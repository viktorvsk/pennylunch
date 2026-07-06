class RecipeSortQuery
  DEFAULT_SORT = "best_match"
  SQL = {
    unknown_time_last: "CASE WHEN total_time = 0 THEN 1 ELSE 0 END ASC",
    recipe_ingredients_join: "LEFT JOIN recipe_ingredients recipe_sort_recipe_ingredients ON recipe_sort_recipe_ingredients.recipe_id = recipes.id",
    catalog_ingredients_join: "LEFT JOIN ingredients recipe_sort_ingredients ON recipe_sort_ingredients.id = recipe_sort_recipe_ingredients.ingredient_id",
    required_ingredient_id: "CASE WHEN recipe_sort_ingredients.optional = FALSE THEN recipe_sort_recipe_ingredients.ingredient_id END"
  }.freeze
  SORT_ORDERS = {
    "time_desc" => [ Arel.sql(SQL.fetch(:unknown_time_last)), { total_time: :desc, id: :asc } ],
    "time_asc" => [ Arel.sql(SQL.fetch(:unknown_time_last)), { total_time: :asc, id: :asc } ],
    "rating_asc" => [ { ratings: :asc, id: :asc } ],
    "rating_desc" => [ { ratings: :desc, id: :asc } ]
  }.freeze
  TOTAL_INGREDIENT_COUNT_SQL = "COUNT(DISTINCT #{SQL.fetch(:required_ingredient_id)})"
  BEST_MATCH_ORDER_SQL = <<~SQL.squish
    CASE WHEN recipe_sort_match_stats.matched_ingredients > 0 THEN 0 ELSE 1 END ASC,
    COALESCE(recipe_sort_match_stats.missing_ingredients, 2147483647) ASC,
    COALESCE(recipe_sort_match_stats.matched_ingredients, 0) DESC,
    COALESCE(recipe_sort_match_stats.total_ingredients, 2147483647) ASC
  SQL

  class << self
    def call(relation:, sort:, ingredients:)
      sort_order = SORT_ORDERS[sort.to_s]
      return relation.reorder(*sort_order) if sort_order

      order_by_best_match(relation:, ingredients:).order(ratings: :desc, total_time: :asc, id: :asc)
    end

    private

    def order_by_best_match(relation:, ingredients:)
      ids = Ingredient.filterable_matches(ingredients).map(&:id)
      return relation if ids.empty?

      match_stats = ingredient_match_stats_relation(relation, ids).to_sql
      relation
        .joins("LEFT JOIN (#{match_stats}) recipe_sort_match_stats ON recipe_sort_match_stats.recipe_id = recipes.id")
        .reorder(Arel.sql(BEST_MATCH_ORDER_SQL))
    end

    def ingredient_match_stats_relation(relation, ids)
      matched_count_sql = matched_ingredient_count_sql(ids)

      relation
        .unscope(:order)
        .joins(SQL.fetch(:recipe_ingredients_join))
        .joins(SQL.fetch(:catalog_ingredients_join))
        .select(<<~SQL.squish)
          recipes.id AS recipe_id,
          #{TOTAL_INGREDIENT_COUNT_SQL} AS total_ingredients,
          #{matched_count_sql} AS matched_ingredients,
          #{TOTAL_INGREDIENT_COUNT_SQL} - #{matched_count_sql} AS missing_ingredients
        SQL
        .group("recipes.id")
    end

    def matched_ingredient_count_sql(ids)
      <<~SQL.squish
        COUNT(DISTINCT CASE
          WHEN recipe_sort_ingredients.optional = FALSE
            AND recipe_sort_recipe_ingredients.ingredient_id IN (#{ids.join(',')})
          THEN recipe_sort_recipe_ingredients.ingredient_id
        END)
      SQL
    end
  end
end

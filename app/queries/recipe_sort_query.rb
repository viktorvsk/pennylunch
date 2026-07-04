class RecipeSortQuery
  DEFAULT_SORT = "best_match"
  UNKNOWN_TIME_LAST_SQL = "CASE WHEN total_time = 0 THEN 1 ELSE 0 END ASC"
  RECIPE_INGREDIENTS_JOIN_SQL = "LEFT JOIN recipe_ingredients recipe_sort_recipe_ingredients ON recipe_sort_recipe_ingredients.recipe_id = recipes.id"
  CATALOG_INGREDIENTS_JOIN_SQL = "LEFT JOIN ingredients recipe_sort_ingredients ON recipe_sort_ingredients.id = recipe_sort_recipe_ingredients.ingredient_id"
  REQUIRED_INGREDIENT_ID_SQL = "CASE WHEN recipe_sort_ingredients.optional = FALSE THEN recipe_sort_recipe_ingredients.ingredient_id END"
  TOTAL_INGREDIENT_COUNT_SQL = "COUNT(DISTINCT #{REQUIRED_INGREDIENT_ID_SQL})"
  BEST_MATCH_ORDER_SQL = <<~SQL.squish
    CASE WHEN recipe_sort_match_stats.matched_ingredients > 0 THEN 0 ELSE 1 END ASC,
    COALESCE(recipe_sort_match_stats.missing_ingredients, 2147483647) ASC,
    COALESCE(recipe_sort_match_stats.matched_ingredients, 0) DESC,
    COALESCE(recipe_sort_match_stats.total_ingredients, 2147483647) ASC
  SQL

  class << self
    def call(relation:, sort:, ingredients:)
      case sort
      when "time_desc"
        relation.reorder(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :desc, id: :asc)
      when "time_asc"
        relation.reorder(Arel.sql(UNKNOWN_TIME_LAST_SQL), total_time: :asc, id: :asc)
      when "rating_asc"
        relation.reorder(ratings: :asc, id: :asc)
      when "rating_desc"
        relation.reorder(ratings: :desc, id: :asc)
      else
        order_by_best_match(relation:, ingredients:).order(ratings: :desc, total_time: :asc, id: :asc)
      end
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
        .joins(RECIPE_INGREDIENTS_JOIN_SQL)
        .joins(CATALOG_INGREDIENTS_JOIN_SQL)
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

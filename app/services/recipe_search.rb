class RecipeSearch
  SEARCH_STRATEGY_CACHE_KEY = "search_strategy"
  VECTOR_SEARCH_STRATEGY = "vector"

  RECIPE_INGREDIENTS_JOIN_SQL = <<~SQL.squish
    LEFT JOIN recipe_ingredients recipe_search_recipe_ingredients
      ON recipe_search_recipe_ingredients.recipe_id = recipes.id
  SQL
  CATALOG_INGREDIENTS_JOIN_SQL = <<~SQL.squish
    LEFT JOIN ingredients recipe_search_ingredients
      ON recipe_search_ingredients.id = recipe_search_recipe_ingredients.ingredient_id
  SQL
  REQUIRED_INGREDIENT_ID_SQL = <<~SQL.squish
    CASE
      WHEN recipe_search_ingredients.optional = FALSE
      THEN recipe_search_recipe_ingredients.ingredient_id
    END
  SQL
  TOTAL_INGREDIENT_COUNT_SQL = "COUNT(DISTINCT #{REQUIRED_INGREDIENT_ID_SQL})"
  BEST_MATCH_ORDER_SQL = <<~SQL.squish
    CASE WHEN recipe_search_match_stats.matched_ingredients > 0 THEN 0 ELSE 1 END ASC,
    COALESCE(recipe_search_match_stats.missing_ingredients, 2147483647) ASC,
    COALESCE(recipe_search_match_stats.matched_ingredients, 0) DESC,
    COALESCE(recipe_search_match_stats.total_ingredients, 2147483647) ASC
  SQL

  class << self
    def call(relation:, ingredients:)
      ingredients = ingredients.to_s
      return relation if ingredients.blank?

      if Rails.cache.read(SEARCH_STRATEGY_CACHE_KEY) == VECTOR_SEARCH_STRATEGY
        filter_by_ingredient_vector(relation:, ingredients:)
      else
        filter_by_ingredient_overlap(relation:, ingredients:)
      end
    end

    def order_by_best_match(scope, ingredients:)
      ids = filterable_ingredient_ids(ingredients)
      return scope if ids.empty?

      match_stats = ingredient_match_stats_relation(scope, ids).to_sql
      scope
        .joins("LEFT JOIN (#{match_stats}) recipe_search_match_stats ON recipe_search_match_stats.recipe_id = recipes.id")
        .reorder(Arel.sql(BEST_MATCH_ORDER_SQL))
    end

    private

    def filter_by_ingredient_overlap(relation:, ingredients:)
      ids = filterable_ingredient_ids(ingredients)
      return relation if ids.empty?

      candidate_ids = RecipeIngredient.where(ingredient_id: ids).select(:recipe_id)

      relation.where(id: candidate_ids)
    end

    def filter_by_ingredient_vector(relation:, ingredients:)
      query_names = filterable_ingredient_names(ingredients)

      return relation if query_names.empty?

      vector = LocalEmbedding.call(query_names.join("\n"))
      threshold = SETTINGS.ingredients_max_cosine_distance.to_f.positive? ? SETTINGS.ingredients_max_cosine_distance.to_f : nil
      ids = relation
        .except(:select, :order, :limit, :offset)
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold:)
        .reselect(:id)
        .unscope(:order)

      relation.where(id: ids)
    end

    def filterable_ingredient_ids(ingredients)
      filterable_ingredients(ingredients).map(&:id)
    end

    def filterable_ingredient_names(ingredients)
      filterable_ingredients(ingredients).map(&:name)
    end

    def filterable_ingredients(ingredients)
      names = submitted_ingredient_names(ingredients)
      if names.empty?
        []
      else
        ingredients_by_name = Ingredient.where(optional: false, name: names).index_by(&:name)
        names.filter_map { |name| ingredients_by_name[name] }
      end
    end

    def submitted_ingredient_names(ingredients)
      ingredients.to_s.split(/[\n,;]+/)
        .filter_map { |line| Ingredient.normalize_lookup_key(line) }
        .uniq
    end

    def matched_ingredient_count_sql(ids)
      ids_sql = ids.map { |id| Integer(id) }.join(", ")
      <<~SQL.squish
        COUNT(DISTINCT CASE
          WHEN recipe_search_ingredients.optional = FALSE
            AND recipe_search_recipe_ingredients.ingredient_id IN (#{ids_sql})
          THEN recipe_search_recipe_ingredients.ingredient_id
        END)
      SQL
    end

    def ingredient_match_stats_relation(scope, ids)
      matched_count_sql = matched_ingredient_count_sql(ids)
      scope
        .except(:select, :order, :limit, :offset)
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
  end
end

class RecipeSearch
  SEARCH_STRATEGY_CACHE_KEY = "search_strategy"
  VECTOR_SEARCH_STRATEGY = "vector"

  RECIPE_INGREDIENT_NAMES_JOIN_SQL = <<~SQL.squish
    JOIN LATERAL jsonb_array_elements_text(recipes.ingredient_names) AS recipe_ingredient_names(ingredient_name) ON TRUE
  SQL
  CATALOG_INGREDIENTS_JOIN_SQL = <<~SQL.squish
    LEFT JOIN ingredients recipe_search_ingredients
      ON recipe_search_ingredients.name = recipe_ingredient_names.ingredient_name
      OR recipe_search_ingredients.aliases @> jsonb_build_array(recipe_ingredient_names.ingredient_name)
  SQL
  REQUIRED_INGREDIENT_KEY_SQL = <<~SQL.squish
    CASE
      WHEN recipe_search_ingredients.optional = FALSE THEN recipe_search_ingredients.id::text
      WHEN recipe_search_ingredients.id IS NULL THEN CONCAT('raw:', recipe_ingredient_names.ingredient_name)
    END
  SQL
  TOTAL_INGREDIENT_COUNT_SQL = "COUNT(DISTINCT #{REQUIRED_INGREDIENT_KEY_SQL})"
  MATCHED_INGREDIENT_COUNT_SQL = "COUNT(DISTINCT recipe_search_user_ingredients.id)"
  MATCHED_RECIPE_INGREDIENT_COUNT_SQL = <<~SQL.squish
    COUNT(DISTINCT CASE
      WHEN recipe_search_user_ingredients.id IS NOT NULL
      THEN recipe_search_ingredients.id::text
    END)
  SQL
  MISSING_INGREDIENT_COUNT_SQL = "#{TOTAL_INGREDIENT_COUNT_SQL} - #{MATCHED_RECIPE_INGREDIENT_COUNT_SQL}"
  BEST_MATCH_ORDER_SQL = <<~SQL.squish
    CASE WHEN recipe_search_match_stats.matched_ingredients > 0 THEN 0 ELSE 1 END ASC,
    COALESCE(recipe_search_match_stats.missing_ingredients, 2147483647) ASC,
    COALESCE(recipe_search_match_stats.matched_ingredients, 0) DESC,
    COALESCE(recipe_search_match_stats.total_ingredients, 2147483647) ASC
  SQL

  def self.call(relation:, ingredients:)
    new(relation:, ingredients:).call
  end

  def initialize(relation:, ingredients:)
    @relation = relation
    @ingredients = ingredients.to_s
  end

  def call
    return relation if ingredients.blank?

    if Rails.cache.read(SEARCH_STRATEGY_CACHE_KEY) == VECTOR_SEARCH_STRATEGY
      filter_by_ingredient_vector
    else
      filter_by_ingredient_overlap
    end
  end

  def order_by_best_match(scope)
    ids = filterable_ingredient_ids
    return scope if ids.empty?

    match_stats = ingredient_match_stats_relation(scope, ids).to_sql
    scope
      .joins("LEFT JOIN (#{match_stats}) recipe_search_match_stats ON recipe_search_match_stats.recipe_id = recipes.id")
      .reorder(Arel.sql(BEST_MATCH_ORDER_SQL))
  end

  private

  attr_reader :relation, :ingredients

  def filter_by_ingredient_overlap
    ids = filterable_ingredient_ids
    return relation if ids.empty?

    candidate_ids = ingredient_match_stats_relation(relation, ids)
      .reselect("recipes.id")
      .having("#{MATCHED_INGREDIENT_COUNT_SQL} > 0")

    relation.where(id: candidate_ids)
  end

  def filter_by_ingredient_vector
    query_names = Ingredient.filterable_canonical_names_for(parsed_ingredient_names)

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

  def filterable_ingredient_ids
    names = Ingredient.filterable_canonical_names_for(parsed_ingredient_names)
    return [] if names.empty?

    Ingredient.where(optional: false, name: names).pluck(:id)
  end

  def parsed_ingredient_names
    @parsed_ingredient_names ||= begin
      lines = ingredients.split(/[\n,;]+/).filter_map { |line| line.squish.presence }
      if lines.empty?
        []
      else
        parser_result = IngredientParser.call([ lines ]).first
        lines + parser_result.ingredient_names
      end
    end
  end

  def user_ingredients_join_sql(ids)
    user_ingredients_sql = Ingredient.where(optional: false, id: ids).select(:id).to_sql
    "LEFT JOIN (#{user_ingredients_sql}) recipe_search_user_ingredients ON recipe_search_user_ingredients.id = recipe_search_ingredients.id"
  end

  def ingredient_match_stats_relation(scope, ids)
    scope
      .except(:select, :order, :limit, :offset)
      .joins(RECIPE_INGREDIENT_NAMES_JOIN_SQL)
      .joins(CATALOG_INGREDIENTS_JOIN_SQL)
      .joins(user_ingredients_join_sql(ids))
      .select(<<~SQL.squish)
        recipes.id AS recipe_id,
        #{TOTAL_INGREDIENT_COUNT_SQL} AS total_ingredients,
        #{MATCHED_INGREDIENT_COUNT_SQL} AS matched_ingredients,
        #{MISSING_INGREDIENT_COUNT_SQL} AS missing_ingredients
      SQL
      .group("recipes.id")
  end
end

class RecipeIngredientFilterQuery
  SEARCH_STRATEGY_CACHE_KEY = "search_strategy"
  STRATEGIES = %w[overlap vector].freeze
  VECTOR_SEARCH_STRATEGY = "vector"

  class << self
    def call(relation:, ingredients:)
      filterable_ingredients = Ingredient.filterable_matches(ingredients)
      return relation if filterable_ingredients.empty?

      if Rails.cache.read(SEARCH_STRATEGY_CACHE_KEY) == VECTOR_SEARCH_STRATEGY
        vector = LocalEmbedding.call(filterable_ingredients.map(&:name).join("\n"))
        threshold = SETTINGS.ingredients_max_cosine_distance.to_f
        ids = relation
          .where.not(ingredients_vector: nil)
          .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: (threshold if threshold.positive?))
          .reselect(:id)
          .unscope(:order)

        relation.where(id: ids)
      else
        ids = RecipeIngredient.where(ingredient_id: filterable_ingredients.map(&:id)).select(:recipe_id)
        relation.where(id: ids)
      end
    end
  end
end

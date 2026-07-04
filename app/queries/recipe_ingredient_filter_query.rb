class RecipeIngredientFilterQuery
  SEARCH_STRATEGY_CACHE_KEY = "search_strategy"
  VECTOR_SEARCH_STRATEGY = "vector"

  class << self
    def call(relation:, ingredients:)
      filterable_ingredients = filterable_ingredients_for(ingredients)
      return relation if filterable_ingredients.empty?

      if Rails.cache.read(SEARCH_STRATEGY_CACHE_KEY) == VECTOR_SEARCH_STRATEGY
        vector = LocalEmbedding.call(filterable_ingredients.map(&:name).join("\n"))
        threshold = SETTINGS.ingredients_max_cosine_distance.to_f.positive? ? SETTINGS.ingredients_max_cosine_distance.to_f : nil
        ids = relation
          .except(:select, :order, :limit, :offset)
          .where.not(ingredients_vector: nil)
          .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold:)
          .reselect(:id)
          .unscope(:order)

        relation.where(id: ids)
      else
        ids = RecipeIngredient.where(ingredient_id: filterable_ingredients.map(&:id)).select(:recipe_id)
        relation.where(id: ids)
      end
    end

    def filterable_ingredients_for(ingredients)
      names = ingredients.to_s.split(/[\n,;]+/).filter_map { |line| Ingredient.normalize_lookup_key(line) }.uniq
      return [] if names.empty?

      ingredients_by_name = Ingredient.where(optional: false, name: names).index_by(&:name)

      names.filter_map { |name| ingredients_by_name[name] }
    end
  end
end

module Recipes
  class SimilarRecipesQuery
    DEFAULT_LIMIT = 3

    def initialize(recipe:, limit: DEFAULT_LIMIT, relation: Recipe.all)
      @recipe = recipe
      @limit = limit
      @relation = relation
    end

    def call
      return relation.none if recipe.ingredients_vector.blank?

      relation
        .where.not(id: recipe.id)
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, recipe.ingredients_vector, distance: "cosine")
        .limit(limit)
    end

    private

    attr_reader :recipe, :limit, :relation
  end
end

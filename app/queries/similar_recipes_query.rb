# Returns recipes nearest to a recipe by ingredient-vector distance.
class SimilarRecipesQuery
  DEFAULT_LIMIT = 3

  class << self
    def call(recipe:, limit: DEFAULT_LIMIT, relation: Recipe.all)
      return relation.none if recipe.ingredients_vector.blank?

      relation
        .where.not(id: recipe.id)
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, recipe.ingredients_vector, distance: "cosine")
        .limit(limit)
    end
  end
end

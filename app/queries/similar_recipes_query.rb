# Finds recipes nearest to a source recipe by pgvector cosine distance over
# `ingredients_vector`.
#
# Returns an `ActiveRecord::Relation<Recipe>` limited by `limit`; returns
# `relation.none` when the source recipe has not been indexed with a vector.
#
# Example generated query:
#   SELECT "recipes".*, "recipes"."ingredients_vector" <=> '[...]' AS neighbor_distance
#   FROM "recipes"
#   WHERE "recipes"."id" != 42 AND "recipes"."ingredients_vector" IS NOT NULL
#   ORDER BY "recipes"."ingredients_vector" <=> '[...]' LIMIT 3
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

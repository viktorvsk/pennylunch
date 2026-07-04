module Recipes
  # Returns a relation limited to nearest ingredient-vector candidates.
  class IngredientCandidateQuery
    DEFAULT_CANDIDATE_COUNT = 250

    def self.call(relation:, vector:)
      count = SETTINGS.ingredients_candidate_count.to_i.positive? ? SETTINGS.ingredients_candidate_count.to_i : DEFAULT_CANDIDATE_COUNT
      threshold = SETTINGS.ingredients_max_cosine_distance.to_f.positive? ? SETTINGS.ingredients_max_cosine_distance.to_f : nil
      ids = relation
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold:)
        .limit(count)
        .pluck(:id)

      relation.where(id: ids)
    end
  end
end

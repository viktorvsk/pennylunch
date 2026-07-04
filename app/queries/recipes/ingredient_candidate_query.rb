module Recipes
  class IngredientCandidateQuery
    DEFAULT_CANDIDATE_COUNT = 250

    def initialize(relation:, vector:, candidate_count:, max_distance:)
      @relation = relation
      @vector = vector
      @candidate_count = candidate_count.to_i.positive? ? candidate_count.to_i : DEFAULT_CANDIDATE_COUNT
      @max_distance = max_distance.to_f.positive? ? max_distance.to_f : nil
    end

    def call
      ids = nearest_ids

      relation.where(id: ids)
    end

    private

    attr_reader :relation, :vector, :candidate_count, :max_distance

    def nearest_ids
      relation
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: max_distance)
        .limit(candidate_count)
        .pluck(:id)
    end
  end
end

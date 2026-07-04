module Recipes
  class IngredientCandidateQuery
    Request = Data.define(:relation, :names, :vector, :candidate_count, :max_distance)

    DEFAULT_CANDIDATE_COUNT = 250
    INGREDIENT_NAMES_OVERLAP_SQL = "ingredients_vector_names && ARRAY[?]::text[]"

    def initialize(relation:, names:, vector:, candidate_count:, max_distance:)
      @request = Request.new(
        relation:,
        names:,
        vector:,
        candidate_count: candidate_count.to_i.positive? ? candidate_count.to_i : DEFAULT_CANDIDATE_COUNT,
        max_distance: max_distance.to_f.positive? ? max_distance.to_f : nil
      )
    end

    def call
      candidate_relation = relation.where(INGREDIENT_NAMES_OVERLAP_SQL, names)
      ids = nearest_ids(candidate_relation)

      ids.any? ? candidate_relation.where(id: ids) : candidate_relation
    end

    private

    attr_reader :request

    delegate :relation, :names, :vector, :candidate_count, :max_distance, to: :request

    def nearest_ids(candidate_relation)
      candidate_relation
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: max_distance)
        .limit(candidate_count)
        .pluck(:id)
    end
  end
end

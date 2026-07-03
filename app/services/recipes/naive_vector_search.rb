module Recipes
  class NaiveVectorSearch
    def initialize(request)
      @request = request
    end

    def call
      query_text = ingredients_embedding_text
      return relation.none if query_text.blank?

      vector = embedder.call(query_text)
      ids = relation
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: max_distance)
        .limit(candidate_count)
        .pluck(:id)

      ids.any? ? relation.where(id: ids) : relation.none
    end

    private

    attr_reader :request

    delegate :relation, :text, :embedder, :ingredient_parser, to: :request

    def ingredients_embedding_text
      ingredient_parser.call([ ingredient_query_lines ]).first.ingredient_names.join("\n")
    end

    def ingredient_query_lines
      text.split(/[\n,;]+/).filter_map { |line| line.squish.presence }
    end

    def candidate_count
      request.candidate_count.positive? ? request.candidate_count : 250
    end

    def max_distance
      request.max_distance.positive? ? request.max_distance : nil
    end
  end
end

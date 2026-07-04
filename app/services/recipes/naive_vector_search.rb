module Recipes
  class NaiveVectorSearch
    def initialize(request)
      @request = request
    end

    def call
      query_names = query_ingredient_names
      return relation if query_names.empty?

      candidate_relation = relation.where("ingredients_vector_names && ARRAY[?]::text[]", query_names)
      query_text = query_names.join("\n")

      vector = embedder.call(query_text)
      ids = candidate_relation
        .where.not(ingredients_vector: nil)
        .nearest_neighbors(:ingredients_vector, vector, distance: "cosine", threshold: max_distance)
        .limit(candidate_count)
        .pluck(:id)

      ids.any? ? candidate_relation.where(id: ids) : candidate_relation
    end

    private

    attr_reader :request

    delegate :relation, :text, :embedder, :ingredient_parser, to: :request

    def query_ingredient_names
      lines = ingredient_query_lines
      parser_result = ingredient_parser.call([ lines ]).first
      Ingredient.filterable_canonical_names_for(lines + parser_result.ingredient_names)
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

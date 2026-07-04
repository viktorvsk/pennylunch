module Recipes
  class NaiveVectorSearch
    def initialize(request)
      @request = request
    end

    def call
      query_names = query_ingredient_names
      return relation if query_names.empty?

      query_text = query_names.join("\n")
      Recipes::IngredientCandidateQuery.new(
        relation:,
        names: query_names,
        vector: embedder.call(query_text),
        candidate_count:,
        max_distance:
      ).call
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
      request.candidate_count.positive? ? request.candidate_count : Recipes::IngredientCandidateQuery::DEFAULT_CANDIDATE_COUNT
    end

    def max_distance
      request.max_distance.positive? ? request.max_distance : nil
    end
  end
end

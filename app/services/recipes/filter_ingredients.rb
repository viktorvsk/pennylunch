module Recipes
  class FilterIngredients
    Request = Data.define(:relation, :text, :embedder, :ingredient_parser, :strategy, :candidate_count, :max_distance)

    def initialize(relation:, text:, options: {})
      @request = Request.new(
        relation:,
        text: text.to_s,
        embedder: options.fetch(:embedder, LocalEmbedding),
        ingredient_parser: options.fetch(:ingredient_parser, IngredientParser),
        strategy: options.fetch(:strategy, Rails.application.config.penny_lunch.ingredients_filter_strategy).to_s,
        candidate_count: options.fetch(:candidate_count, Rails.application.config.penny_lunch.ingredients_candidate_count).to_i,
        max_distance: options.fetch(:max_distance, Rails.application.config.penny_lunch.ingredients_max_cosine_distance).to_f,
      )
    end

    def call
      return relation if text.blank?

      case strategy
      when "naive_vector_search"
        Recipes::NaiveVectorSearch.new(request).call
      else
        raise ArgumentError, "unsupported ingredients filter strategy: #{strategy}"
      end
    end

    private

    attr_reader :request

    delegate :relation, :text, :embedder, :ingredient_parser, :strategy, :candidate_count, :max_distance, to: :request
  end
end

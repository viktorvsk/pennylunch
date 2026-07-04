class SetRecipeSearchStrategyJob < ApplicationJob
  queue_as :default

  STRATEGIES = %w[overlap vector].freeze
  class InvalidStrategyError < StandardError; end

  def perform(strategy)
    normalized_strategy = strategy.to_s
    unless STRATEGIES.include?(normalized_strategy)
      raise InvalidStrategyError, "unknown recipe search strategy: #{normalized_strategy}"
    end

    if normalized_strategy == RecipeIngredientFilterQuery::VECTOR_SEARCH_STRATEGY
      Rails.cache.write(RecipeIngredientFilterQuery::SEARCH_STRATEGY_CACHE_KEY, RecipeIngredientFilterQuery::VECTOR_SEARCH_STRATEGY)
    else
      Rails.cache.delete(RecipeIngredientFilterQuery::SEARCH_STRATEGY_CACHE_KEY)
    end
  end
end

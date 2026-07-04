class SetRecipeSearchStrategyJob < ApplicationJob
  def perform(strategy)
    raise ArgumentError, "unknown recipe search strategy: #{strategy}" unless RecipeIngredientFilterQuery::STRATEGIES.include?(strategy.to_s)

    Rails.cache.write(RecipeIngredientFilterQuery::SEARCH_STRATEGY_CACHE_KEY, strategy.to_s)
  end
end

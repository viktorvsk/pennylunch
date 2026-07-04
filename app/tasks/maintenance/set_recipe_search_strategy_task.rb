module Maintenance
  class SetRecipeSearchStrategyTask < MaintenanceTasks::Task
    STRATEGIES = %w[overlap vector].freeze

    attribute :strategy, :string, default: "overlap"
    validates :strategy, inclusion: { in: STRATEGIES }

    no_collection

    def process
      if strategy == RecipeSearch::VECTOR_SEARCH_STRATEGY
        Rails.cache.write(RecipeSearch::SEARCH_STRATEGY_CACHE_KEY, RecipeSearch::VECTOR_SEARCH_STRATEGY)
      else
        Rails.cache.delete(RecipeSearch::SEARCH_STRATEGY_CACHE_KEY)
      end
    end
  end
end

module Recipes
  module FilterValues
    ACTIVE_VALUE = "1"
    DEFAULT_PAGE = 1
    QUICK_TOTAL_TIME_LIMIT = 30
    POPULAR_RATING_THRESHOLD = 4.8

    def self.active?(value)
      value.to_s == ACTIVE_VALUE
    end
  end
end

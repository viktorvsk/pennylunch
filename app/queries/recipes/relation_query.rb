module Recipes
  class RelationQuery
    BOOLEAN = ActiveModel::Type::Boolean.new
    UNKNOWN_TOTAL_TIME = 0
    QUICK_TOTAL_TIME_LIMIT = 30
    POPULAR_RATING_THRESHOLD = 4.8

    def self.call(params:, relation: Recipe.all)
      params = params.to_h.with_indifferent_access
      filtered = Recipes::TitleSearchQuery.call(relation:, query: params[:q])
      filtered = in_category(filtered, params[:category])
      filtered = quick(filtered) if active?(params[:quick])
      filtered = popular(filtered) if active?(params[:popular])
      filtered
    end

    def self.active?(value)
      BOOLEAN.cast(value)
    end

    def self.in_category(scope, category)
      normalized = Recipe.normalize_category(category)
      normalized.present? ? scope.where(category_normalized: normalized) : scope
    end
    private_class_method :in_category

    def self.quick(scope)
      scope.where("total_time > ? AND total_time < ?", UNKNOWN_TOTAL_TIME, QUICK_TOTAL_TIME_LIMIT)
    end
    private_class_method :quick

    def self.popular(scope)
      scope.where("ratings > ?", POPULAR_RATING_THRESHOLD)
    end
    private_class_method :popular
  end
end

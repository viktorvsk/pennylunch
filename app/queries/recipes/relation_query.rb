module Recipes
  class RelationQuery
    BOOLEAN = ActiveModel::Type::Boolean.new
    UNKNOWN_TOTAL_TIME = 0
    QUICK_TOTAL_TIME_LIMIT = 30
    POPULAR_RATING_THRESHOLD = 4.8

    def self.call(params:, relation: Recipe.all)
      new(params:, relation:).call
    end

    def self.sort(relation, sort)
      Recipes::SortQuery.call(relation:, sort:)
    end

    def self.active?(value)
      BOOLEAN.cast(value)
    end

    def self.default_sort
      Recipes::SortQuery.default_sort
    end

    def initialize(params:, relation: Recipe.all)
      @params = params
      @relation = relation
    end

    def call
      filtered = Recipes::TitleSearchQuery.call(relation:, query: param(:q))
      filtered = in_category(filtered, param(:category))
      filtered = quick(filtered) if self.class.active?(param(:quick))
      filtered = popular(filtered) if self.class.active?(param(:popular))
      filtered
    end

    private

    attr_reader :params, :relation

    def param(name)
      params[name] || params[name.to_s]
    end

    def in_category(scope, category)
      normalized = Recipe.normalize_category(category)
      normalized.present? ? scope.where(category_normalized: normalized) : scope
    end

    def quick(scope)
      scope.where("total_time > ? AND total_time < ?", UNKNOWN_TOTAL_TIME, QUICK_TOTAL_TIME_LIMIT)
    end

    def popular(scope)
      scope.where("ratings > ?", POPULAR_RATING_THRESHOLD)
    end
  end
end

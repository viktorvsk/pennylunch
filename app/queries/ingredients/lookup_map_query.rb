module Ingredients
  class LookupMapQuery
    def initialize(scope:)
      @scope = scope
    end

    def call
      scope.pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
        ([ name ] + Array(aliases)).each do |value|
          key = Ingredients::LookupKey.normalize(value)
          mapping[key] = name if key.present?
        end
      end
    end

    private

    attr_reader :scope
  end
end

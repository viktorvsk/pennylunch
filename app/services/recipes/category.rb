module Recipes
  class Category
    def self.normalize(value)
      value.to_s.strip.downcase
    end

    def self.slug_for(value)
      normalize(value).parameterize
    end
  end
end

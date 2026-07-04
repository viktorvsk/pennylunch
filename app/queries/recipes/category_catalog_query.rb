module Recipes
  class CategoryCatalogQuery
    BLANK_CATEGORY = ""
    SOURCE_LABEL_RANK = 0
    NORMALIZED_LABEL_RANK = 1

    def self.options
      new.options
    end

    def self.labels
      new.labels
    end

    def self.slug_map
      new.slug_map
    end

    def self.from_slug(slug)
      new.from_slug(slug)
    end

    def options
      @options ||= Recipe.where.not(category_normalized: BLANK_CATEGORY)
        .distinct
        .order(:category_normalized)
        .pluck(:category_normalized)
    end

    def labels
      labels = options.to_h { |category| [ category, category ] }

      source_categories.each do |normalized, rows|
        labels[normalized] = best_label(rows) || normalized
      end

      labels
    end

    def slug_map
      options.to_h { |category| [ category, Recipe.category_slug_for(category) ] }
    end

    def from_slug(slug)
      options.find { |category| Recipe.category_slug_for(category) == slug.to_s }
    end

    private

    def source_categories
      Recipe.where.not(category_normalized: BLANK_CATEGORY)
        .pluck(:category_normalized, :category)
        .group_by(&:first)
    end

    def best_label(rows)
      rows.filter_map { |(_, category)| category.to_s.squish.presence }.min_by do |category|
        [ category_rank(category), category.downcase ]
      end
    end

    def category_rank(category)
      category == Recipe.normalize_category(category) ? NORMALIZED_LABEL_RANK : SOURCE_LABEL_RANK
    end
  end
end

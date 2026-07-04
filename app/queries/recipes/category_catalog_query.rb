module Recipes
  class CategoryCatalogQuery
    BLANK_CATEGORY = ""
    SOURCE_LABEL_RANK = 0
    NORMALIZED_LABEL_RANK = 1

    def self.options
      Recipe.where.not(category_normalized: BLANK_CATEGORY)
        .distinct
        .order(:category_normalized)
        .pluck(:category_normalized)
    end

    def self.labels
      labels = options.to_h { |category| [ category, category ] }

      source_categories.each do |normalized, rows|
        labels[normalized] = best_label(rows) || normalized
      end

      labels
    end

    def self.from_slug(slug)
      options.find { |category| Recipe.category_slug_for(category) == slug.to_s }
    end

    def self.source_categories
      Recipe.where.not(category_normalized: BLANK_CATEGORY)
        .pluck(:category_normalized, :category)
        .group_by(&:first)
    end
    private_class_method :source_categories

    def self.best_label(rows)
      rows.filter_map { |(_, category)| category.to_s.squish.presence }.min_by do |category|
        [ category_rank(category), category.downcase ]
      end
    end
    private_class_method :best_label

    def self.category_rank(category)
      category == Recipe.normalize_category(category) ? NORMALIZED_LABEL_RANK : SOURCE_LABEL_RANK
    end
    private_class_method :category_rank
  end
end

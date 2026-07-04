class RecipeToolbar < Data.define(:current_sort, :quick_active, :popular_active, :sort_options, :category_options, :selected_category, :selected_category_label, :category_tooltip)
  SortOption = Data.define(:value, :label)
  CategoryOption = Data.define(:value, :label)
  BOOLEAN = ActiveModel::Type::Boolean.new
  SORT_LABELS = {
    "best_match" => "Best Match",
    "time_asc" => "Fastest First",
    "time_desc" => "Slowest First",
    "rating_asc" => "Popular Last",
    "rating_desc" => "Popular First"
  }.freeze

  class << self
    def build(filters:, selected_category:, category_labels:)
      current_sort = normalize_sort(filters["sort"])
      selected_category = selected_category.to_s
      selected_category_label = category_labels[selected_category] if selected_category.present?

      new(
        current_sort:,
        quick_active: active_filter?(filters["quick"]),
        popular_active: active_filter?(filters["popular"]),
        sort_options: SORT_LABELS.map { |value, label| SortOption.new(value:, label:) },
        category_options: category_labels.map { |value, label| CategoryOption.new(value:, label:) },
        selected_category:,
        selected_category_label:,
        category_tooltip: selected_category_label.present? ? "Category: #{selected_category_label}" : "Category: all categories"
      )
    end

    private

    def normalize_sort(value)
      sort = value.presence || RecipeSortQuery::DEFAULT_SORT
      SORT_LABELS.key?(sort) ? sort : RecipeSortQuery::DEFAULT_SORT
    end

    def active_filter?(value)
      BOOLEAN.cast(value) || false
    end
  end

  def current_sort_label
    SORT_LABELS.fetch(current_sort)
  end
end

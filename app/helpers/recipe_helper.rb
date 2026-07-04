module RecipeHelper
  RecipeToolbarState = Data.define(:current_sort, :quick_active, :popular_active, :category_labels, :selected_category_label, :category_tooltip)
  MAX_RATING_STARS = 5
  RATING_PRECISION = 2
  RECIPE_UI_CATALOG_CACHE_KEY = "recipes/ui_catalog/v1"
  SORT_OPTIONS = {
    "best_match" => "Best Match",
    "time_asc" => "Fastest First",
    "time_desc" => "Slowest First",
    "rating_asc" => "Popular Last",
    "rating_desc" => "Popular First"
  }.freeze

  def rating_stars(rating, class_name: "recipe-rating", side: "bottom", align: "end")
    value = number_with_precision(rating, precision: RATING_PRECISION)
    tag.span(
      filled_stars(rating),
      class: class_name,
      aria: { label: "Rating #{value} out of 5" },
      data: { tooltip: "Rating: #{value} out of 5", side:, align: }
    )
  end

  def category_label(recipe)
    recipe.category.presence || "Uncategorized"
  end

  def category_heading(category)
    category.to_s.titleize
  end

  def recipe_time_tooltip(recipe)
    result = []
    result << "prepare for #{recipe_duration_text(recipe.prep_time)}" if recipe.prep_time.positive?
    result << "then" if recipe.prep_time.positive? && recipe.cook_time.positive?
    result << "cook for #{recipe_duration_text(recipe.cook_time)}" if recipe.cook_time.positive?
    result.join(" ").capitalize
  end

  def recipe_duration_text(minutes)
    total_minutes = minutes.to_i
    hours, remaining_minutes = total_minutes.divmod(60)
    parts = []
    parts << pluralize(hours, "hour") if hours.positive?
    parts << pluralize(remaining_minutes, "minute") if remaining_minutes.positive? || parts.empty?
    parts.join(" ")
  end

  def recipe_sort_options
    SORT_OPTIONS
  end

  def recipe_sort_label(sort)
    SORT_OPTIONS.fetch(sort.presence || RecipeSortQuery::DEFAULT_SORT, SORT_OPTIONS.fetch(RecipeSortQuery::DEFAULT_SORT))
  end

  def recipe_filter_active?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def recipe_toolbar_state(filters:, selected_category:)
    category_labels = recipe_category_labels
    selected_category_label = selected_category.present? ? category_labels.fetch(selected_category, category_heading(selected_category)) : nil

    RecipeToolbarState.new(
      current_sort: filters["sort"].presence || RecipeSortQuery::DEFAULT_SORT,
      quick_active: recipe_filter_active?(filters["quick"]),
      popular_active: recipe_filter_active?(filters["popular"]),
      category_labels:,
      selected_category_label:,
      category_tooltip: selected_category_label.present? ? "Category: #{selected_category_label}" : "Category: all categories"
    )
  end

  def recipe_ui_catalog
    Rails.cache.fetch(recipe_ui_catalog_cache_key) do
      category_labels = Recipe.category_labels

      {
        ingredient_options: Ingredient.filter_options,
        category_labels:,
        category_slugs: category_labels.keys.to_h { |category| [ category, Recipe.category_slug_for(category) ] }
      }
    end
  end

  def recipe_ui_catalog_json
    catalog = recipe_ui_catalog
    {
      ingredientOptions: catalog.fetch(:ingredient_options),
      categoryLabels: catalog.fetch(:category_labels),
      categorySlugs: catalog.fetch(:category_slugs)
    }.to_json
  end

  def recipe_category_labels
    recipe_ui_catalog.fetch(:category_labels)
  end

  def recipe_category_from_slug(slug)
    recipe_ui_catalog.fetch(:category_slugs).key(slug.to_s)
  end

  def recipe_ui_catalog_cache_key
    [
      RECIPE_UI_CATALOG_CACHE_KEY,
      Ingredient.all.cache_key_with_version,
      Recipe.all.cache_key_with_version
    ]
  end

  def recipe_layout_fab_filters
    @recipe_layout_fab_filters || params.permit(:ingredients).to_h
  end

  def recipe_filter_path(filters = {})
    values = filters.to_h.with_indifferent_access
    category = Recipe.normalize_category(values.delete(:category))
    values.delete(:sort) if values[:sort].blank? || values[:sort] == RecipeSortQuery::DEFAULT_SORT
    values.compact_blank!

    if category.present?
      recipe_category_path(Recipe.category_slug_for(category), values)
    else
      recipes_path(values)
    end
  end

  private

  def filled_stars(rating)
    filled_count = rating.to_f.round.clamp(0, MAX_RATING_STARS)
    safe_join(MAX_RATING_STARS.times.map do |index|
      tag.span("★", class: index < filled_count ? "text-amber-500" : "text-zinc-300")
    end)
  end
end

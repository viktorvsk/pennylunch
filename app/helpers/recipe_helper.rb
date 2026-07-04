module RecipeHelper
  MAX_RATING_STARS = 5
  RATING_PRECISION = 2
  RECIPE_UI_CATALOG_CACHE_EXPIRATION = 5.minutes
  RECIPE_UI_CATALOG_CACHE_KEY = "recipes/ui_catalog/v1"
  SORT_OPTIONS = {
    "time_asc" => "Time ascending",
    "time_desc" => "Time descending",
    "rating_asc" => "Rating ascending",
    "rating_desc" => "Rating descending"
  }.freeze

  def filled_stars(rating)
    filled_count = rating.to_f.round.clamp(0, MAX_RATING_STARS)
    safe_join(MAX_RATING_STARS.times.map do |index|
      content_tag(:span, "★", class: index < filled_count ? "text-amber-500" : "text-zinc-300")
    end)
  end

  def rating_stars(rating, **options)
    class_name = options.fetch(:class_name, "recipe-rating")
    side = options.fetch(:side, "bottom")
    align = options.fetch(:align, "end")
    value = number_with_precision(rating, precision: RATING_PRECISION)
    content_tag(
      :span,
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
    result << "prepare for #{recipe.prep_time} minutes" unless recipe.prep_time.zero?
    result << "then" if recipe.prep_time.positive? && recipe.cook_time.positive?
    result << "cook for #{recipe.cook_time} minutes" unless recipe.cook_time.zero?
    result.join(" ").capitalize
  end

  def recipe_sort_options
    SORT_OPTIONS
  end

  def recipe_sort_label(sort)
    SORT_OPTIONS.fetch(sort.presence || RecipeSearch::DEFAULT_SORT, SORT_OPTIONS.fetch(RecipeSearch::DEFAULT_SORT))
  end

  def recipe_filter_active?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def recipe_ui_catalog
    Rails.cache.fetch(RECIPE_UI_CATALOG_CACHE_KEY, expires_in: RECIPE_UI_CATALOG_CACHE_EXPIRATION) do
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

  def recipe_layout_fab_filters
    params.slice(:ingredients).permit(:ingredients).to_h
  end

  def recipe_filter_path(filters = {})
    values = filters.to_h.with_indifferent_access
    category = Recipe.normalize_category(values.delete(:category))
    values.delete(:page) if values[:page].blank?
    values.delete(:sort) if values[:sort].blank? || values[:sort] == RecipeSearch::DEFAULT_SORT
    values.compact_blank!

    path = category.present? ? "/recipes/#{Recipe.category_slug_for(category)}" : recipes_path
    values.present? ? "#{path}?#{values.to_query}" : path
  end
end

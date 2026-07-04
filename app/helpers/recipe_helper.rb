module RecipeHelper
  MAX_RATING_STARS = 5
  RATING_PRECISION = 2

  def rating_stars(rating, **options)
    options.assert_valid_keys(:class_name, :side, :align)
    class_name = options.fetch(:class_name, "recipe-rating")
    side = options.fetch(:side, "bottom")
    align = options.fetch(:align, "end")
    value = number_with_precision(rating, precision: RATING_PRECISION)
    tag.span(
      filled_stars(rating),
      class: class_name,
      aria: { label: "Rating #{value} out of 5" },
      data: { tooltip: "Rating: #{value} out of 5", side:, align: }
    )
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

  def recipe_toolbar_state(filters:, selected_category:)
    RecipeToolbar.build(filters:, selected_category:, category_labels: recipe_category_labels)
  end

  def recipe_catalog
    Catalog.fetch
  end

  def recipe_catalog_json
    recipe_catalog.as_json.to_json
  end

  def recipe_category_labels
    recipe_catalog.category_labels
  end

  def recipe_category_from_slug(slug)
    recipe_catalog.category_from_slug(slug)
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

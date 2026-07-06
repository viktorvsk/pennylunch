module RecipeHelper
  def rating_stars(rating, side: "bottom")
    value = number_with_precision(rating, precision: 2)
    filled_count = rating.to_f.round.clamp(0, 5)
    tag.span(
      safe_join(5.times.map do |index|
        tag.span("★", class: index < filled_count ? "text-amber-500" : "text-zinc-300")
      end),
      class: "recipe-rating",
      aria: { label: "Rating #{value} out of 5" },
      data: { tooltip: "Rating: #{value} out of 5", side:, align: "end" }
    )
  end

  def recipe_duration_text(minutes)
    total_minutes = minutes.to_i
    hours, remaining_minutes = total_minutes.divmod(60)
    parts = []
    parts << pluralize(hours, "hour") if hours.positive?
    parts << pluralize(remaining_minutes, "minute") if remaining_minutes.positive? || parts.empty?
    parts.join(" ")
  end

  def recipe_catalog
    Rails.cache.fetch([
      "recipes/catalog/v1",
      Ingredient.all.cache_key_with_version,
      Recipe.all.cache_key_with_version
    ]) do
      category_labels = Recipe.category_labels
      {
        ingredient_options: Ingredient.order(:name).pluck(:name, :optional).map { |name, optional| { name:, optional: } },
        category_labels:,
        category_slugs: category_labels.keys.to_h { |category| [ category, Recipe.category_slug_for(category) ] }
      }
    end
  end

  def recipe_filter_path(filters)
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
end

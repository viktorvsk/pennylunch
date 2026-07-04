module IngredientsHelper
  DEFAULT_INGREDIENT_SUMMARY_LIMIT = 8
  RecipeMatchReadiness = Data.define(:matched_count, :required_count, :percentage, :label, :tooltip, :ready)

  def ingredient_name_summary(recipe, limit: DEFAULT_INGREDIENT_SUMMARY_LIMIT)
    names = recipe.ingredient_names
    return "" if names.empty?

    suffix = names.size > limit ? " + #{names.size - limit} more" : ""
    "#{names.first(limit).join(", ")}#{suffix}"
  end

  def recipe_match_readiness(required_names, selected_names)
    matched_count = (required_names & selected_names).size
    required_count = required_names.size
    percentage = required_count.positive? ? ((matched_count.to_f / required_count) * 100).round : 0

    RecipeMatchReadiness.new(
      matched_count:,
      required_count:,
      percentage:,
      label: "#{percentage}%",
      tooltip: "Matches #{matched_count} of #{required_count} required ingredients in your selected ingredients. Pantry staples are not counted.",
      ready: required_count.positive? && matched_count == required_count
    )
  end

  def recipe_ingredient_groups(recipe)
    recipe.parsed_ingredients.partition { |ingredient| !ingredient.optional }
  end

  def ingredient_reference_url(name)
    "https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(name.to_s.squish.tr(" ", "_"))}"
  end
end

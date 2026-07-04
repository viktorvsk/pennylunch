module IngredientsHelper
  DEFAULT_INGREDIENT_SUMMARY_LIMIT = 8
  RecipeMatchReadiness = Data.define(:matched_count, :required_count, :percentage, :label, :tooltip, :ready)

  def ingredient_name_summary(recipe, limit: DEFAULT_INGREDIENT_SUMMARY_LIMIT)
    names = recipe.ingredient_names
    return "" if names.empty?

    suffix = names.size > limit ? " + #{names.size - limit} more" : ""
    "#{names.first(limit).join(", ")}#{suffix}"
  end

  def recipe_filter_ingredient_names(value)
    value.to_s.tr(",;", "\n").split("\n").filter_map { |name| Ingredient.normalize_lookup_key(name) }.uniq
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

  def recipe_ingredient_rows(recipe)
    recipe.ingredients.each_with_index.map do |ingredient, index|
      ingredient_row(recipe, ingredient, index)
    end
  end

  def recipe_ingredient_groups(recipe)
    recipe_ingredient_rows(recipe).partition { |row| !row[:optional] }
  end

  def ingredient_reference_url(name)
    "https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(name.to_s.squish.tr(" ", "_"))}"
  end

  private

  def ingredient_catalog_metadata
    @ingredient_catalog_metadata ||= IngredientCatalogMetadata.call
  end

  def ingredient_row(recipe, ingredient, index)
    metadata = ingredient_catalog_metadata
    parser = ingredient_parser_payload(recipe, index)
    amount = Array(parser["amount"]).find { |value| value.is_a?(Hash) } || {}
    names = Array(parser["name"]).select { |value| value.is_a?(Hash) }
    state = [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ].filter_map { |value| ingredient_parser_value(value) }.join(", ")
    name_parts = ingredient_name_parts(names, metadata)
    ingredient_name = ingredient_display_name(name_parts, recipe.ingredient_names[index].presence || ingredient.to_s)
    records = names.filter_map { |value| metadata[Ingredient.normalize_lookup_key(value["text"])] }.uniq(&:name)
    fallback_record = metadata[Ingredient.normalize_lookup_key(ingredient_name)]
    records << fallback_record if records.empty? && fallback_record.present?
    catalog_names = records.map(&:name)
    name_parts = [ { name: ingredient_name, catalog_name: catalog_names.first } ] if name_parts.empty?
    optional = records.any? && records.all?(&:optional)

    {
      size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
      unit: amount["unit"].presence,
      name: ingredient_name,
      name_parts:,
      catalog_name: catalog_names.first,
      catalog_names:,
      optional:,
      state:
    }
  end

  def ingredient_parser_payload(recipe, index)
    item = recipe.ingredient_parse_data[index]
    item.is_a?(Hash) && item["parser"].is_a?(Hash) ? item["parser"] : {}
  end

  def ingredient_parser_value(value)
    case value
    when Array
      value.filter_map { |item| ingredient_parser_value(item) }.join(", ").presence
    when Hash
      value["text"].presence || value["name"].presence || value.values.filter_map { |item| ingredient_parser_value(item) }.join(", ").presence
    else
      value.to_s.squish.presence
    end
  end

  def ingredient_name_parts(names, metadata)
    names.filter_map do |value|
      name = value["text"].to_s.squish.presence
      next if name.blank?

      record = metadata[Ingredient.normalize_lookup_key(name)]
      { name:, catalog_name: record&.name }
    end.uniq { |part| Ingredient.normalize_lookup_key(part[:name]) }
  end

  def ingredient_display_name(name_parts, fallback_name)
    names = name_parts.map { |part| part[:name] }
    names.presence&.to_sentence || fallback_name.to_s.squish
  end
end

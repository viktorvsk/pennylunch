module IngredientsHelper
  DEFAULT_INGREDIENT_SUMMARY_LIMIT = 8

  def recipe_ingredient_names(recipe)
    Array(recipe.ingredient_names).filter_map { |name| name.to_s.squish.presence }
  end

  def ingredient_name_summary(recipe, limit: DEFAULT_INGREDIENT_SUMMARY_LIMIT)
    names = recipe_ingredient_names(recipe)
    return "" if names.empty?

    visible_names = names.first(limit)
    remaining_count = names.size - visible_names.size
    suffix = remaining_count.positive? ? " + #{remaining_count} more" : ""
    "#{visible_names.join(", ")}#{suffix}"
  end

  def recipe_ingredient_catalog_names(recipe)
    lookup = ingredient_catalog_lookup
    recipe_ingredient_names(recipe).map { |name| lookup[Ingredient.normalize_lookup_key(name)] }
  end

  def recipe_ingredient_rows(recipe)
    metadata = ingredient_catalog_metadata
    Array(recipe.ingredients).each_with_index.map do |ingredient, index|
      parser = ingredient_parser_payload(recipe, index)
      amount = Array(parser["amount"]).find { |value| value.is_a?(Hash) } || {}
      names = Array(parser["name"]).select { |value| value.is_a?(Hash) }
      name = names.first || {}
      state = [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ].filter_map { |value| ingredient_parser_value(value) }.join(", ")
      ingredient_name = name["text"].presence || Array(recipe.ingredient_names)[index].presence || ingredient.to_s
      records = names.filter_map { |value| metadata[Ingredient.normalize_lookup_key(value["text"])] }.uniq { |record| record[:name] }
      fallback_record = metadata[Ingredient.normalize_lookup_key(ingredient_name)]
      records << fallback_record if records.empty? && fallback_record.present?
      catalog_names = records.map { |record| record[:name] }
      optional = records.any? && records.all? { |record| record[:optional] }

      {
        size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
        unit: amount["unit"].presence,
        name: ingredient_name,
        catalog_name: catalog_names.first,
        catalog_names:,
        optional:,
        state:
      }
    end
  end

  def recipe_ingredient_groups(recipe)
    recipe_ingredient_rows(recipe).partition { |row| !row[:optional] }
  end

  def ingredient_reference_url(name)
    "https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(name.to_s.squish.tr(" ", "_"))}"
  end

  private

  def ingredient_catalog_lookup
    @ingredient_catalog_lookup ||= Ingredient.lookup_map
  end

  def ingredient_catalog_metadata
    @ingredient_catalog_metadata ||= Ingredient.pluck(:name, :aliases, :optional).each_with_object({}) do |(name, aliases, optional), mapping|
      ([ name ] + Array(aliases)).each do |value|
        key = Ingredient.normalize_lookup_key(value)
        mapping[key] = { name:, optional: } if key.present?
      end
    end
  end

  def ingredient_parser_payload(recipe, index)
    item = Array(recipe.ingredient_parse_data)[index]
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
end

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

  def recipe_ingredient_rows(recipe)
    Array(recipe.ingredients).each_with_index.map do |ingredient, index|
      parser = ingredient_parser_payload(recipe, index)
      amount = Array(parser["amount"]).find { |value| value.is_a?(Hash) } || {}
      name = Array(parser["name"]).find { |value| value.is_a?(Hash) } || {}
      state = [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ].filter_map { |value| ingredient_parser_value(value) }.join(", ")

      {
        size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
        unit: amount["unit"].presence,
        name: name["text"].presence || Array(recipe.ingredient_names)[index].presence || ingredient.to_s,
        state:
      }
    end
  end

  def ingredient_reference_url(name)
    "https://en.wikipedia.org/wiki/#{ERB::Util.url_encode(name.to_s.squish.tr(" ", "_"))}"
  end

  private

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

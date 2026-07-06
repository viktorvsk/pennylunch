ParsedIngredient = Data.define(:size, :unit, :name, :name_parts, :catalog_name, :catalog_names, :optional, :state) do
  class << self
    def from_parser(raw_line, parse_item, metadata)
      parser = parser_for(parse_item)
      amount = amount_for(parser)
      names = Array(parser["name"]).select { |entry| entry.is_a?(Hash) }
      state = extract_state(parser)
      name_parts = name_parts_for(names, metadata)
      display_name = name_parts.map { it[:name] }.presence&.to_sentence || raw_line.to_s.squish
      records = records_for(names, display_name, metadata)
      catalog_names = records.map { it[:name] }
      name_parts = [ { name: display_name, catalog_name: catalog_names.first } ] if name_parts.empty?

      new(
        size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
        unit: amount["unit"].presence,
        name: display_name,
        name_parts:,
        catalog_name: catalog_names.first,
        catalog_names:,
        optional: records.any? && records.all? { it[:optional] },
        state:
      )
    end

    private

    def parser_for(parse_item)
      parse_item.is_a?(Hash) && parse_item["parser"].is_a?(Hash) ? parse_item["parser"] : {}
    end

    def amount_for(parser)
      Array(parser["amount"]).find { |entry| entry.is_a?(Hash) } || {}
    end

    def extract_state(parser)
      [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ]
        .filter_map { |value| extract_text_value(value) }.join(", ")
    end

    def name_parts_for(names, metadata)
      names.filter_map do |value|
        name = value["text"].to_s.squish.presence
        { name:, catalog_name: metadata[name]&.[](:name) } if name.present?
      end.uniq { it[:name] }
    end

    def records_for(names, display_name, metadata)
      records = names.filter_map { |value| metadata[value["text"].to_s.squish] }.uniq { it[:name] }
      records << metadata[display_name] if records.empty? && metadata[display_name].present?
      records
    end

    def extract_text_value(value)
      case value
      when Array
        value.filter_map { |item| extract_text_value(item) }.join(", ").presence
      when Hash
        value["text"].presence || value["name"].presence || value.values.filter_map { |item| extract_text_value(item) }.join(", ").presence
      else
        value.to_s.squish.presence
      end
    end
  end
end

ParsedIngredient = Data.define(:size, :unit, :name, :name_parts, :catalog_name, :catalog_names, :optional, :state) do
  class << self
    def from_parser(raw_line, parse_item, metadata)
      parser = extract_parser(parse_item)
      amount = Array(parser["amount"]).find { |entry| entry.is_a?(Hash) } || {}
      names = Array(parser["name"]).select { |entry| entry.is_a?(Hash) }
      state = extract_state(parser)
      name_parts = resolve_name_parts(names, metadata)
      display_name = display_name_for(name_parts, raw_line)
      records = resolve_records(names, display_name, metadata)
      catalog_names = records.map(&:name)
      name_parts = [ { name: display_name, catalog_name: catalog_names.first } ] if name_parts.empty?

      new(
        size: amount["quantity"].presence || amount["quantity_max"].presence || amount["text"].presence,
        unit: amount["unit"].presence,
        name: display_name,
        name_parts:,
        catalog_name: catalog_names.first,
        catalog_names:,
        optional: records.any? && records.all?(&:optional),
        state:
      )
    end

    private

    def extract_parser(parse_item)
      parse_item.is_a?(Hash) && parse_item["parser"].is_a?(Hash) ? parse_item["parser"] : {}
    end

    def extract_state(parser)
      [ parser["preparation"], parser["comment"], parser["purpose"], parser["size"] ]
        .filter_map { |value| extract_text_value(value) }.join(", ")
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

    def resolve_name_parts(names, metadata)
      names.filter_map do |value|
        name = value["text"].to_s.squish.presence
        next if name.blank?

        record = metadata[name]
        { name:, catalog_name: record&.name }
      end.uniq { |part| part[:name] }
    end

    def display_name_for(name_parts, fallback)
      names = name_parts.map { |part| part[:name] }
      names.presence&.to_sentence || fallback.to_s.squish
    end

    def resolve_records(names, display_name, metadata)
      records = names.filter_map { |value| metadata[value["text"].to_s.squish] }.uniq(&:name)
      if records.empty?
        fallback = metadata[display_name]
        records << fallback if fallback.present?
      end
      records
    end
  end
end

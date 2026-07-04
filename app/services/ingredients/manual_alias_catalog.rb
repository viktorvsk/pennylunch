require "yaml"

module Ingredients
  class ManualAliasCatalog
    Entry = Data.define(:name, :aliases, :optional)

    class Error < StandardError; end

    DEFAULT_PATH = Rails.root.join("config/ingredient_aliases.yml")

    def self.load(path: DEFAULT_PATH)
      new(path:).load
    end

    def initialize(path:)
      @path = Pathname(path)
    end

    def load
      payload = YAML.safe_load(path.read) || {}
      entries = entries_from(payload.fetch("ingredients"))
      validate_entries(entries)
      entries
    rescue KeyError
      raise Error, "manual ingredient alias catalog must contain ingredients"
    rescue Psych::SyntaxError => error
      raise Error, "manual ingredient alias catalog is invalid YAML: #{error.message}"
    end

    private

    attr_reader :path

    def entries_from(ingredients)
      raise Error, "manual ingredient alias catalog ingredients must be a map" unless ingredients.is_a?(Hash)

      ingredients.map do |name, definition|
        normalized_name = Ingredient.normalize_lookup_key(name)
        raise Error, "ingredient name #{name.inspect} must be canonical and must not contain commas" if normalized_name.to_s.include?(",")

        aliases, optional = definition_from(name, definition)
        normalized_aliases = aliases.filter_map { |alias_name| alias_name.to_s.squish.downcase.presence }.uniq
        raise Error, "ingredient #{name.inspect} must have at least one alias" if normalized_aliases.empty?

        Entry.new(normalized_name, normalized_aliases, optional)
      end
    end

    def definition_from(name, definition)
      case definition
      when Array
        [ definition, false ]
      when Hash
        aliases = definition.fetch("aliases") do
          raise Error, "ingredient #{name.inspect} must define aliases"
        end
        [ aliases, definition["optional"] == true ]
      else
        raise Error, "ingredient #{name.inspect} must be an alias array or map"
      end
    end

    def normalized_aliases_for(entry)
      entry.aliases.filter_map { |alias_name| Ingredient.normalize_lookup_key(alias_name) }
    end

    def validate_entries(entries)
      names = entries.map(&:name)
      duplicate_names = names.tally.select { |_name, count| count > 1 }.keys
      raise Error, "duplicate ingredient names: #{duplicate_names.join(', ')}" if duplicate_names.any?

      alias_owners = entries.each_with_object({}) do |entry, owners|
        normalized_aliases_for(entry).each { |alias_name| (owners[alias_name] ||= []) << entry.name }
      end
      duplicate_aliases = alias_owners.select { |_alias_name, owners| owners.uniq.size > 1 }
      raise Error, "aliases assigned to multiple ingredients: #{duplicate_aliases.keys.join(', ')}" if duplicate_aliases.any?

      names_by_lookup_key = entries.to_h { |entry| [ Ingredient.normalize_lookup_key(entry.name), entry.name ] }
      alias_name_collisions = entries.flat_map do |entry|
        normalized_aliases_for(entry).filter_map do |alias_name|
          owner = names_by_lookup_key[alias_name]
          alias_name if owner.present? && owner != entry.name
        end
      end.uniq
      raise Error, "aliases match other ingredient names: #{alias_name_collisions.join(', ')}" if alias_name_collisions.any?
    end
  end
end

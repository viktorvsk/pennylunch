module Ingredients
  class SyncFromAliasCatalog
    Result = Data.define(:ingredient_count, :alias_count, :optional_count)

    class Error < StandardError; end

    class UnmappedIngredientNamesError < Error
      attr_reader :names

      def initialize(names)
        @names = names
        super("manual ingredient alias catalog is missing #{names.size} raw recipe ingredient names: #{names.first(25).join(', ')}")
      end
    end

    def self.call(catalog: ManualAliasCatalog.load, raw_names: nil, recipe_coverage: :validate)
      new(catalog:, raw_names:, recipe_coverage:).call
    end

    def initialize(catalog:, raw_names:, recipe_coverage:)
      @catalog = catalog
      @raw_names = raw_names
      @recipe_coverage = recipe_coverage
    end

    def call
      if validate_recipe_coverage?
        missing_names = unmapped_recipe_names
        raise UnmappedIngredientNamesError, missing_names if missing_names.any?
      end

      Ingredient.transaction do
        Ingredient.delete_all
        catalog.each do |entry|
          Ingredient.create!(name: entry.name, aliases: entry.aliases, optional: entry.optional)
        end
      end

      Result.new(
        ingredient_count: catalog.size,
        alias_count: catalog.sum { |entry| entry.aliases.size },
        optional_count: catalog.count(&:optional)
      )
    end

    private

    attr_reader :catalog, :raw_names, :recipe_coverage

    def validate_recipe_coverage?
      recipe_coverage == :validate
    end

    def unmapped_recipe_names
      return [] if recipe_ingredient_names.empty?

      keys = catalog.flat_map(&:aliases).filter_map { |alias_name| Ingredient.normalize_lookup_key(alias_name) }.uniq
      recipe_ingredient_names.reject { |name| keys.include?(Ingredient.normalize_lookup_key(name)) }.uniq.sort
    end

    def recipe_ingredient_names
      @recipe_ingredient_names ||= Array(raw_names || raw_recipe_ingredient_names).filter_map { |name| name.to_s.squish.downcase.presence }.uniq
    end

    def raw_recipe_ingredient_names
      Recipe.pluck(:ingredient_parse_data, :ingredient_names).flat_map do |parse_data, fallback_names|
        parser_names = parser_names_from(parse_data)
        parser_names.any? ? parser_names : fallback_names
      end
    end

    def parser_names_from(parse_data)
      Array(parse_data).flat_map do |entry|
        parser_name = entry.dig("parser", "name") if entry.is_a?(Hash)
        Array(parser_name).filter_map { |name| name.is_a?(Hash) ? name["text"] : name }
      end
    end
  end
end

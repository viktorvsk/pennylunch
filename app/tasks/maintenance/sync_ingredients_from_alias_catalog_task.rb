require "yaml"

module Maintenance
  # Upserts Ingredient records from the repository-owned YAML file.
  #
  # What it changes:
  # It creates or updates the Ingredient rows listed in `config/ingredient_aliases.yml`, returning the number
  # of catalog entries processed. Ingredients that are not listed in the YAML file are left alone.
  #
  # Why this exists:
  # Ingredient resolution is a reviewed catalog decision, not an inflection heuristic. The catalog records
  # which raw parser/source phrases map to each canonical Ingredient name and which Ingredients should be
  # optional for vector search. Deleting Ingredients is a separate admin decision handled in Avo, so this
  # task only applies the repository-owned catalog entries.
  #
  # How it works:
  # The task loads YAML, converts each ingredient entry into model attributes, finds or initializes the
  # Ingredient by normalized canonical name, and saves it through the model. All normalization and
  # cross-record alias validation stays in the Ingredient model.
  class SyncIngredientsFromAliasCatalogTask < MaintenanceTasks::Task
    CATALOG_PATH = Rails.root.join("config/ingredient_aliases.yml")

    no_collection

    def process
      upsert_ingredients(ingredient_attributes_from_catalog)
    end

    private

    def upsert_ingredients(ingredient_attributes)
      Ingredient.transaction do
        ingredient_attributes.each do |attributes|
          Ingredient.find_or_initialize_by(name: Ingredient.normalize_lookup_key(attributes.fetch(:name))).update!(
            aliases: attributes.fetch(:aliases),
            optional: attributes.fetch(:optional)
          )
        end
      end

      ingredient_attributes.size
    end

    def ingredient_attributes_from_catalog
      payload = YAML.safe_load(CATALOG_PATH.read) || {}
      ingredients = payload.fetch("ingredients") do
        raise "manual ingredient alias catalog must contain ingredients"
      end
      raise "manual ingredient alias catalog ingredients must be a map" unless ingredients.is_a?(Hash)

      ingredients.map do |name, definition|
        aliases, optional = ingredient_definition(name, definition)
        { name:, aliases:, optional: optional == true }
      end
    rescue Psych::SyntaxError => error
      raise "manual ingredient alias catalog is invalid YAML: #{error.message}"
    end

    def ingredient_definition(name, definition)
      case definition
      when Array
        [ definition, false ]
      when Hash
        [
          definition.fetch("aliases") do
            raise "ingredient #{name.inspect} must define aliases"
          end,
          definition["optional"]
        ]
      else
        raise "ingredient #{name.inspect} must be an alias array or map"
      end
    end
  end
end

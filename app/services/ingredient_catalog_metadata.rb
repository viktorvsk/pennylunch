# Returns a cached hash of all catalog ingredient names and aliases mapped to metadata.
# Shape: { "normalized_key" => IngredientCatalogMetadata::Entry }
# Example: { "green onion" => IngredientCatalogMetadata::Entry(name: "Onion", optional: false) }
class IngredientCatalogMetadata
  Entry = Data.define(:name, :optional)
  CACHE_KEY = "ingredients/catalog_metadata/v2"

  class << self
    def call
      Rails.cache.fetch(CACHE_KEY) do
        Ingredient.pluck(:name, :aliases, :optional).each_with_object({}) do |(name, aliases, optional), mapping|
          [ name, *aliases ].each do |value|
            mapping[value] = Entry.new(name:, optional:)
          end
        end
      end
    end
  end
end

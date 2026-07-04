# Reads the ingredient catalog into the cached lookup used when displaying parsed
# recipe ingredients and resolving parser output.
#
# Returns a `Hash<String, IngredientCatalogMetadata::Entry>` keyed by every
# canonical ingredient name and alias, including optional ingredients. Values
# expose the canonical `name` and whether that ingredient is `optional`.
#
# Example shape:
#   { "green onion" => IngredientCatalogMetadata::Entry(name: "onion", optional: false) }
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

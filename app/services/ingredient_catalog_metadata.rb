# Returns a cached hash of all catalog ingredient names and aliases mapped to metadata.
# Shape: { "normalized_key" => IngredientMetadata }
# Example: { "green onion" => IngredientMetadata(name: "Onion", optional: false) }
class IngredientCatalogMetadata
  class << self
    def call
      Rails.cache.fetch("ingredients/catalog_metadata") do
        Ingredient.pluck(:name, :aliases, :optional).each_with_object({}) do |(name, aliases, optional), mapping|
          ([ name ] + aliases).each do |value|
            key = Ingredient.normalize_lookup_key(value)
            mapping[key] = IngredientMetadata.new(name:, optional:) if key.present?
          end
        end
      end
    end
  end
end

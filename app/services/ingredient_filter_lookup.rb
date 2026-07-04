# Returns a cached hash of non-optional catalog ingredient names and aliases mapped to canonical name.
# Shape: { "normalized_key" => "Canonical Name" }
# Example: { "spaghetti" => "Pasta" }
class IngredientFilterLookup
  class << self
    def call
      Rails.cache.fetch("ingredients/filterable_lookup_map") do
        Ingredient.where(optional: false).pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
          ([ name ] + aliases).each do |value|
            key = Ingredient.normalize_lookup_key(value)
            mapping[key] = name if key.present?
          end
        end
      end
    end
  end
end

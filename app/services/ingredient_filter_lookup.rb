# Reads the filterable ingredient catalog into the cached lookup used by recipe
# indexing.
#
# Returns a `Hash<String, String>` keyed by every non-optional canonical name and
# alias. Values are canonical ingredient names, so parser output can be collapsed
# to the stable names used by basket filtering and vector generation.
#
# Example shape:
#   { "spaghetti" => "pasta" }
class IngredientFilterLookup
  class << self
    def call
      Rails.cache.fetch("ingredients/filterable_lookup_map") do
        Ingredient.where(optional: false).pluck(:name, :aliases).each_with_object({}) do |(name, aliases), mapping|
          [ name, *aliases ].each do |value|
            mapping[value] = name
          end
        end
      end
    end
  end
end

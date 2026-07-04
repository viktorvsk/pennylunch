class Catalog < Data.define(:ingredient_options, :category_labels, :category_slugs)
  CACHE_KEY = "recipes/catalog/v1"

  class << self
    def fetch
      Rails.cache.fetch(cache_key) { build }
    end

    def cache_key
      [
        CACHE_KEY,
        Ingredient.all.cache_key_with_version,
        Recipe.all.cache_key_with_version
      ]
    end

    private

    def build
      category_labels = Recipe.category_labels

      new(
        ingredient_options: Ingredient.order(:name).pluck(:name, :optional).map { |name, optional| { name:, optional: } },
        category_labels:,
        category_slugs: category_labels.keys.to_h { |category| [ category, Recipe.category_slug_for(category) ] }
      )
    end
  end

  def category_from_slug(slug)
    category_slugs.key(slug.to_s)
  end

  def as_json(*)
    {
      ingredientOptions: ingredient_options,
      categoryLabels: category_labels,
      categorySlugs: category_slugs
    }
  end
end

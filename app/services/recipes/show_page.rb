module Recipes
  class ShowPage
    Result = Data.define(:recipe, :similar_recipes, :ingredient_options)

    def initialize(slug:)
      @slug = slug
    end

    def call
      recipe = Recipe.find_by!(slug:)

      Result.new(
        recipe:,
        similar_recipes: Recipes::SimilarRecipesQuery.new(recipe:).call,
        ingredient_options: Ingredient.filter_options
      )
    end

    private

    attr_reader :slug
  end
end

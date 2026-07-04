class IndexRecipeJob < ApplicationJob
  def perform(recipe_ids = "all")
    recipes = (recipe_ids == "all" ? Recipe.all : Recipe.where(id: recipe_ids)).to_a
    return if recipes.empty?

    parser_results = IngredientParser.call(recipes.map(&:ingredients))
    ingredient_lookup = Ingredient.filterable_lookup_map
    entries = recipes.zip(parser_results).map do |recipe, parser_result|
      RecipeIndexEntry.from(recipe:, parser_result:, ingredient_lookup:)
    end

    Recipe.transaction do
      Recipe.connection.execute(RecipeIndexUpdateQuery.call(entries:), RecipeIndexUpdateQuery.name)
      Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: recipes.map(&:id)), RecipeIngredientRecomputeQuery.name)
    end
  end
end

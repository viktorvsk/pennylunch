class IndexRecipeJob < ApplicationJob
  BATCH_SIZE = 100

  def perform(recipe_ids)
    (recipe_ids == "all" ? Recipe.all : Recipe.where(id: recipe_ids)).in_batches(of: BATCH_SIZE) do |batch|
      index_recipes(batch.to_a)
    end
  end

  private

  def index_recipes(recipes)
    parser_results = IngredientParser.call(recipes.map(&:ingredients))
    ingredient_lookup = Ingredient.filterable_lookup
    entries = recipes.zip(parser_results).map do |recipe, parser_result|
      vector_names = parser_result.ingredient_names.filter_map { ingredient_lookup[it] }.uniq
      [
        recipe.id,
        parser_result.ingredient_names,
        parser_result.ingredient_parse_data,
        LocalEmbedding.call(vector_names.join("\n"))
      ]
    end

    Recipe.transaction do
      Recipe.connection.execute(RecipeIndexUpdateQuery.call(entries:), RecipeIndexUpdateQuery.name)
      Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: recipes.map(&:id)), RecipeIngredientRecomputeQuery.name)
    end
  end
end

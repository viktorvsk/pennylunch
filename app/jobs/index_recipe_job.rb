class IndexRecipeJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 128

  def perform(recipe_ids = "all")
    recipes = recipe_ids == "all" ? Recipe.all : Recipe.where(id: Array(recipe_ids).compact_blank.map { |id| Integer(id) })

    recipes.in_batches(of: BATCH_SIZE) do |records|
      process_batch(records.to_a)
    end
  end

  private

  def process_batch(recipes)
    return if recipes.empty?

    entries = entries_for(recipes)

    Recipe.transaction do
      Recipe.connection.execute(RecipeIndexUpdateQuery.call(entries:), RecipeIndexUpdateQuery.name)
      Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: recipes.map(&:id)), RecipeIngredientRecomputeQuery.name)
    end
  end

  def entries_for(recipes)
    parser_results = IngredientParser.call(recipes.map(&:ingredients))
    ingredient_lookup = Ingredient.filterable_lookup_map

    recipes.zip(parser_results).map do |recipe, parser_result|
      RecipeIndexEntry.from(recipe:, parser_result:, ingredient_lookup:)
    end
  end
end

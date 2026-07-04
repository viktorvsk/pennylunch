class IndexRecipeJob < ApplicationJob
  DEFAULT_BATCH_SIZE = 100
  MAX_BATCH_SIZE = 1_000

  def perform(recipe_ids = "all")
    recipe_scope(recipe_ids).in_batches(of: recipe_index_batch_size) do |batch|
      index_recipes(batch.to_a)
    end
  end

  private

  def recipe_scope(recipe_ids)
    recipe_ids == "all" ? Recipe.all : Recipe.where(id: recipe_ids)
  end

  def recipe_index_batch_size
    size = SETTINGS.recipe_index_batch_size.to_s.to_i
    return DEFAULT_BATCH_SIZE if size <= 0

    [ size, MAX_BATCH_SIZE ].min
  end

  def index_recipes(recipes)
    return if recipes.empty?
    parser_results = IngredientParser.call(recipes.map(&:ingredients))
    ingredient_lookup = IngredientFilterLookup.call
    entries = recipes.zip(parser_results).map do |recipe, parser_result|
      RecipeIndexEntry.from(recipe:, parser_result:, ingredient_lookup:)
    end

    Recipe.transaction do
      Recipe.connection.execute(RecipeIndexUpdateQuery.call(entries:), RecipeIndexUpdateQuery.name)
      Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: recipes.map(&:id)), RecipeIngredientRecomputeQuery.name)
    end
  end
end

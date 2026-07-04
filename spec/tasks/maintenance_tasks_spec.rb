require "rails_helper"

RSpec.describe "Maintenance tasks" do
  it "warms the local embedding model" do
    allow(LocalEmbedding).to receive(:warm!)

    Maintenance::WarmEmbeddingModelTask.new.process

    expect(LocalEmbedding).to have_received(:warm!)
  end

  it "imports recipes through the import service" do
    allow(Recipes::Import).to receive(:call)

    Maintenance::ImportRecipesTask.new.process

    expect(Recipes::Import).to have_received(:call)
  end

  it "backfills a missing recipe vector" do
    create(:ingredient, name: "chicken breast", aliases: [ "chicken breasts" ])
    create(:ingredient, name: "lemon")
    create(:ingredient, name: "salt", optional: true)
    recipe = create(:recipe, ingredients_vector: nil)
    vector = Array.new(384, 0.1)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "lemon", "chicken breasts", "salt" ], recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return([ vector ])

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(recipe)

    expect(recipe.reload.ingredient_names).to eq([ "lemon", "chicken breasts", "salt" ])
    expect(recipe.reload.ingredients_vector_names).to eq([ "lemon", "chicken breast" ])
    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(recipe.reload.ingredients_vector).to eq(vector)
    expect(LocalEmbedding).to have_received(:call).with([ "lemon\nchicken breast" ])
  end

  it "embeds vector backfill batches with one model call" do
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "basil", optional: true)
    create(:ingredient, name: "chicken")
    create(:ingredient, name: "garlic")
    first = create(:recipe, ingredients_vector: nil, ingredients: [ "tomatoes", "basil" ])
    second = create(:recipe, ingredients_vector: nil, ingredients: [ "chicken", "garlic" ])
    vectors = [
      Array.new(384, 0.2),
      Array.new(384, 0.3)
    ]
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "tomatoes", "basil" ], first.ingredients),
      parser_result([ "chicken", "garlic" ], second.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vectors)

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(Recipe.where(id: [ first.id, second.id ]).order(:id))

    expect(IngredientParser).to have_received(:call).with([
      first.ingredients,
      second.ingredients
    ])
    expect(LocalEmbedding).to have_received(:call).with([
      "tomato",
      "chicken\ngarlic"
    ])
    expect(first.reload.ingredient_names).to eq([ "tomatoes", "basil" ])
    expect(first.reload.ingredients_vector_names).to eq([ "tomato" ])
    expect(first.reload.ingredients_vector).to eq(vectors.first)
    expect(second.reload.ingredient_names).to eq([ "chicken", "garlic" ])
    expect(second.reload.ingredients_vector_names).to eq([ "chicken", "garlic" ])
    expect(second.reload.ingredients_vector).to eq(vectors.second)
  end

  it "backfills parser data without re-embedding when names and vectors are current" do
    recipe = create(
      :recipe,
      ingredient_names: [ "lemon", "chicken breast", "salt" ],
      ingredient_parse_data: [],
      ingredients_vector: Array.new(384, 0.4),
      ingredients_vector_names: [ "lemon", "chicken breast", "salt" ]
    )
    recipe.ingredient_names.each { |name| create(:ingredient, name:) }
    allow(IngredientParser).to receive(:call).and_return([
      parser_result(recipe.ingredient_names, recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call)

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(recipe)

    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(LocalEmbedding).not_to have_received(:call)
  end

  it "restores raw recipe ingredient names from stored parser data" do
    recipe = create(
      :recipe,
      ingredients: [ "1 cup wheat, rye, and flax hot cereal mix", "2 ripe avocados" ],
      ingredient_names: [ "cereal mix", "avocado" ],
      ingredients_vector_names: [ "cereal mix", "avocado" ],
      ingredient_parse_data: [
        {
          "input" => "1 cup wheat, rye, and flax hot cereal mix",
          "parser" => {
            "name" => [
              { "text" => "wheat, rye, and flax hot cereal mix" }
            ]
          }
        },
        {
          "input" => "2 ripe avocados",
          "parser" => {
            "name" => [
              { "text" => "ripe avocados" }
            ]
          }
        }
      ]
    )

    Maintenance::RestoreRecipeRawIngredientNamesTask.new.process(recipe)

    expect(recipe.reload.ingredient_names).to eq([ "wheat, rye, and flax hot cereal mix", "ripe avocados" ])
    expect(recipe.reload.ingredients_vector_names).to eq([ "cereal mix", "avocado" ])
  end

  it "syncs ingredients from the manual alias catalog" do
    allow(Ingredients::SyncFromAliasCatalog).to receive(:call)

    Maintenance::SyncIngredientsFromAliasCatalogTask.new.process

    expect(Ingredients::SyncFromAliasCatalog).to have_received(:call)
  end

  it "reloads ingredients from the manual alias catalog without recipe coverage checks" do
    allow(Ingredients::SyncFromAliasCatalog).to receive(:call)

    Maintenance::ReloadIngredientsFromAliasCatalogTask.new.process

    expect(Ingredients::SyncFromAliasCatalog).to have_received(:call).with(recipe_coverage: :skip)
  end

  it "keeps the legacy ingredient bootstrap task on the manual catalog path" do
    allow(Ingredients::SyncFromAliasCatalog).to receive(:call)

    Maintenance::BootstrapIngredientsFromRecipeNamesTask.new.process

    expect(Ingredients::SyncFromAliasCatalog).to have_received(:call)
  end

  it "deletes recipes without deleting ingredients" do
    create(:recipe)
    ingredient = create(:ingredient, name: "salt")

    Maintenance::DeleteRecipesTask.new.process

    expect(Recipe.count).to eq(0)
    expect(Ingredient.find_by(id: ingredient.id)).to be_present
  end

  it "deletes ingredients without deleting recipes" do
    recipe = create(:recipe)
    create(:ingredient, name: "salt")

    Maintenance::DeleteIngredientsTask.new.process

    expect(Ingredient.count).to eq(0)
    expect(Recipe.find_by(id: recipe.id)).to be_present
  end

  it "deletes recipes and ingredients for local data resets" do
    create(:recipe)
    create(:ingredient, name: "salt")

    Maintenance::DeleteRecipesAndIngredientsTask.new.process

    expect(Recipe.count).to eq(0)
    expect(Ingredient.count).to eq(0)
  end

  def parser_result(names, ingredients)
    IngredientParser::Result.new(names, parse_data_for(ingredients))
  end

  def parse_data_for(ingredients)
    ingredients.map do |ingredient|
      {
        "input" => ingredient,
        "parser" => {
          "sentence" => ingredient
        }
      }
    end
  end
end

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
    recipe = create(:recipe, ingredients_vector: nil)
    vector = Array.new(384, 0.1)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "lemon", "chicken breasts", "salt" ], recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return([ vector ])

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(recipe)

    expect(recipe.reload.ingredient_names).to eq([ "lemon", "chicken breasts", "salt" ])
    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(recipe.reload.ingredients_vector).to eq(vector)
  end

  it "embeds vector backfill batches with one model call" do
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
      "tomatoes\nbasil",
      "chicken\ngarlic"
    ])
    expect(first.reload.ingredient_names).to eq([ "tomatoes", "basil" ])
    expect(first.reload.ingredients_vector).to eq(vectors.first)
    expect(second.reload.ingredient_names).to eq([ "chicken", "garlic" ])
    expect(second.reload.ingredients_vector).to eq(vectors.second)
  end

  it "backfills parser data without re-embedding when names and vectors are current" do
    recipe = create(:recipe, ingredient_parse_data: [], ingredients_vector: Array.new(384, 0.4))
    allow(IngredientParser).to receive(:call).and_return([
      parser_result(recipe.ingredient_names, recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call)

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(recipe)

    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(LocalEmbedding).not_to have_received(:call)
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

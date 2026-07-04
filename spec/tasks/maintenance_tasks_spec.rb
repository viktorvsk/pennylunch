require "rails_helper"

RSpec.describe "Maintenance tasks" do
  it "imports recipes through the import service with the task URL" do
    allow(RecipeImport).to receive(:call)
    task = Maintenance::ImportRecipesTask.new
    task.url = "https://example.test/recipes.json.gz"

    task.process

    expect(RecipeImport).to have_received(:call).with(url: "https://example.test/recipes.json.gz")
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
    expect(first.reload.ingredients_vector).to eq(vectors.first)
    expect(second.reload.ingredient_names).to eq([ "chicken", "garlic" ])
    expect(second.reload.ingredients_vector).to eq(vectors.second)
  end

  it "regenerates vectors from current catalog names" do
    recipe = create(
      :recipe,
      ingredient_names: [ "lemon", "chicken breast", "salt" ],
      ingredient_parse_data: [],
      ingredients_vector: Array.new(384, 0.4)
    )
    recipe.ingredient_names.each { |name| create(:ingredient, name:) }
    vector = Array.new(384, 0.5)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result(recipe.ingredient_names, recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return([ vector ])

    Maintenance::BackfillRecipeIngredientVectorsTask.new.process(recipe)

    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(recipe.reload.ingredients_vector).to eq(vector)
    expect(LocalEmbedding).to have_received(:call).with([ "lemon\nchicken breast\nsalt" ])
  end

  it "upserts ingredients from the manual alias catalog" do
    avocado = create(:ingredient, name: "avocado", aliases: [ "old avocado" ])
    retained = create(:ingredient, name: "turmeric", aliases: [ "turmeric" ])

    with_alias_catalog(<<~YAML) do
      ingredients:
        avocado:
          aliases:
            - avocado
            - avocados
            - ripe avocado
        salt:
          optional: true
          aliases:
            - salt
            - kosher salt
    YAML

      synced_count = Maintenance::SyncIngredientsFromAliasCatalogTask.new.process

      expect(synced_count).to eq(2)
      expect(avocado.reload.aliases).to eq([ "avocado", "avocados", "ripe avocado" ])
      expect(Ingredient.find_by!(name: "salt")).to be_optional
      expect(Ingredient.find_by(id: retained.id)).to be_present
    end
  end

  it "lets Ingredient model validations reject invalid catalog rows without changing ingredients" do
    existing = create(:ingredient, name: "salt", aliases: [ "salt" ])
    with_alias_catalog(<<~YAML) do
      ingredients:
        avocado:
          aliases:
            - avocado
        guacamole:
          aliases:
            - avocado
    YAML

      expect { Maintenance::SyncIngredientsFromAliasCatalogTask.new.process }
        .to raise_error(ActiveRecord::RecordInvalid, /Aliases must be unique across ingredients/)
      expect(Ingredient.pluck(:id)).to eq([ existing.id ])
    end
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

  def with_alias_catalog(yaml)
    path = Rails.root.join("tmp/test-ingredient-aliases.yml")
    path.write(yaml)
    stub_const("Maintenance::SyncIngredientsFromAliasCatalogTask::CATALOG_PATH", path)
    yield
  ensure
    path.delete if path&.exist?
  end
end

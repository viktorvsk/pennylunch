require "rails_helper"

RSpec.describe "Avo-queued jobs", type: :job do
  it "imports recipes through the import service with the given URL" do
    allow(RecipeImport).to receive(:call)

    ImportRecipesJob.perform_now("https://example.test/recipes.json.gz")

    expect(RecipeImport).to have_received(:call).with(url: "https://example.test/recipes.json.gz")
  end

  it "imports recipes through the import service with the default URL" do
    allow(RecipeImport).to receive(:call)

    ImportRecipesJob.perform_now

    expect(RecipeImport).to have_received(:call).with(url: RecipeImport::DEFAULT_URL)
  end

  it "sets vector recipe search through the search strategy job" do
    with_memory_cache do |cache|
      SetRecipeSearchStrategyJob.perform_now("vector")

      expect(cache.read("search_strategy")).to eq("vector")
    end
  end

  it "clears recipe search strategy through the search strategy job" do
    with_memory_cache do |cache|
      cache.write("search_strategy", "vector")

      SetRecipeSearchStrategyJob.perform_now("overlap")

      expect(cache.read("search_strategy")).to eq("overlap")
    end
  end

  it "rejects unknown recipe search strategies" do
    expect { SetRecipeSearchStrategyJob.perform_now("naive_vector_search") }
      .to raise_error(ArgumentError, "unknown recipe search strategy: naive_vector_search")
  end

  it "indexes a missing recipe vector" do
    create(:ingredient, name: "chicken breast", aliases: [ "chicken breasts" ])
    create(:ingredient, name: "lemon")
    create(:ingredient, name: "salt", optional: true)
    stale = create(:ingredient, name: "apple")
    recipe = create(:recipe, ingredients_vector: nil)
    create(:recipe_ingredient, recipe:, ingredient: stale)
    vector = Array.new(384, 0.1)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "lemon", "chicken breasts", "salt" ], recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector)

    IndexRecipeJob.perform_now([ recipe.id ])

    expect(recipe.reload.ingredient_names).to eq([ "lemon", "chicken breasts", "salt" ])
    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(recipe.reload.ingredients_vector).to eq(vector)
    expect(recipe.resolved_ingredients.order(:name).pluck(:name)).to eq([ "chicken breast", "lemon", "salt" ])
    expect(LocalEmbedding).to have_received(:call).with("lemon\nchicken breast")
  end

  it "indexes selected recipes with one recipe update and one ingredient recompute" do
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
    allow(IngredientParser).to receive(:call) do |ingredient_batches|
      ingredient_batches.map do |ingredients|
        if ingredients == first.ingredients
          parser_result([ "tomatoes", "basil" ], first.ingredients)
        else
          parser_result([ "chicken", "garlic" ], second.ingredients)
        end
      end
    end
    allow(LocalEmbedding).to receive(:call) do |text|
      text == "tomato" ? vectors.first : vectors.second
    end

    statements = recorded_sql do
      IndexRecipeJob.perform_now([ first.id, second.id ])
    end
    update_statements = statements.grep(/\AUPDATE "recipes"/)
    recompute_statements = statements.grep(/\AWITH target_recipes AS/)

    expect(IngredientParser).to have_received(:call).once.with(contain_exactly(first.ingredients, second.ingredients))
    expect(LocalEmbedding).to have_received(:call).twice
    expect(LocalEmbedding).to have_received(:call).with("tomato")
    expect(LocalEmbedding).to have_received(:call).with("chicken\ngarlic")
    expect(first.reload.ingredient_names).to eq([ "tomatoes", "basil" ])
    expect(first.reload.ingredients_vector).to eq(vectors.first)
    expect(first.resolved_ingredients.order(:name).pluck(:name)).to eq([ "basil", "tomato" ])
    expect(second.reload.ingredient_names).to eq([ "chicken", "garlic" ])
    expect(second.reload.ingredients_vector).to eq(vectors.second)
    expect(second.resolved_ingredients.order(:name).pluck(:name)).to eq([ "chicken", "garlic" ])
    expect(update_statements.size).to eq(1)
    expect(recompute_statements.size).to eq(1)
    expect(recompute_statements.first).to include("SELECT DISTINCT")
  end

  it "regenerates vectors for all recipes from current catalog names" do
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
    allow(LocalEmbedding).to receive(:call).and_return(vector)

    IndexRecipeJob.perform_now("all")

    expect(recipe.reload.ingredient_parse_data).to eq(parse_data_for(recipe.ingredients))
    expect(recipe.reload.ingredients_vector).to eq(vector)
    expect(recipe.resolved_ingredients.order(:name).pluck(:name)).to eq([ "chicken breast", "lemon", "salt" ])
    expect(LocalEmbedding).to have_received(:call).with("lemon\nchicken breast\nsalt")
  end

  it "clears stale vectors when recipe indexing has no filterable catalog names" do
    stale = create(:ingredient, name: "apple")
    recipe = create(:recipe, ingredients_vector: Array.new(384, 0.4))
    create(:recipe_ingredient, recipe:, ingredient: stale)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "unknown sauce" ], recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call)

    IndexRecipeJob.perform_now([ recipe.id ])

    expect(recipe.reload.ingredients_vector).to be_nil
    expect(recipe.ingredient_names).to eq([ "unknown sauce" ])
    expect(recipe.resolved_ingredients).to be_empty
    expect(LocalEmbedding).not_to have_received(:call)
  end

  it "rolls back recipe index updates when ingredient recompute SQL fails" do
    create(:ingredient, name: "lemon")
    recipe = create(
      :recipe,
      ingredient_names: [ "old lemon" ],
      ingredient_parse_data: [ { "input" => "old lemon" } ],
      ingredients_vector: Array.new(384, 0.4)
    )
    original_parse_data = recipe.ingredient_parse_data
    original_vector = recipe.ingredients_vector
    vector = Array.new(384, 0.5)
    allow(IngredientParser).to receive(:call).and_return([
      parser_result([ "lemon" ], recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector)
    connection = Recipe.connection
    allow(connection).to receive(:exec_query).and_call_original
    allow(connection).to receive(:exec_query)
      .with(kind_of(String), RecipeIngredientRecomputeQuery.name)
      .and_raise(ActiveRecord::StatementInvalid.new("boom"))

    expect { IndexRecipeJob.perform_now([ recipe.id ]) }
      .to raise_error(ActiveRecord::StatementInvalid, "boom")

    expect(recipe.reload.ingredient_names).to eq([ "old lemon" ])
    expect(recipe.ingredient_parse_data).to eq(original_parse_data)
    expect(recipe.ingredients_vector).to eq(original_vector)
    expect(recipe.recipe_ingredients).to be_empty
  end

  it "ignores deleted recipe ids while indexing" do
    recipe = create(:recipe)
    deleted_id = create(:recipe).id
    Recipe.where(id: deleted_id).delete_all
    allow(IngredientParser).to receive(:call).and_return([
      parser_result(recipe.ingredient_names, recipe.ingredients)
    ])
    allow(LocalEmbedding).to receive(:call).and_return(Array.new(384, 0.1))

    expect { IndexRecipeJob.perform_now([ recipe.id, deleted_id ]) }
      .not_to raise_error
  end

  it "upserts ingredients from the manual alias catalog" do
    avocado = create(:ingredient, name: "avocado", aliases: [ "old avocado" ])
    retained = create(:ingredient, name: "turmeric", aliases: [ "turmeric" ])

    with_alias_catalog(<<~YAML) do |path|
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

      upsert_statements = recorded_sql do
        BootstrapIngredientsJob.perform_now(path)
      end.grep(/\AINSERT INTO "ingredients"/)

      expect(avocado.reload.aliases).to eq([ "avocado", "avocados", "ripe avocado" ])
      expect(Ingredient.find_by!(name: "salt")).to be_optional
      expect(Ingredient.find_by(id: retained.id)).to be_present
      expect(upsert_statements.size).to eq(1)
    end
  end

  it "uses normalized names, aliases, and boolean optional values in the real alias catalog" do
    ingredients = YAML.safe_load_file(BootstrapIngredientsJob::CATALOG_PATH)["ingredients"]
    optional_values = ingredients.values.map { |attributes| attributes["optional"] || false }.uniq
    invalid_names = ingredients.keys.reject { |name| name == Ingredient.normalize_lookup_key(name) }
    invalid_aliases = ingredients.values.flat_map { |attributes| attributes["aliases"] }.reject { |name| name == Ingredient.normalize_lookup_key(name) }

    expect(invalid_names).to be_empty
    expect(invalid_aliases).to be_empty
    expect(optional_values).to match_array([ true, false ])
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
    yield path
  ensure
    path.delete if path&.exist?
  end

  def with_memory_cache
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)
    yield cache
  end

  def recorded_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _started, _finished, _id, payload|
      statements << payload.fetch(:sql) unless payload[:cached] || payload[:name] == "SCHEMA"
    end

    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end

require "rails_helper"

RSpec.describe RecipeSearch do
  around do |example|
    original_candidate_count = SETTINGS.ingredients_candidate_count
    original_max_distance = SETTINGS.ingredients_max_cosine_distance
    example.run
  ensure
    SETTINGS.ingredients_candidate_count = original_candidate_count
    SETTINGS.ingredients_max_cosine_distance = original_max_distance
  end

  it "returns the relation unchanged when ingredients are blank" do
    recipe = create(:recipe)

    result = described_class.call(relation: Recipe.all, ingredients: "")

    expect(result).to eq([ recipe ])
  end

  it "narrows the relation to ingredient vector candidates" do
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "pasta")
    tomato_pasta = create(:recipe, title: "Fast Tomato Pasta", ingredient_names: [ "tomatoes", "pasta" ], ingredients_vector: vector(1.0))
    tomato_soup = create(:recipe, title: "Best Tomato Soup", ingredient_names: [ "tomatoes" ], ingredients_vector: vector(0.8, 0.6))
    chicken = create(:recipe, title: "Chicken Dinner", ratings: 5.0, prep_time: 10, cook_time: 15, ingredient_names: [ "chicken" ], ingredients_vector: vector(-1.0))
    set_candidate_count(2)
    allow(IngredientParser).to receive(:call).and_return([
      IngredientParser::Result.new([ "tomatoes", "pasta" ], [])
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: "tomatoes, pasta"
    )

    expect(result).to contain_exactly(tomato_pasta, tomato_soup)
    expect(result).not_to include(chicken)
  end

  it "embeds canonical ingredient names resolved from basket aliases" do
    create(:ingredient, name: "avocado", aliases: [ "ripe avocado", "green avocado" ])
    create(:ingredient, name: "salt", optional: true)
    avocado_recipe = create(:recipe, title: "Avocado Salad", ingredient_names: [ "green avocado" ], ingredients_vector: vector(1.0))
    create(:recipe, title: "Apple Cake", ingredient_names: [ "apple" ], ingredients_vector: vector(-1.0))
    set_candidate_count(1)
    allow(IngredientParser).to receive(:call).and_return([
      IngredientParser::Result.new([ "green avocado", "salt" ], [])
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: "green avocado, salt"
    )

    expect(LocalEmbedding).to have_received(:call).with("avocado")
    expect(result).to eq([ avocado_recipe ])
  end

  it "uses only vector distance for ingredient candidates" do
    create(:ingredient, name: "avocado")
    create(:recipe, title: "Avocado Smoothie", ingredient_names: [ "green avocado", "banana" ], ingredients_vector: vector(0.8, 0.6))
    banana_recipe = create(:recipe, title: "Banana Ice Cream", ingredient_names: [ "banana" ], ingredients_vector: vector(1.0))
    set_candidate_count(2)
    allow(IngredientParser).to receive(:call).and_return([
      IngredientParser::Result.new([ "avocado" ], [])
    ])
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: "avocado"
    )

    expect(result).to include(banana_recipe)
  end

  it "does not filter when the basket only has optional ingredients" do
    create(:ingredient, name: "salt", optional: true)
    recipe = create(:recipe, title: "Any Dinner", ingredients_vector: vector(1.0))
    allow(IngredientParser).to receive(:call).and_return([
      IngredientParser::Result.new([ "salt" ], [])
    ])
    allow(LocalEmbedding).to receive(:call)

    result = described_class.call(
      relation: Recipe.all,
      ingredients: "salt"
    )

    expect(LocalEmbedding).not_to have_received(:call)
    expect(result).to eq([ recipe ])
  end

  it "ranks ingredient matches with the real local embedding model" do
    skip "Set RUN_EMBEDDING_SPECS=1 to run real Informers embedding specs." unless ENV["RUN_EMBEDDING_SPECS"] == "1"

    pasta = create(:recipe, title: "Tomato Basil Pasta", ratings: 4.0, ingredients: [
      "tomatoes",
      "fresh basil",
      "spaghetti",
      "garlic"
    ])
    apple_cake = create(:recipe, title: "Apple Cinnamon Cake", ratings: 5.0, ingredients: [
      "apples",
      "cinnamon",
      "flour",
      "sugar"
    ])

    [ pasta, apple_cake ].each do |recipe|
      names = recipe.ingredient_names.presence || recipe.ingredients
      recipe.update!(ingredients_vector: LocalEmbedding.call(names.join("\n")))
    end
    set_candidate_count(1)

    result = described_class.call(relation: Recipe.all, ingredients: "tomatoes basil spaghetti garlic")

    expect(result).to eq([ pasta ])
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end

  def set_candidate_count(value)
    SETTINGS.ingredients_candidate_count = value
  end
end

require "rails_helper"

RSpec.describe RecipeIngredientFilterQuery do
  around do |example|
    original_max_distance = SETTINGS.ingredients_max_cosine_distance
    example.run
  ensure
    SETTINGS.ingredients_max_cosine_distance = original_max_distance
  end

  before do
    allow(Rails.cache).to receive(:read).and_call_original
  end

  it "returns the relation unchanged when ingredients are blank" do
    recipe = create(:recipe)

    result = described_class.call(relation: Recipe.all, ingredients: "")

    expect(result).to eq([ recipe ])
  end

  it "keeps all exact ingredient overlap candidates without applying match ordering" do
    create(:ingredient, name: "avocado", aliases: [ "avocado", "avocados", "ripe avocado" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    simple_avocado = create(:recipe, title: "Simple Avocado", ratings: 4.0, ingredient_names: [ "avocados" ])
    avocado_rice_bowl = create(:recipe, title: "Avocado Rice Bowl", ratings: 5.0, ingredient_names: [ "avocados", "lime", "rice" ])
    lime_water = create(:recipe, title: "Lime Water", ratings: 3.0, ingredient_names: [ "lime" ])
    create(:recipe, title: "Apple Cake", ratings: 5.0, ingredient_names: [ "apple" ])
    create_recipe_ingredient_rows
    allow(IngredientParser).to receive(:call)

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "avocado", "lime" ]
    ).order(ratings: :desc)

    expect(result).to eq([ avocado_rice_bowl, simple_avocado, lime_water ])
    expect(IngredientParser).not_to have_received(:call)
  end

  it "narrows the relation to all ingredient vector candidates within threshold" do
    use_strategy("vector")
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "pasta")
    tomato_pasta = create(:recipe, title: "Fast Tomato Pasta", ingredient_names: [ "tomatoes", "pasta" ], ingredients_vector: vector(1.0))
    tomato_soup = create(:recipe, title: "Best Tomato Soup", ingredient_names: [ "tomatoes" ], ingredients_vector: vector(0.8, 0.6))
    chicken = create(:recipe, title: "Chicken Dinner", ratings: 5.0, prep_time: 10, cook_time: 15, ingredient_names: [ "chicken" ], ingredients_vector: vector(-1.0))
    allow(IngredientParser).to receive(:call)
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "tomato", "pasta" ]
    )

    expect(result).to contain_exactly(tomato_pasta, tomato_soup)
    expect(result).not_to include(chicken)
    expect(IngredientParser).not_to have_received(:call)
  end

  it "embeds submitted canonical ingredient names without parsing basket text" do
    use_strategy("vector")
    create(:ingredient, name: "avocado", aliases: [ "ripe avocado", "green avocado" ])
    create(:ingredient, name: "salt", optional: true)
    avocado_recipe = create(:recipe, title: "Avocado Salad", ingredient_names: [ "green avocado" ], ingredients_vector: vector(1.0))
    create(:recipe, title: "Apple Cake", ingredient_names: [ "apple" ], ingredients_vector: vector(-1.0))
    allow(IngredientParser).to receive(:call)
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "avocado", "salt" ]
    )

    expect(LocalEmbedding).to have_received(:call).with("avocado")
    expect(IngredientParser).not_to have_received(:call)
    expect(result).to eq([ avocado_recipe ])
  end

  it "uses only vector distance for ingredient candidates" do
    use_strategy("vector")
    create(:ingredient, name: "avocado")
    create(:recipe, title: "Avocado Smoothie", ingredient_names: [ "green avocado", "banana" ], ingredients_vector: vector(0.8, 0.6))
    banana_recipe = create(:recipe, title: "Banana Ice Cream", ingredient_names: [ "banana" ], ingredients_vector: vector(1.0))
    allow(LocalEmbedding).to receive(:call).and_return(vector(1.0))

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "avocado" ]
    )

    expect(result).to include(banana_recipe)
  end

  it "does not filter when the basket only has optional ingredients" do
    create(:ingredient, name: "salt", optional: true)
    recipe = create(:recipe, title: "Any Dinner", ingredients_vector: vector(1.0))
    allow(IngredientParser).to receive(:call)
    allow(LocalEmbedding).to receive(:call)

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "salt" ]
    )

    expect(LocalEmbedding).not_to have_received(:call)
    expect(IngredientParser).not_to have_received(:call)
    expect(result).to eq([ recipe ])
  end

  it "uses ingredient overlap when the cached strategy is not vector" do
    use_strategy("naive_vector_search")
    create(:ingredient, name: "avocado")
    avocado_recipe = create(:recipe, title: "Avocado Toast", ingredient_names: [ "avocado" ], ingredients_vector: vector(-1.0))
    create(:recipe, title: "Banana Ice Cream", ingredient_names: [ "banana" ], ingredients_vector: vector(1.0))
    create_recipe_ingredient_rows
    allow(IngredientParser).to receive(:call)
    allow(LocalEmbedding).to receive(:call)

    result = described_class.call(
      relation: Recipe.all,
      ingredients: [ "avocado" ]
    )

    expect(LocalEmbedding).not_to have_received(:call)
    expect(IngredientParser).not_to have_received(:call)
    expect(result).to eq([ avocado_recipe ])
  end

  it "ranks ingredient matches with the real local embedding model" do
    use_strategy("vector")
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

    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "basil")
    create(:ingredient, name: "spaghetti")
    create(:ingredient, name: "garlic")

    result = described_class.call(relation: Recipe.all, ingredients: [ "tomato", "basil", "spaghetti", "garlic" ])

    expect(result).to eq([ pasta ])
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end

  def use_strategy(value)
    allow(Rails.cache).to receive(:read).with("search_strategy").and_return(value)
  end

  def create_recipe_ingredient_rows
    Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: Recipe.ids), RecipeIngredientRecomputeQuery.name)
  end
end

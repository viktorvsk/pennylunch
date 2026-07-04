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

  it "returns one page and infers the next page without a total count" do
    create_list(:recipe, described_class::PER_PAGE + 1)

    result = described_class.new(params: {}).call

    expect(result.recipes.size).to eq(described_class::PER_PAGE)
    expect(result.next_page).to eq(2)
    expect(result).not_to respond_to(:total_count)
    expect(result).not_to respond_to(:category_options)
  end

  it "filters recipes by the public search controls" do
    quick_popular = create(:recipe, title: "Quick Tomato Pasta", prep_time: 8, cook_time: 15, ratings: 4.91, category: "Pasta")
    create(:recipe, title: "Slow Roast Chicken", prep_time: 20, cook_time: 120, ratings: 4.5, category: "Dinner")
    other = create(:recipe, title: "Blueberry Muffins", prep_time: 10, cook_time: 18, ratings: 4.85, category: "Breakfast")

    expect(described_class.new(params: { q: "tomato" }).call.recipes).to contain_exactly(quick_popular)
    expect(described_class.new(params: { category: "pasta" }).call.recipes).to contain_exactly(quick_popular)
    expect(described_class.new(params: { quick: "1" }).call.recipes).to contain_exactly(quick_popular, other)
    expect(described_class.new(params: { popular: "1" }).call.recipes).to contain_exactly(quick_popular, other)
  end

  it "sorts recipes by public sort options" do
    quick_popular = create(:recipe, title: "Quick Tomato Pasta", prep_time: 8, cook_time: 15, ratings: 4.91)
    slow = create(:recipe, title: "Slow Roast Chicken", prep_time: 20, cook_time: 120, ratings: 4.5)
    other = create(:recipe, title: "Blueberry Muffins", prep_time: 10, cook_time: 18, ratings: 4.85)
    unknown_time = create(:recipe, title: "Mystery Bread", prep_time: 0, cook_time: 0, ratings: 4.7)

    expect(described_class.new(params: { sort: "time_asc" }).call.recipes).to eq([ quick_popular, other, slow, unknown_time ])
    expect(described_class.new(params: { sort: "time_desc" }).call.recipes).to eq([ unknown_time, slow, other, quick_popular ])
    expect(described_class.new(params: { sort: "rating_asc" }).call.recipes).to eq([ slow, unknown_time, other, quick_popular ])
  end

  it "sorts the ingredient candidate set with the selected sort" do
    create(:ingredient, name: "tomato", aliases: [ "tomatoes" ])
    create(:ingredient, name: "pasta")
    tomato_fast = create(:recipe, title: "Fast Tomato Pasta", ratings: 4.4, prep_time: 5, cook_time: 10, ingredient_names: [ "tomatoes", "pasta" ], ingredients_vector: vector(1.0))
    tomato_best = create(:recipe, title: "Best Tomato Soup", ratings: 4.9, prep_time: 20, cook_time: 30, ingredient_names: [ "tomatoes" ], ingredients_vector: vector(0.8, 0.6))
    chicken = create(:recipe, title: "Chicken Dinner", ratings: 5.0, prep_time: 10, cook_time: 15, ingredient_names: [ "chicken" ], ingredients_vector: vector(-1.0))
    set_candidate_count(2)

    result = described_class.new(
      params: { ingredients: "tomatoes, pasta", sort: "rating_desc" },
      embedder: fake_embedder(vector(1.0)),
      ingredient_parser: fake_ingredient_parser([ IngredientParser::Result.new([ "tomatoes", "pasta" ], []) ]),
    ).call

    expect(result.recipes).to eq([ tomato_best, tomato_fast ])
    expect(result.recipes).not_to include(chicken)
  end

  it "embeds canonical ingredient names resolved from basket aliases" do
    create(:ingredient, name: "avocado", aliases: [ "ripe avocado", "green avocado" ])
    create(:ingredient, name: "salt", optional: true)
    avocado_recipe = create(:recipe, title: "Avocado Salad", ingredient_names: [ "green avocado" ], ingredients_vector: vector(1.0))
    create(:recipe, title: "Apple Cake", ingredient_names: [ "apple" ], ingredients_vector: vector(-1.0))
    embedder = fake_embedder(vector(1.0))
    set_candidate_count(1)

    result = described_class.new(
      params: { ingredients: "green avocado, salt" },
      embedder:,
      ingredient_parser: fake_ingredient_parser([ IngredientParser::Result.new([ "green avocado", "salt" ], []) ]),
    ).call

    expect(embedder.calls).to eq([ "avocado" ])
    expect(result.recipes).to eq([ avocado_recipe ])
  end

  it "uses only vector distance for ingredient candidates" do
    create(:ingredient, name: "avocado")
    create(:recipe, title: "Avocado Smoothie", ingredient_names: [ "green avocado", "banana" ], ingredients_vector: vector(0.8, 0.6))
    banana_recipe = create(:recipe, title: "Banana Ice Cream", ingredient_names: [ "banana" ], ingredients_vector: vector(1.0))
    set_candidate_count(2)

    result = described_class.new(
      params: { ingredients: "avocado" },
      embedder: fake_embedder(vector(1.0)),
      ingredient_parser: fake_ingredient_parser([ IngredientParser::Result.new([ "avocado" ], []) ]),
    ).call

    expect(result.recipes).to include(banana_recipe)
  end

  it "does not filter when the basket only has optional ingredients" do
    create(:ingredient, name: "salt", optional: true)
    recipe = create(:recipe, title: "Any Dinner", ingredients_vector: vector(1.0))
    embedder = fake_embedder(vector(1.0))

    result = described_class.new(
      params: { ingredients: "salt" },
      embedder:,
      ingredient_parser: fake_ingredient_parser([ IngredientParser::Result.new([ "salt" ], []) ]),
    ).call

    expect(embedder.calls).to be_empty
    expect(result.recipes).to eq([ recipe ])
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

    result = described_class.new(
      params: { ingredients: "tomatoes basil spaghetti garlic", sort: "rating_desc" },
    ).call

    expect(result.recipes).to eq([ pasta ])
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end

  def set_candidate_count(value)
    SETTINGS.ingredients_candidate_count = value
  end

  def fake_embedder(value)
    Class.new do
      def self.calls
        @calls ||= []
      end

      define_singleton_method(:call) do |text|
        calls << text
        value
      end
    end
  end

  def fake_ingredient_parser(value)
    Class.new do
      define_singleton_method(:call) { |_ingredient_lists| value }
    end
  end
end

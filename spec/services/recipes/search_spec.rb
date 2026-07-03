require "rails_helper"

RSpec.describe Recipes::Search do
  it "keeps ingredient relevance ahead of the selected sort" do
    tomato_fast = create(:recipe, title: "Fast Tomato Pasta", ratings: 4.4, prep_time: 5, cook_time: 10, ingredients_vector: vector(1.0))
    tomato_best = create(:recipe, title: "Best Tomato Soup", ratings: 4.9, prep_time: 20, cook_time: 30, ingredients_vector: vector(0.8, 0.6))
    chicken = create(:recipe, title: "Chicken Dinner", ratings: 5.0, prep_time: 10, cook_time: 15, ingredients_vector: vector(-1.0))

    result = described_class.new(
      params: { ingredients: "tomatoes, pasta", sort: "rating_desc" },
      embedder: fake_embedder(vector(1.0)),
      ingredient_parser: fake_ingredient_parser([ IngredientParser::Result.new([ "tomatoes", "pasta" ], []) ]),
      ingredients_candidate_count: 2,
    ).call

    expect(result.recipes).to eq([ tomato_fast, tomato_best ])
    expect(result.recipes).not_to include(chicken)
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
      recipe.update!(ingredients_vector: LocalEmbedding.call(recipe.ingredients_embedding_text))
    end

    result = described_class.new(
      params: { ingredients: "tomatoes basil spaghetti garlic", sort: "rating_desc" },
      ingredients_candidate_count: 1,
    ).call

    expect(result.recipes).to eq([ pasta ])
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end

  def fake_embedder(value)
    Class.new do
      define_singleton_method(:call) { |_text| value }
    end
  end

  def fake_ingredient_parser(value)
    Class.new do
      define_singleton_method(:call) { |_ingredient_lists| value }
    end
  end
end

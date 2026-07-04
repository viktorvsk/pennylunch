require "rails_helper"

RSpec.describe Recipes::SimilarRecipesQuery do
  it "returns nearest ingredient-vector neighbors without requiring the same category" do
    recipe = create(:recipe, title: "Tomato Pasta", category: "Pasta", ingredients_vector: vector(1.0, 0.0))
    closest = create(:recipe, title: "Tomato Soup", category: "Soup", ingredients_vector: vector(0.98, 0.02))
    next_closest = create(:recipe, title: "Garlic Tomatoes", category: "Salad", ingredients_vector: vector(0.9, 0.1))
    create(:recipe, title: "Same Category Without Vector", category: "Pasta", ingredients_vector: nil)
    create(:recipe, title: "Apple Cake", category: "Pasta", ingredients_vector: vector(-1.0, 0.0))

    result = described_class.new(recipe:, limit: 2).call

    expect(result).to eq([ closest, next_closest ])
  end

  it "returns none when the recipe has no ingredient vector" do
    recipe = create(:recipe, ingredients_vector: nil)
    create(:recipe, ingredients_vector: vector(1.0, 0.0))

    expect(described_class.new(recipe:).call).to be_empty
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end
end

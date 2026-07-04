require "rails_helper"

RSpec.describe RecipeIngredient, type: :model do
  it "belongs to a recipe and an ingredient" do
    recipe_ingredient = create(:recipe_ingredient)

    expect(recipe_ingredient.recipe).to be_present
    expect(recipe_ingredient.ingredient).to be_present
  end
end

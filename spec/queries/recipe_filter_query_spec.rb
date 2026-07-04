require "rails_helper"

RSpec.describe RecipeFilterQuery do
  it "applies title, category, quick, popular, and ingredient filters" do
    create(:ingredient, name: "tomato")
    match = create(:recipe, title: "Tomato Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Tomato Dessert", category: "Dessert", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Slow Tomato Dinner", category: "Dinner", prep_time: 20, cook_time: 20, ratings: 4.9, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Low Rated Tomato Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.0, ingredient_names: [ "tomato" ])
    create(:recipe, title: "Garlic Dinner", category: "Dinner", prep_time: 10, cook_time: 15, ratings: 4.9, ingredient_names: [ "garlic" ])
    create_recipe_ingredient_rows

    result = described_class.call(
      filters: {
        "q" => "tomato",
        "category" => "Dinner",
        "quick" => "1",
        "popular" => "1",
        "ingredients" => [ "tomato" ]
      }
    )

    expect(result).to eq([ match ])
  end

  def create_recipe_ingredient_rows
    Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: Recipe.ids), RecipeIngredientRecomputeQuery.name)
  end
end

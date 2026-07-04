require "rails_helper"

RSpec.describe "Avo destructive record actions" do
  it "deletes selected recipe records without deleting ingredients" do
    selected_recipe = create(:recipe)
    retained_recipe = create(:recipe)
    ingredient = create(:ingredient, name: "salt")

    action = run_action(Avo::Actions::DeleteSelectedRecipes, [ selected_recipe ])

    expect(Recipe.pluck(:id)).to eq([ retained_recipe.id ])
    expect(Ingredient.find_by(id: ingredient.id)).to be_present
    expect(action.response[:type]).to eq(:reload)
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Deleted 1 recipe."))
  end

  it "deletes all recipe records in an Avo select-all relation" do
    create(:recipe, category: "Dinner")
    retained_recipe = create(:recipe, category: "Dessert")

    run_action(Avo::Actions::DeleteSelectedRecipes, Recipe.where(category: "Dinner"))

    expect(Recipe.pluck(:id)).to eq([ retained_recipe.id ])
  end

  it "deletes selected ingredient records without deleting recipes" do
    selected_ingredient = create(:ingredient, name: "salt")
    retained_ingredient = create(:ingredient, name: "lemon")
    recipe = create(:recipe)

    action = run_action(Avo::Actions::DeleteSelectedIngredients, [ selected_ingredient ])

    expect(Ingredient.pluck(:id)).to eq([ retained_ingredient.id ])
    expect(Recipe.find_by(id: recipe.id)).to be_present
    expect(action.response[:type]).to eq(:reload)
    expect(action.response[:messages]).to include(hash_including(type: :success, body: "Deleted 1 ingredient."))
  end

  def run_action(action_class, query)
    action = action_class.new
    action.handle(query:, fields: {}, current_user: nil, resource: nil)
    action
  end
end

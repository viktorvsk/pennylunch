require "rails_helper"

RSpec.describe RecipeSortQuery do
  it "orders a relation by fewest missing required ingredients before fuller partials" do
    create(:ingredient, name: "avocado", aliases: [ "avocado", "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "rice")
    exact_match = create(:recipe, title: "Avocado Lime Salad", ratings: 4.0, ingredient_names: [ "avocados", "lime" ])
    fewer_missing_partial = create(:recipe, title: "Avocado Plate", ratings: 5.0, ingredient_names: [ "avocados" ])
    fuller_match_with_missing = create(:recipe, title: "Avocado Rice Bowl", ratings: 5.0, ingredient_names: [ "avocados", "lime", "rice" ])
    create_recipe_ingredient_rows

    result = described_class.call(relation: Recipe.all, sort: "best_match", ingredients: [ "avocado", "lime" ])

    expect(result).to eq([ exact_match, fewer_missing_partial, fuller_match_with_missing ])
  end

  it "ignores optional and unknown recipe ingredients for best match counts" do
    create(:ingredient, name: "avocado", aliases: [ "avocados" ])
    create(:ingredient, name: "lime")
    create(:ingredient, name: "salt", optional: true)
    missing_optional = create(:recipe, title: "Salted Avocado Lime Plate", ingredient_names: [ "avocados", "lime", "salt" ])
    missing_unknown = create(:recipe, title: "Seasoned Avocado Plate", ingredient_names: [ "avocados", "house seasoning", "secret sauce" ])
    complete = create(:recipe, title: "Avocado Plate", ingredient_names: [ "avocados" ])
    create_recipe_ingredient_rows

    result = described_class.call(relation: Recipe.all, sort: "best_match", ingredients: [ "avocado", "lime" ]).order(id: :asc)

    expect(result).to eq([ missing_optional, missing_unknown, complete ])
  end

  it "builds best-match SQL from recipe ingredient joins instead of raw recipe JSON or alias JSON" do
    create(:ingredient, name: "avocado")
    create(:recipe, title: "Avocado Toast", ingredient_names: [ "avocado" ])
    create_recipe_ingredient_rows

    relation = RecipeIngredientFilterQuery.call(relation: Recipe.all, ingredients: [ "avocado" ])
    sql = described_class.call(relation:, sort: "best_match", ingredients: [ "avocado" ]).to_sql

    expect(sql).not_to include("jsonb_array_elements_text")
    expect(sql).not_to include("aliases @>")
    expect(sql).to include("recipe_ingredients")
  end

  it "orders unknown recipe times last for explicit time sorting" do
    known = create(:recipe, title: "Known Time", prep_time: 5, cook_time: 10)
    unknown = create(:recipe, title: "Unknown Time", prep_time: 0, cook_time: 0)

    result = described_class.call(relation: Recipe.all, sort: "time_asc", ingredients: "")

    expect(result).to eq([ known, unknown ])
  end

  def create_recipe_ingredient_rows
    Recipe.connection.exec_query(RecipeIngredientRecomputeQuery.call(recipe_ids: Recipe.ids), RecipeIngredientRecomputeQuery.name)
  end
end

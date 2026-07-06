require "rails_helper"

RSpec.describe IndexRecipeJob, type: :job do
  it "indexes selected recipes with real parser output, vectors, and catalog joins" do
    create(:ingredient, name: "flour")
    create(:ingredient, name: "egg", aliases: [ "egg", "eggs" ])
    create(:ingredient, name: "salt", optional: true)
    create(:ingredient, name: "black pepper", aliases: [ "black pepper", "ground black pepper" ], optional: true)
    stale = create(:ingredient, name: "apple")
    recipe = create(
      :recipe,
      ingredients: [ "1 cup flour", "2 eggs", "salt and ground black pepper to taste" ],
      ingredient_names: [ "apple" ],
      ingredient_parse_data: [ { "input" => "old apple" } ],
      ingredients_vector: nil
    )
    create(:recipe_ingredient, recipe:, ingredient: stale)

    described_class.perform_now([ recipe.id ])

    recipe.reload
    expect(recipe.ingredient_names).to eq([ "flour", "eggs", "salt", "black pepper" ])
    expect(recipe.ingredient_parse_data.map { |entry| entry.fetch("input") }).to eq(recipe.ingredients)
    expect_real_vector(recipe.ingredients_vector)
    expect(recipe.resolved_ingredients.order(:name).pluck(:name)).to eq([ "black pepper", "egg", "flour", "salt" ])
  end

  it "indexes all recipes from their raw ingredient lines" do
    create(:ingredient, name: "pasta", aliases: [ "pasta", "spaghetti" ])
    create(:ingredient, name: "garlic")
    create(:ingredient, name: "avocado")
    create(:ingredient, name: "lime")
    pasta = create(:recipe, ingredients: [ "200g spaghetti", "3 cloves garlic, minced" ], ingredient_names: [], ingredient_parse_data: [], ingredients_vector: nil)
    avocado = create(:recipe, ingredients: [ "1 avocado", "1 lime" ], ingredient_names: [], ingredient_parse_data: [], ingredients_vector: nil)

    described_class.perform_now("all")

    expect(pasta.reload.ingredient_names).to eq([ "spaghetti", "garlic" ])
    expect(pasta.resolved_ingredients.order(:name).pluck(:name)).to eq([ "garlic", "pasta" ])
    expect_real_vector(pasta.ingredients_vector)
    expect(avocado.reload.ingredient_names).to eq([ "avocado", "lime" ])
    expect(avocado.resolved_ingredients.order(:name).pluck(:name)).to eq([ "avocado", "lime" ])
    expect_real_vector(avocado.ingredients_vector)
  end

  it "clears stale vectors and stale joins when no required catalog ingredient is matched" do
    stale = create(:ingredient, name: "apple")
    salt = create(:ingredient, name: "salt", optional: true)
    recipe = create(
      :recipe,
      ingredients: [ "salt to taste" ],
      ingredient_names: [ "apple" ],
      ingredient_parse_data: [ { "input" => "old apple" } ],
      ingredients_vector: LocalEmbedding.call("apple")
    )
    create(:recipe_ingredient, recipe:, ingredient: stale)

    described_class.perform_now([ recipe.id ])

    recipe.reload
    expect(recipe.ingredient_names).to eq([ "salt" ])
    expect(recipe.ingredients_vector).to be_nil
    expect(recipe.resolved_ingredients).to contain_exactly(salt)
  end

  def expect_real_vector(vector)
    expect(vector.size).to eq(384)
    expect(vector).to all(be_a(Float))
    expect(vector).to all(satisfy(&:finite?))
  end
end

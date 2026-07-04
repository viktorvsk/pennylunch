require "rails_helper"

RSpec.describe IngredientsHelper, type: :helper do
  describe "#recipe_ingredient_catalog_names" do
    it "maps raw recipe ingredient aliases to canonical names for UI matching" do
      create(:ingredient, name: "banana", aliases: [ "banana", "overripe bananas" ])
      create(:ingredient, name: "salt", aliases: [ "salt", "kosher salt" ], optional: true)
      recipe = build(:recipe, ingredient_names: [ "overripe bananas", "kosher salt", "unknown" ])

      expect(helper.recipe_ingredient_catalog_names(recipe)).to eq([ "banana", "salt", nil ])
    end
  end

  describe "#recipe_ingredient_rows" do
    it "includes a canonical match name for each parsed ingredient row" do
      create(:ingredient, name: "banana", aliases: [ "banana", "overripe bananas" ])
      recipe = build(
        :recipe,
        ingredients: [ "3 mashed overripe bananas" ],
        ingredient_names: [ "overripe bananas" ],
        ingredient_parse_data: [
          {
            "parser" => {
              "amount" => [ { "quantity" => "3" } ],
              "name" => [ { "text" => "overripe bananas" } ],
              "preparation" => "mashed"
            }
          }
        ]
      )

      expect(helper.recipe_ingredient_rows(recipe).first).to include(
        name: "overripe bananas",
        catalog_name: "banana",
        catalog_names: [ "banana" ],
        optional: false
      )
    end

    it "includes every canonical match name from multi-name parser rows" do
      create(:ingredient, name: "bread", aliases: [ "ciabatta bread" ])
      create(:ingredient, name: "crusty sourdough")
      recipe = build(
        :recipe,
        ingredients: [ "1 loaf crusty sourdough or ciabatta bread, sliced" ],
        ingredient_names: [ "crusty sourdough", "ciabatta bread" ],
        ingredient_parse_data: [
          {
            "parser" => {
              "amount" => [ { "quantity" => "1", "unit" => "loaf" } ],
              "name" => [ { "text" => "crusty sourdough" }, { "text" => "ciabatta bread" } ],
              "preparation" => "sliced"
            }
          }
        ]
      )

      expect(helper.recipe_ingredient_rows(recipe).first).to include(
        name: "crusty sourdough",
        catalog_name: "crusty sourdough",
        catalog_names: [ "crusty sourdough", "bread" ],
        optional: false
      )
    end
  end

  describe "#recipe_ingredient_groups" do
    it "places non-optional and unknown rows before optional rows" do
      create(:ingredient, name: "salt", optional: true)
      create(:ingredient, name: "tomato")
      recipe = build(
        :recipe,
        ingredients: [ "1 tomato", "salt to taste", "house seasoning" ],
        ingredient_names: [ "tomato", "salt", "house seasoning" ],
        ingredient_parse_data: [
          { "parser" => { "name" => [ { "text" => "tomato" } ] } },
          { "parser" => { "name" => [ { "text" => "salt" } ] } },
          { "parser" => { "name" => [ { "text" => "house seasoning" } ] } }
        ]
      )

      main, pantry = helper.recipe_ingredient_groups(recipe)

      expect(main.map { |row| row[:name] }).to eq([ "tomato", "house seasoning" ])
      expect(pantry.map { |row| row[:name] }).to eq([ "salt" ])
    end
  end
end

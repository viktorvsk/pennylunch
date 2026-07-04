require "rails_helper"
RSpec.describe IngredientsHelper, type: :helper do
  describe "#recipe_match_readiness" do
    it "reports the selected share of required ingredients" do
      readiness = helper.recipe_match_readiness([ "avocado", "lime", "rice" ], [ "avocado", "lime" ])
      expect(readiness.percentage).to eq(67)
      expect(readiness.label).to eq("67%")
      expect(readiness.tooltip).to eq("Matches 2 of 3 required ingredients in your selected ingredients. Pantry staples are not counted.")
      expect(readiness.ready).to be(false)
    end

    it "reports 100 percent when every required ingredient is selected" do
      readiness = helper.recipe_match_readiness([ "avocado", "lime" ], [ "lime", "avocado" ])

      expect(readiness.label).to eq("100%")
      expect(readiness.ready).to be(true)
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

      expect(main.map(&:name)).to eq([ "tomato", "house seasoning" ])
      expect(pantry.map(&:name)).to eq([ "salt" ])
    end
  end
end

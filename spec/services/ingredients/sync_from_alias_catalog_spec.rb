require "rails_helper"

RSpec.describe Ingredients::SyncFromAliasCatalog do
  it "creates ingredients from the manual catalog" do
    catalog = [
      Ingredients::ManualAliasCatalog::Entry.new("avocado", [ "avocado", "avocados", "ripe avocado" ], false),
      Ingredients::ManualAliasCatalog::Entry.new("salt", [ "salt", "kosher salt" ], true)
    ]

    result = described_class.call(catalog:, raw_names: [ "ripe avocado", "kosher salt" ])

    expect(result.ingredient_count).to eq(2)
    expect(result.alias_count).to eq(5)
    expect(Ingredient.find_by!(name: "avocado").aliases).to eq([ "avocado", "avocados", "ripe avocado" ])
    expect(Ingredient.find_by!(name: "salt")).to be_optional
  end

  it "uses parser names as the raw coverage source when recipes are already canonicalized" do
    catalog = [
      Ingredients::ManualAliasCatalog::Entry.new("cereal mix", [ "wheat, rye, and flax hot cereal mix" ], false)
    ]
    create(:recipe, ingredients: [ "1 cup wheat, rye, and flax hot cereal mix" ], ingredient_names: [ "cereal mix" ], ingredient_parse_data: [
      {
        "input" => "1 cup wheat, rye, and flax hot cereal mix",
        "parser" => {
          "name" => [
            { "text" => "wheat, rye, and flax hot cereal mix" }
          ]
        }
      }
    ])

    described_class.call(catalog:)

    expect(Ingredient.find_by!(name: "cereal mix").aliases).to include("wheat, rye, and flax hot cereal mix")
  end

  it "does not write ingredients when the catalog misses raw recipe names" do
    existing = create(:ingredient, name: "salt", aliases: [ "salt" ])
    catalog = [
      Ingredients::ManualAliasCatalog::Entry.new("avocado", [ "avocado", "avocados" ], false)
    ]

    expect { described_class.call(catalog:, raw_names: [ "avocado", "green avocado" ]) }
      .to raise_error(Ingredients::SyncFromAliasCatalog::UnmappedIngredientNamesError, /green avocado/)
    expect(Ingredient.pluck(:id)).to eq([ existing.id ])
  end

  it "can reload directly from the catalog without recipe coverage checks" do
    create(:ingredient, name: "old ingredient", aliases: [ "old ingredient" ])
    catalog = [
      Ingredients::ManualAliasCatalog::Entry.new("avocado", [ "avocado", "avocados" ], false)
    ]

    described_class.call(catalog:, raw_names: [ "green avocado" ], recipe_coverage: :skip)

    expect(Ingredient.pluck(:name)).to eq([ "avocado" ])
  end
end

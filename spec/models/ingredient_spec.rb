require "rails_helper"

RSpec.describe Ingredient do
  it "requires a unique normalized name and stores aliases as a JSON array" do
    ingredient = described_class.create!(name: " Tomatoes ", aliases: [ "roma tomatoes", "", "roma tomatoes", " grape tomatoes " ])

    expect(ingredient.name).to eq("tomatoes")
    expect(ingredient.aliases).to eq([ "roma tomatoes", "grape tomatoes" ])
    expect(described_class.new(name: "tomatoes")).not_to be_valid
  end

  it "rejects non-array aliases" do
    ingredient = described_class.new(name: "tomato", aliases: "roma tomato")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:aliases]).to include("must be an array")
  end

  it "rejects empty aliases" do
    ingredient = described_class.new(name: "tomato")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:aliases]).to include("must have at least one alias")
  end

  it "rejects aliases already used by another ingredient" do
    create(:ingredient, name: "avocado", aliases: [ "avocado", "ripe avocado" ])

    ingredient = described_class.new(name: "pear", aliases: [ "ripe avocado" ])

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:aliases]).to include("must be unique across ingredients")
  end

  it "rejects aliases matching another ingredient name" do
    create(:ingredient, name: "avocado")

    ingredient = described_class.new(name: "pear", aliases: [ "avocado" ])

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:aliases]).to include("must not match another ingredient name")
  end

  it "rejects comma-separated canonical names" do
    ingredient = described_class.new(name: "wheat, rye, and flax hot cereal mix")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:name]).to include("must not contain commas")
  end

  it "filters matches from text excluding optional ingredients" do
    create(:ingredient, name: "salt", aliases: [ "salt", "kosher salt" ], optional: true)
    avocado = create(:ingredient, name: "avocado")

    expect(described_class.filterable_matches([ "salt", "avocado" ])).to eq([ avocado ])
  end

  it "filters only exact canonical ingredient names" do
    avocado = create(:ingredient, name: "avocado", aliases: [ "ripe avocado" ])

    expect(described_class.filterable_matches([ " Avocado ", "avocado", "ripe avocado" ])).to eq([ avocado ])
  end

  it "returns filterable matches in filter-text order" do
    create(:ingredient, name: "pasta")
    create(:ingredient, name: "garlic")

    expect(described_class.filterable_matches([ "garlic", "pasta" ]).map(&:name)).to eq([ "garlic", "pasta" ])
  end
end

require "rails_helper"

RSpec.describe Ingredient do
  it "requires a unique normalized name and stores aliases as a JSON array" do
    ingredient = described_class.create!(name: " Tomatoes ", aliases: [ "roma tomatoes", "", "roma tomatoes", " grape tomatoes " ])

    expect(ingredient.name).to eq("tomato")
    expect(ingredient.aliases).to eq([ "roma tomatoes", "grape tomatoes" ])
    expect(described_class.new(name: "tomato")).not_to be_valid
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

    ingredient = described_class.new(name: "pear", aliases: [ "avocados" ])

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:aliases]).to include("must not match another ingredient name")
  end

  it "rejects comma-separated canonical names" do
    ingredient = described_class.new(name: "wheat, rye, and flax hot cereal mix")

    expect(ingredient).not_to be_valid
    expect(ingredient.errors[:name]).to include("must not contain commas")
  end

  it "maps aliases and names to canonical ingredient names" do
    create(:ingredient, name: "avocado", aliases: [ "avocado", "ripe avocado", "green avocado" ])
    create(:ingredient, name: "tomato", aliases: [ "tomato", "tomatoes" ])

    expect(described_class.canonical_names_for([ "green avocados", "tomatoes", "unknown" ])).to eq([ "avocado", "tomato" ])
  end

  it "normalizes common ingredient plurals without damaging uncountable names" do
    expect(described_class.normalize_lookup_key("pasta")).to eq("pasta")
    expect(described_class.normalize_lookup_key("cookies")).to eq("cookie")
    expect(described_class.normalize_lookup_key("strawberries")).to eq("strawberry")
    expect(described_class.normalize_lookup_key("tomatoes")).to eq("tomato")
    expect(described_class.normalize_lookup_key("zucchinis")).to eq("zucchini")
    expect(described_class.normalize_lookup_key("s green onions")).to eq("green onion")
  end

  it "keeps optional ingredients out of filterable canonical names" do
    create(:ingredient, name: "salt", aliases: [ "salt", "kosher salt" ], optional: true)
    create(:ingredient, name: "avocado")

    expect(described_class.filterable_canonical_names_for([ "kosher salt", "avocado" ])).to eq([ "avocado" ])
  end

  it "exposes ingredient filter options with optional metadata" do
    create(:ingredient, name: "salt", optional: true)
    create(:ingredient, name: "avocado")

    expect(described_class.filter_options).to eq([
      { name: "avocado", optional: false },
      { name: "salt", optional: true }
    ])
  end
end

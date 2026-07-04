require "rails_helper"

RSpec.describe Recipes::CategoryCatalogQuery do
  describe ".from_slug" do
    it "resolves normalized categories from parameterized slugs" do
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")

      expect(Recipe.category_slug_for("air fryer main dish recipes")).to eq("air-fryer-main-dish-recipes")
      expect(described_class.from_slug("air-fryer-main-dish-recipes")).to eq("air fryer main dish recipes")
    end
  end

  describe "#options" do
    it "returns unique lowercase categories without blanks" do
      create(:recipe, category: "Dinner", category_normalized: "dinner")
      create(:recipe, category: "dinner", category_normalized: "dinner")
      create(:recipe, category: "", category_normalized: "")

      expect(described_class.options).to eq([ "dinner" ])
    end
  end

  describe "#labels" do
    it "maps normalized categories to original display names" do
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")
      create(:recipe, category: "air fryer main dish recipes", category_normalized: "air fryer main dish recipes")

      expect(described_class.labels).to eq(
        "air fryer main dish recipes" => "Air Fryer Main Dish Recipes"
      )
    end
  end
end

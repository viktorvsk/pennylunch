require "rails_helper"

RSpec.describe Catalog do
  describe ".fetch" do
    it "builds sorted ingredient options and category mappings through the cache" do
      create(:ingredient, name: "zucchini")
      create(:ingredient, name: "avocado", optional: true)
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")
      allow(Rails.cache).to receive(:fetch).and_call_original

      catalog = described_class.fetch

      expect(catalog).to have_attributes(
        ingredient_options: [
          { name: "avocado", optional: true },
          { name: "zucchini", optional: false }
        ],
        category_labels: { "air fryer main dish recipes" => "Air Fryer Main Dish Recipes" },
        category_slugs: { "air fryer main dish recipes" => "air-fryer-main-dish-recipes" }
      )
      expect(Rails.cache).to have_received(:fetch).with(described_class.cache_key)
    end

    it "does not serve a stale empty ingredient catalog after ingredients are created" do
      cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(cache)

      expect(described_class.fetch.ingredient_options).to eq([])

      create(:ingredient, name: "avocado")

      expect(described_class.fetch.ingredient_options).to eq([
        { name: "avocado", optional: false }
      ])
    end
  end

  describe ".cache_key" do
    it "tracks ingredient and recipe collection versions" do
      expect(described_class.cache_key).to eq([
        "recipes/catalog/v1",
        Ingredient.all.cache_key_with_version,
        Recipe.all.cache_key_with_version
      ])
    end
  end

  describe "#category_from_slug" do
    it "returns the normalized category for a category slug" do
      catalog = described_class.new(
        ingredient_options: [],
        category_labels: { "air fryer main dish recipes" => "Air Fryer Main Dish Recipes" },
        category_slugs: { "air fryer main dish recipes" => "air-fryer-main-dish-recipes" }
      )

      expect(catalog.category_from_slug("air-fryer-main-dish-recipes")).to eq("air fryer main dish recipes")
    end
  end

  describe "#as_json" do
    it "emits the browser catalog payload with camelCase keys" do
      catalog = described_class.new(
        ingredient_options: [ { name: "tomato", optional: true } ],
        category_labels: { "pasta" => "Pasta" },
        category_slugs: { "pasta" => "pasta" }
      )

      expect(catalog.as_json).to eq(
        ingredientOptions: [ { name: "tomato", optional: true } ],
        categoryLabels: { "pasta" => "Pasta" },
        categorySlugs: { "pasta" => "pasta" }
      )
    end
  end
end

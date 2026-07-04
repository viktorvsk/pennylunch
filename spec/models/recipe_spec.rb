require "rails_helper"

RSpec.describe Recipe do
  describe "#to_param" do
    it "derives the friendly slug from recipe attributes and appends the id" do
      recipe = build_stubbed(
        :recipe,
        id: 42,
        title: "Tomato Pasta",
        category: "",
        author: "Pasta Maker",
        prep_time: 8,
        cook_time: 15,
        total_time: 23
      )
      recipe.slug = nil if recipe.respond_to?(:slug=)

      expect(recipe.to_param).to eq("Tomato-Pasta-Pasta-Maker-23-minutes-42")
    end
  end

  describe "schema" do
    it "does not persist friendly URL slugs" do
      expect(described_class.column_names).not_to include("slug")
    end

    it "does not persist source identity keys" do
      expect(described_class.column_names).not_to include("source_key")
    end
  end

  describe ".category_labels" do
    it "maps normalized categories to original display names" do
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")
      create(:recipe, category: "air fryer main dish recipes", category_normalized: "air fryer main dish recipes")
      create(:recipe, category: "Dinner", category_normalized: "dinner")
      create(:recipe, category: "dinner", category_normalized: "dinner")
      create(:recipe, category: "", category_normalized: "")

      expect(described_class.category_labels).to eq(
        "air fryer main dish recipes" => "Air Fryer Main Dish Recipes",
        "dinner" => "Dinner"
      )
    end
  end

  describe "#display_image_url" do
    it "extracts direct Allrecipes image URLs from Meredith proxy URLs" do
      recipe = described_class.new(image: "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F8263243.jpg")

      expect(recipe.display_image_url).to eq("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    end

    it "keeps non-proxy image URLs unchanged" do
      recipe = described_class.new(image: "https://example.com/recipe.jpg")

      expect(recipe.display_image_url).to eq("https://example.com/recipe.jpg")
    end
  end

  describe "#catalog_ingredients" do
    it "resolves matched catalog ingredients only" do
      create(:ingredient, name: "banana", aliases: [ "banana", "overripe bananas" ])
      create(:ingredient, name: "salt", aliases: [ "salt", "kosher salt" ], optional: true)
      recipe = build(:recipe, ingredient_names: [ "overripe bananas", "kosher salt", "unknown" ])

      expect(recipe.catalog_ingredients.map(&:name)).to eq([ "banana", "salt" ])
      expect(recipe.catalog_ingredients.map(&:optional)).to eq([ false, true ])
    end
  end

  describe "#recipe_ingredients_data" do
    it "maps all raw ingredient names to their catalog canonical name, with nil for unmatched" do
      create(:ingredient, name: "banana", aliases: [ "banana", "overripe bananas" ])
      create(:ingredient, name: "salt", aliases: [ "salt", "kosher salt" ], optional: true)
      recipe = build(:recipe, ingredient_names: [ "overripe bananas", "kosher salt", "unknown" ])

      expect(recipe.recipe_ingredients_data).to eq([
        { name: "overripe bananas", matchName: "banana" },
        { name: "kosher salt", matchName: "salt" },
        { name: "unknown", matchName: nil }
      ])
    end
  end

  describe "#parsed_ingredients" do
    it "resolves parsed ingredient details with catalog metadata" do
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

      result = recipe.parsed_ingredients.first

      expect(result).to be_a(ParsedIngredient)
      expect(result.name).to eq("overripe bananas")
      expect(result.catalog_name).to eq("banana")
      expect(result.catalog_names).to eq([ "banana" ])
      expect(result.optional).to be(false)
      expect(result.state).to eq("mashed")
    end

    it "resolves multi-name parser rows with all catalog names" do
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

      result = recipe.parsed_ingredients.first

      expect(result.name).to eq("crusty sourdough and ciabatta bread")
      expect(result.name_parts).to eq([
        { name: "crusty sourdough", catalog_name: "crusty sourdough" },
        { name: "ciabatta bread", catalog_name: "bread" }
      ])
      expect(result.catalog_name).to eq("crusty sourdough")
      expect(result.catalog_names).to eq([ "crusty sourdough", "bread" ])
      expect(result.optional).to be(false)
    end
  end

  describe "validations" do
    it "leaves parser data alignment to import and indexing workflows" do
      recipe = build(:recipe, ingredients: [ "1 cup flour", "1 egg" ], ingredient_parse_data: [ { "input" => "1 cup flour" } ])

      expect(recipe).to be_valid
    end
  end
end

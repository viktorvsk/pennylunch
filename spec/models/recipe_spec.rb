require "rails_helper"

RSpec.describe Recipe do
  describe ".slug_for" do
    it "skips blank category parts" do
      slug = described_class.slug_for(
        title: "Tomato Pasta",
        category: "",
        author: "Pasta Maker",
        total_time: 23
      )

      expect(slug).to eq("Tomato-Pasta-Pasta-Maker-23-minutes")
    end
  end

  describe ".display_image_url_for" do
    it "extracts direct Allrecipes image URLs from Meredith proxy URLs" do
      url = "https://imagesvc.meredithcorp.io/v3/mm/image?url=https%3A%2F%2Fimages.media-allrecipes.com%2Fuserphotos%2F8263243.jpg"

      expect(described_class.display_image_url_for(url)).to eq("https://images.media-allrecipes.com/userphotos/8263243.jpg")
    end

    it "keeps non-proxy image URLs unchanged" do
      url = "https://example.com/recipe.jpg"

      expect(described_class.display_image_url_for(url)).to eq(url)
    end
  end

  describe "#ingredients_embedding_text" do
    it "preserves parser ingredient names without canonicalizing them" do
      recipe = build(:recipe, ingredients: [ "1 cup Flour", "2 eggs" ], ingredient_names: [ " Flour ", "EGGS", "flour" ])

      recipe.valid?

      expect(recipe.ingredient_names).to eq([ "flour", "eggs" ])
      expect(recipe.ingredients_embedding_text).to eq("flour\neggs")
    end

    it "uses vector ingredient names when they are available" do
      recipe = build(:recipe, ingredient_names: [ "chicken", "salt" ], ingredients_vector_names: [ "chicken" ])

      recipe.valid?

      expect(recipe.ingredients_embedding_text).to eq("chicken")
    end
  end

  describe "validations" do
    it "allows empty parser data but rejects parser data that does not match source ingredients" do
      recipe = build(:recipe, ingredients: [ "1 cup flour", "1 egg" ], ingredient_parse_data: [ { "input" => "1 cup flour" } ])

      expect(recipe).not_to be_valid
      expect(recipe.errors[:ingredient_parse_data]).to include("must match ingredients")

      recipe.ingredient_parse_data = []
      expect(recipe).to be_valid
    end
  end
end

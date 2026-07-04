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
  end

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

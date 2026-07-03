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

  describe ".category_from_slug" do
    it "resolves normalized categories from parameterized slugs" do
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")

      expect(described_class.category_slug_for("air fryer main dish recipes")).to eq("air-fryer-main-dish-recipes")
      expect(described_class.category_from_slug("air-fryer-main-dish-recipes")).to eq("air fryer main dish recipes")
    end
  end

  describe ".ingredient_filter_options" do
    it "includes known ingredient names and derived exact ingredient terms" do
      create(:recipe, ingredient_names: [ "boneless chicken breasts", "fresh tomatoes", "all-purpose flour" ])

      expect(described_class.ingredient_filter_options).to include(
        "boneless chicken breasts",
        "chicken",
        "tomato",
        "flour"
      )
      expect(described_class.ingredient_filter_options).not_to include("boneless", "fresh", "purpose")
    end
  end

  describe ".similar_by_ingredients" do
    it "returns nearest ingredient-vector neighbors without requiring the same category" do
      recipe = create(:recipe, title: "Tomato Pasta", category: "Pasta", ingredients_vector: vector(1.0, 0.0))
      closest = create(:recipe, title: "Tomato Soup", category: "Soup", ingredients_vector: vector(0.98, 0.02))
      next_closest = create(:recipe, title: "Garlic Tomatoes", category: "Salad", ingredients_vector: vector(0.9, 0.1))
      create(:recipe, title: "Same Category Without Vector", category: "Pasta", ingredients_vector: nil)
      create(:recipe, title: "Apple Cake", category: "Pasta", ingredients_vector: vector(-1.0, 0.0))

      expect(described_class.similar_by_ingredients(recipe, limit: 2)).to eq([ closest, next_closest ])
    end

    it "returns none when the recipe has no ingredient vector" do
      recipe = create(:recipe, ingredients_vector: nil)
      create(:recipe, ingredients_vector: vector(1.0, 0.0))

      expect(described_class.similar_by_ingredients(recipe)).to be_empty
    end
  end

  describe "#ingredients_embedding_text" do
    it "uses normalized ingredient names instead of source ingredient sentences" do
      recipe = build(:recipe, ingredients: [ "1 cup Flour", "2 eggs" ], ingredient_names: [ " Flour ", "EGGS", "flour" ])

      recipe.valid?

      expect(recipe.ingredient_names).to eq([ "flour", "eggs" ])
      expect(recipe.ingredients_embedding_text).to eq("flour\neggs")
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

  describe "query scopes" do
    it "filters and sorts recipes" do
      quick_popular = create(:recipe, title: "Quick Tomato Pasta", prep_time: 8, cook_time: 15, ratings: 4.91, category: "Pasta")
      slow = create(:recipe, title: "Slow Roast Chicken", prep_time: 20, cook_time: 120, ratings: 4.5, category: "Dinner")
      other = create(:recipe, title: "Blueberry Muffins", prep_time: 10, cook_time: 18, ratings: 4.85, category: "Breakfast")
      unknown_time = create(:recipe, title: "Mystery Bread", prep_time: 0, cook_time: 0, ratings: 4.7, category: "Bread")

      expect(described_class.matching_title("tomato")).to contain_exactly(quick_popular)
      expect(described_class.in_category("pasta")).to contain_exactly(quick_popular)
      expect(described_class.quick).to contain_exactly(quick_popular, other)
      expect(described_class.popular).to contain_exactly(quick_popular, other)
      expect(described_class.sorted_by("time_asc")).to eq([ quick_popular, other, slow, unknown_time ])
      expect(described_class.sorted_by("time_desc")).to eq([ unknown_time, slow, other, quick_popular ])
      expect(described_class.sorted_by("rating_asc")).to eq([ slow, unknown_time, other, quick_popular ])
    end
  end

  describe ".category_options" do
    it "returns unique lowercase categories without blanks" do
      create(:recipe, category: "Dinner", category_normalized: "dinner")
      create(:recipe, category: "dinner", category_normalized: "dinner")
      create(:recipe, category: "", category_normalized: "")

      expect(described_class.category_options).to eq([ "dinner" ])
    end
  end

  describe ".category_labels" do
    it "maps normalized categories to original display names" do
      create(:recipe, category: "Air Fryer Main Dish Recipes", category_normalized: "air fryer main dish recipes")
      create(:recipe, category: "air fryer main dish recipes", category_normalized: "air fryer main dish recipes")

      expect(described_class.category_labels).to eq(
        "air fryer main dish recipes" => "Air Fryer Main Dish Recipes"
      )
    end
  end

  def vector(first_value, second_value = 0.0)
    [ first_value, second_value ] + Array.new(382, 0.0)
  end
end

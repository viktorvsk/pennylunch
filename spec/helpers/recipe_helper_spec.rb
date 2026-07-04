require "rails_helper"

RSpec.describe RecipeHelper, type: :helper do
  describe "#recipe_duration_text" do
    it "renders recipe durations in human-friendly hour and minute parts" do
      expect(helper.recipe_duration_text(45)).to eq("45 minutes")
      expect(helper.recipe_duration_text(60)).to eq("1 hour")
      expect(helper.recipe_duration_text(65)).to eq("1 hour 5 minutes")
      expect(helper.recipe_duration_text(105)).to eq("1 hour 45 minutes")
    end
  end

  describe "#recipe_ui_catalog" do
    it "fetches the shared recipe UI catalog through a short-lived cache" do
      create(:ingredient, name: "tomato", optional: true)
      create(:recipe, category: "Pasta", category_normalized: "pasta")
      allow(Rails.cache).to receive(:fetch).and_call_original

      catalog = helper.recipe_ui_catalog

      expect(catalog).to include(
        ingredient_options: [ { name: "tomato", optional: true } ],
        category_slugs: { "pasta" => "pasta" },
        category_labels: { "pasta" => "Pasta" }
      )
      expect(helper.recipe_category_from_slug("pasta")).to eq("pasta")
      expect(Rails.cache).to have_received(:fetch).with(
        [
          RecipeHelper::RECIPE_UI_CATALOG_CACHE_KEY,
          Ingredient.all.cache_key_with_version,
          Recipe.all.cache_key_with_version
        ]
      ).at_least(:once)
    end

    it "does not serve a stale empty ingredient catalog after ingredients are created" do
      cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(cache)

      expect(helper.recipe_ui_catalog.fetch(:ingredient_options)).to eq([])

      create(:ingredient, name: "avocado")

      expect(helper.recipe_ui_catalog.fetch(:ingredient_options)).to eq([
        { name: "avocado", optional: false }
      ])
    end
  end

  describe "#recipe_toolbar_state" do
    it "builds toolbar display state from filters and selected category" do
      create(:recipe, category: "Pasta", category_normalized: "pasta")

      expect(helper.recipe_toolbar_state(filters: { "sort" => "rating_desc", "quick" => "1", "popular" => "0" }, selected_category: "pasta")).to have_attributes(
        current_sort: "rating_desc",
        quick_active: true,
        popular_active: false,
        category_labels: { "pasta" => "Pasta" },
        selected_category_label: "Pasta",
        category_tooltip: "Category: Pasta"
      )
    end

    it "defaults to best matching sort" do
      expect(helper.recipe_toolbar_state(filters: {}, selected_category: nil).current_sort).to eq("best_match")
      expect(helper.recipe_sort_label(nil)).to eq("Best Match")
      expect(helper.recipe_sort_options).to include(
        "best_match" => "Best Match",
        "time_asc" => "Fastest First",
        "time_desc" => "Slowest First",
        "rating_asc" => "Popular Last",
        "rating_desc" => "Popular First"
      )
    end
  end
end

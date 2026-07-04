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

  describe "#recipe_catalog" do
    let(:catalog) do
      Catalog.new(
        ingredient_options: [ { name: "tomato", optional: true } ],
        category_labels: { "pasta" => "Pasta" },
        category_slugs: { "pasta" => "pasta" }
      )
    end

    before do
      allow(Catalog).to receive(:fetch).and_return(catalog)
    end

    it "delegates shared catalog loading to Catalog" do
      expect(helper.recipe_catalog).to eq(catalog)
      expect(helper.recipe_category_labels).to eq("pasta" => "Pasta")
      expect(helper.recipe_category_from_slug("pasta")).to eq("pasta")
    end

    it "serializes the shared catalog browser payload" do
      expect(JSON.parse(helper.recipe_catalog_json)).to eq(
        "ingredientOptions" => [ { "name" => "tomato", "optional" => true } ],
        "categoryLabels" => { "pasta" => "Pasta" },
        "categorySlugs" => { "pasta" => "pasta" }
      )
    end
  end

  describe "#recipe_toolbar_state" do
    it "builds toolbar display state from filters and selected category" do
      allow(Catalog).to receive(:fetch).and_return(
        Catalog.new(
          ingredient_options: [],
          category_labels: { "pasta" => "Pasta" },
          category_slugs: { "pasta" => "pasta" }
        )
      )

      expect(helper.recipe_toolbar_state(filters: { "sort" => "rating_desc", "quick" => "1", "popular" => "0" }, selected_category: "pasta")).to have_attributes(
        current_sort: "rating_desc",
        current_sort_label: "Popular First",
        quick_active: true,
        popular_active: false,
        selected_category: "pasta",
        selected_category_label: "Pasta",
        category_tooltip: "Category: Pasta"
      )
    end
  end
end

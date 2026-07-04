require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
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
        ApplicationHelper::RECIPE_UI_CATALOG_CACHE_KEY,
        expires_in: ApplicationHelper::RECIPE_UI_CATALOG_CACHE_EXPIRATION
      ).at_least(:once)
    end
  end
end

require "rails_helper"

RSpec.describe RecipeToolbar do
  describe ".build" do
    it "builds toolbar display state from filters and category labels" do
      toolbar = described_class.build(
        filters: { "sort" => "rating_desc", "quick" => "1", "popular" => "0" },
        selected_category: "pasta",
        category_labels: { "pasta" => "Pasta", "air fryer" => "Air Fryer" }
      )

      expect(toolbar).to have_attributes(
        current_sort: "rating_desc",
        current_sort_label: "Popular First",
        quick_active: true,
        popular_active: false,
        selected_category: "pasta",
        selected_category_label: "Pasta",
        category_tooltip: "Category: Pasta"
      )
      expect(toolbar.sort_options.map { |option| [ option.value, option.label ] }).to eq([
        [ "best_match", "Best Match" ],
        [ "time_asc", "Fastest First" ],
        [ "time_desc", "Slowest First" ],
        [ "rating_asc", "Popular Last" ],
        [ "rating_desc", "Popular First" ]
      ])
      expect(toolbar.category_options.map { |option| [ option.value, option.label ] }).to eq([
        [ "pasta", "Pasta" ],
        [ "air fryer", "Air Fryer" ]
      ])
    end

    it "defaults unknown sort and empty category state" do
      toolbar = described_class.build(
        filters: { "sort" => "unknown", "quick" => nil, "popular" => "" },
        selected_category: nil,
        category_labels: {}
      )

      expect(toolbar).to have_attributes(
        current_sort: "best_match",
        current_sort_label: "Best Match",
        quick_active: false,
        popular_active: false,
        selected_category: "",
        selected_category_label: nil,
        category_tooltip: "Category: all categories"
      )
    end
  end
end

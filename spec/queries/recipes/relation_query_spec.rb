require "rails_helper"

RSpec.describe Recipes::RelationQuery do
  it "filters and sorts recipes by the public search controls" do
    quick_popular = create(:recipe, title: "Quick Tomato Pasta", prep_time: 8, cook_time: 15, ratings: 4.91, category: "Pasta")
    slow = create(:recipe, title: "Slow Roast Chicken", prep_time: 20, cook_time: 120, ratings: 4.5, category: "Dinner")
    other = create(:recipe, title: "Blueberry Muffins", prep_time: 10, cook_time: 18, ratings: 4.85, category: "Breakfast")
    unknown_time = create(:recipe, title: "Mystery Bread", prep_time: 0, cook_time: 0, ratings: 4.7, category: "Bread")

    expect(described_class.call(params: { q: "tomato" })).to contain_exactly(quick_popular)
    expect(described_class.call(params: { category: "pasta" })).to contain_exactly(quick_popular)
    expect(described_class.call(params: { quick: "1" })).to contain_exactly(quick_popular, other)
    expect(described_class.call(params: { popular: "1" })).to contain_exactly(quick_popular, other)
    expect(described_class.sort(Recipe.all, "time_asc")).to eq([ quick_popular, other, slow, unknown_time ])
    expect(described_class.sort(Recipe.all, "time_desc")).to eq([ unknown_time, slow, other, quick_popular ])
    expect(described_class.sort(Recipe.all, "rating_asc")).to eq([ slow, unknown_time, other, quick_popular ])
  end
end

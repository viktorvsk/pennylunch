require "rails_helper"

RSpec.describe "Recipe filters", type: :system do
  let(:expected_title) { "E2E Turbo Filter Tomato Pasta" }
  let(:excluded_titles) do
    [
      "E2E Turbo Filter Slow Tomato Pasta",
      "E2E Turbo Filter Tomato Budget",
      "E2E Turbo Filter Garlic Rice",
      "E2E Turbo Filter Dessert Tomato"
    ]
  end

  before do
    create(
      :recipe,
      title: expected_title,
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.99
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Slow Tomato Pasta",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 60,
      cook_time: 30,
      ratings: 4.98
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Tomato Budget",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 8,
      ratings: 4.1
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Garlic Rice",
      category: "E2E Dinner",
      category_normalized: "e2e dinner",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.97
    )
    create(
      :recipe,
      title: "E2E Turbo Filter Dessert Tomato",
      category: "E2E Dessert",
      category_normalized: "e2e dessert",
      prep_time: 5,
      cook_time: 10,
      ratings: 4.96
    )
  end

  it "filters relevant recipes through Turbo navigation" do
    visit recipes_path

    find("input[name='q']").set("E2E Turbo Filter Tomato")
    expect(page).to have_current_path(%r{/recipes\?q=E2E\+Turbo\+Filter\+Tomato})

    find("button[aria-label='Category']").click
    find("#recipe-category-popover input").set("E2E Dinner")
    find("[role='option'][data-value='e2e dinner']").click
    expect(page).to have_current_path(%r{/recipes/e2e-dinner\?q=E2E\+Turbo\+Filter\+Tomato})

    find(:xpath, "//label[.//input[@name='quick']]").click
    expect(page).to have_current_path(/quick=1/)
    find(:xpath, "//label[.//input[@name='popular']]").click
    expect(page).to have_current_path(/popular=1/)

    within "#recipe-results-frame" do
      expect(page).to have_text(expected_title)
      excluded_titles.each { |title| expect(page).to have_no_text(title) }
    end

    expect(page).to have_css(".recipe-toolbar-toggle[data-state='active']", count: 2)
    expect(page).to have_css("#recipe-ingredients-fab[data-turbo-permanent]", count: 1)
    expect(page).to have_current_path("/recipes/e2e-dinner", ignore_query: true)
  end
end

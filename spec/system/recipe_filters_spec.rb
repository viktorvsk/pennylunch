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

  it "highlights index card ingredients from the active filter context" do
    create(:ingredient, name: "honey")
    create(:recipe, title: "E2E Honey Toast", ingredient_names: [ "honey", "bread" ])

    visit recipes_path

    page.execute_script(<<~JS)
      window.PennyLunch.writeBasket({ selected: ["honey"], enabled: false });
      window.PennyLunch.applyIngredientMatches();
    JS

    expect(page).to have_no_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")

    page.execute_script(<<~JS)
      document.querySelector("[data-ingredients-filter-hidden]").value = "honey";
      window.PennyLunch.applyIngredientMatches();
    JS

    expect(page).to have_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")
  end

  it "does not resubmit ingredient filters after returning from a show page" do
    honey = create(:ingredient, name: "honey")
    matching_recipe = create(:recipe, title: "E2E Cookie Basket Honey Toast", ingredient_names: [ "honey" ])
    create(:recipe, title: "E2E Cookie Basket Apple Cake", ingredient_names: [ "apple" ])
    create(:recipe_ingredient, recipe: matching_recipe, ingredient: honey)

    visit recipe_path(matching_recipe)

    page.execute_script(<<~JS)
      window.__pennylunchFetches = [];
      document.addEventListener("turbo:before-fetch-request", (event) => {
        window.__pennylunchFetches.push(event.detail.url.toString());
      });
      window.PennyLunch.writeBasket({ selected: ["honey"], enabled: true });
    JS

    click_link "PennyLunch"

    expect(page).to have_current_path("/")
    expect(page).to have_text("E2E Cookie Basket Honey Toast")
    expect(page).to have_no_text("E2E Cookie Basket Apple Cake")

    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 300);")

    expect(page.evaluate_script("window.__pennylunchFetches").count).to eq(1)
  end
end

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
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: ["honey"], enabled: false }))}; Path=/; SameSite=Lax`;
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    expect(page).to have_no_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")

    page.execute_script(<<~JS)
      document.querySelector("[data-auto-submit-target~='ingredients']").value = "honey";
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    expect(page).to have_css(".recipe-card-ingredients .recipe-ingredient-match", text: "honey")
  end

  it "renders the basket panel with a bottom autocomplete input and no add button" do
    visit recipes_path

    find("[data-ingredients-fab-target='trigger']").click

    expect(page).to have_no_css("[data-ingredients-fab-target='addButton']")
    expect(page).to have_no_text("Add Ingredient")

    layout = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("#recipe-ingredients-panel").getBoundingClientRect();
        const picker = document.querySelector(".recipe-ingredients-picker");
        const pickerRect = picker.getBoundingClientRect();
        const selected = document.querySelector(".recipe-ingredients-selected").getBoundingClientRect();
        const emptyState = document.querySelector(".recipe-ingredients-empty-state").getBoundingClientRect();
        const emptyStatePhrase = document.querySelector(".recipe-ingredients-empty-state-phrase").getBoundingClientRect();
        const emptyStateMark = getComputedStyle(document.querySelector(".recipe-ingredients-empty-state"), "::before");
        const inputGroup = document.querySelector(".recipe-ingredients-input-group").getBoundingClientRect();
        const pickerStyle = getComputedStyle(picker);
        const paddingBottom = Number.parseFloat(getComputedStyle(picker).paddingBottom);
        const gap = Number.parseFloat(pickerStyle.rowGap || pickerStyle.gap);

        return {
          inputBottomGap: Math.round(panel.bottom - inputGroup.bottom - paddingBottom),
          selectedTopGap: Math.round(selected.top - pickerRect.top),
          selectedInputGap: Math.round(inputGroup.top - selected.bottom - gap),
          selectedHeight: Math.round(selected.height),
          emptyStateBackground: emptyStateMark.backgroundImage,
          emptyStatePhraseBelowCenter: emptyStatePhrase.top > (emptyState.top + emptyState.height / 2),
          emptyStatePhraseLeftGap: Math.round(emptyStatePhrase.left - selected.left),
          emptyStatePhraseRightGap: Math.round(selected.right - emptyStatePhrase.right)
        };
      })()
    JS

    expect(layout.fetch("inputBottomGap").abs).to be <= 2
    expect(layout.fetch("selectedTopGap").abs).to be <= 2
    expect(layout.fetch("selectedInputGap").abs).to be <= 2
    expect(layout.fetch("selectedHeight")).to be_positive
    expect(layout.fetch("emptyStateBackground")).to include("/icon-512x512.png")
    expect(layout.fetch("emptyStatePhraseBelowCenter")).to be(true)
    expect(layout.fetch("emptyStatePhraseLeftGap")).to be >= 16
    expect(layout.fetch("emptyStatePhraseRightGap")).to be >= 16
  end

  it "keeps the basket panel open after adding an ingredient while filtering is enabled" do
    honey = create(:ingredient, name: "honey")
    matching_recipe = create(:recipe, title: "E2E Honey Toast", ingredient_names: [ "honey" ])
    create(:recipe_ingredient, recipe: matching_recipe, ingredient: honey)

    visit recipes_path

    find("[data-ingredients-fab-target='trigger']").click
    find(".recipe-ingredients-switch").click
    expect(page).to have_text("only matching recipes are displayed.")

    find("#recipe-ingredients-input").set("hon")
    expect(page).to have_css(".recipe-ingredients-option", text: "honey")
    find("#recipe-ingredients-input").send_keys(:enter)
    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 400);")

    expect(page).to have_css("#recipe-ingredients-panel:not([hidden])")
    expect(page).to have_css(".recipe-ingredients-row", text: "honey")
    expect(page).to have_text("only matching recipes are displayed.")
    expect(page).to have_no_text("Your basket is empty.")

    empty_state = page.evaluate_script(<<~JS)
      (() => {
        const emptyState = document.querySelector(".recipe-ingredients-empty-state");
        const phrase = document.querySelector(".recipe-ingredients-empty-state-phrase");
        const mark = getComputedStyle(emptyState, "::before");

        return {
          stateDisplay: getComputedStyle(emptyState).display,
          phraseDisplay: getComputedStyle(phrase).display,
          markImage: mark.backgroundImage
        };
      })()
    JS

    expect(empty_state.fetch("stateDisplay")).not_to eq("none")
    expect(empty_state.fetch("phraseDisplay")).to eq("none")
    expect(empty_state.fetch("markImage")).to include("/icon-512x512.png")
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
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: ["honey"], enabled: true }))}; Path=/; SameSite=Lax`;
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"));
    JS

    click_link "PennyLunch"

    expect(page).to have_current_path("/")
    expect(page).to have_text("E2E Cookie Basket Honey Toast")
    expect(page).to have_no_text("E2E Cookie Basket Apple Cake")

    page.driver.browser.execute_async_script("const done = arguments[arguments.length - 1]; setTimeout(done, 300);")

    expect(page.evaluate_script("window.__pennylunchFetches").count).to eq(1)
  end
end

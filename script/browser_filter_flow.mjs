import { assertServerReady, baseUrl, launchBrowser, runRailsRunner } from "./browser_helpers.mjs"

const expectedTitle = "E2E Turbo Filter Tomato Pasta"
const excludedTitles = [
  "E2E Turbo Filter Slow Tomato Pasta",
  "E2E Turbo Filter Tomato Budget",
  "E2E Turbo Filter Garlic Rice",
  "E2E Turbo Filter Dessert Tomato"
]

function seedData() {
  runRailsRunner(`
    def e2e_vector(first_value, second_value = 0.0)
      [first_value, second_value] + Array.new(382, 0.0)
    end

    ActiveRecord::Base.transaction do
      Recipe.where("title LIKE ?", "E2E Turbo Filter%").delete_all

      [
        ["e2e tomato", false],
        ["e2e pasta", false],
        ["e2e garlic", false]
      ].each do |name, optional|
        ingredient = Ingredient.find_or_initialize_by(name: name)
        ingredient.aliases = [name]
        ingredient.optional = optional
        ingredient.save!
      end

      [
        {
          title: "E2E Turbo Filter Tomato Pasta",
          category: "E2E Dinner",
          prep_time: 5,
          cook_time: 10,
          ratings: 4.99,
          ingredients: ["e2e tomato", "e2e pasta"],
          ingredient_names: ["e2e tomato", "e2e pasta"],
          ingredients_vector: e2e_vector(1.0, 0.0),
          source_position: -10_001
        },
        {
          title: "E2E Turbo Filter Slow Tomato Pasta",
          category: "E2E Dinner",
          prep_time: 60,
          cook_time: 30,
          ratings: 4.98,
          ingredients: ["e2e tomato", "e2e pasta"],
          ingredient_names: ["e2e tomato", "e2e pasta"],
          ingredients_vector: e2e_vector(0.99, 0.01),
          source_position: -10_002
        },
        {
          title: "E2E Turbo Filter Tomato Budget",
          category: "E2E Dinner",
          prep_time: 5,
          cook_time: 8,
          ratings: 4.1,
          ingredients: ["e2e tomato"],
          ingredient_names: ["e2e tomato"],
          ingredients_vector: e2e_vector(0.98, 0.02),
          source_position: -10_003
        },
        {
          title: "E2E Turbo Filter Garlic Rice",
          category: "E2E Dinner",
          prep_time: 5,
          cook_time: 10,
          ratings: 4.97,
          ingredients: ["e2e garlic"],
          ingredient_names: ["e2e garlic"],
          ingredients_vector: e2e_vector(0.0, 1.0),
          source_position: -10_004
        },
        {
          title: "E2E Turbo Filter Dessert Tomato",
          category: "E2E Dessert",
          prep_time: 5,
          cook_time: 10,
          ratings: 4.96,
          ingredients: ["e2e tomato"],
          ingredient_names: ["e2e tomato"],
          ingredients_vector: e2e_vector(0.95, 0.05),
          source_position: -10_005
        }
      ].each do |attributes|
        Recipe.create!(
          attributes.merge(
            author: "E2E Cook",
            cuisine: "",
            image: "https://example.com/e2e-recipe.jpg",
            ingredient_parse_data: attributes.fetch(:ingredients).map { |ingredient| { "input" => ingredient, "parser" => { "sentence" => ingredient } } }
          )
        )
      end
    end

    Rails.cache.delete(RecipeHelper::RECIPE_UI_CATALOG_CACHE_KEY)
  `)
}

function cleanupData() {
  runRailsRunner(`
    ActiveRecord::Base.transaction do
      Recipe.where("title LIKE ?", "E2E Turbo Filter%").delete_all
      Ingredient.where(name: ["e2e tomato", "e2e pasta", "e2e garlic"]).delete_all
    end

    Rails.cache.delete(RecipeHelper::RECIPE_UI_CATALOG_CACHE_KEY)
  `)
}

async function waitForFilteredResults(page) {
  await page.waitForFunction(({ expectedTitle, excludedTitles }) => {
    const frame = document.querySelector("#recipe-results-frame")
    const text = frame?.textContent || ""
    return text.includes(expectedTitle) && excludedTitles.every((title) => !text.includes(title))
  }, { expectedTitle, excludedTitles })
}

async function selectCategory(page, label, value) {
  await page.locator("#recipe-category-combobox[data-combobox-initialized='true']").waitFor()
  await page.locator("button[aria-label='Category']").click()
  try {
    await page.waitForFunction(() => document.querySelector("#recipe-category-popover")?.getAttribute("aria-hidden") === "false", null, { timeout: 3_000 })
  } catch {
    const state = await page.evaluate(() => ({
      initialized: document.querySelector("#recipe-category-combobox")?.dataset.comboboxInitialized,
      component: document.querySelector("#recipe-category-combobox")?.dataset.basecoatComponent,
      expanded: document.querySelector("button[aria-label='Category']")?.getAttribute("aria-expanded"),
      hidden: document.querySelector("#recipe-category-popover")?.getAttribute("aria-hidden")
    }))
    throw new Error(`Category popover did not open: ${JSON.stringify(state)}`)
  }
  await page.locator("#recipe-category-popover input").fill(label)
  try {
    await page.waitForFunction((categoryValue) => {
      const option = document.querySelector(`[role='option'][data-value='${categoryValue}']`)
      return option?.getAttribute("aria-hidden") === "false"
    }, value, { timeout: 3_000 })
  } catch {
    const state = await page.evaluate((categoryValue) => {
      const option = document.querySelector(`[role='option'][data-value='${categoryValue}']`)
      return {
        exists: Boolean(option),
        optionHidden: option?.getAttribute("aria-hidden"),
        inputValue: document.querySelector("#recipe-category-popover input")?.value,
        visibleOptions: Array.from(document.querySelectorAll("[role='option'][aria-hidden='false']")).slice(0, 10).map((option) => option.textContent?.trim())
      }
    }, value)
    throw new Error(`Category option did not become visible: ${JSON.stringify(state)}`)
  }
  await page.locator(`[role='option'][data-value='${value}']`).click()
}

async function assertToolbarIconControlsOpenAfterTurboRestore(page) {
  await page.locator(".recipe-card > a[href^='/recipes/']").first().click()
  await page.waitForURL(/\/recipes\/.+-\d+/)
  await page.goBack()
  await page.waitForURL(/\/recipes\/e2e-dinner/)
  await page.locator("#recipe-results-frame").waitFor()

  await page.locator("button[aria-label='Category']").click()
  try {
    await page.waitForFunction(() => document.querySelector("#recipe-category-popover")?.getAttribute("aria-hidden") === "false", null, { timeout: 3_000 })
  } catch {
    const state = await page.evaluate(() => ({
      initialized: document.querySelector("#recipe-category-combobox")?.dataset.comboboxInitialized,
      component: document.querySelector("#recipe-category-combobox")?.dataset.basecoatComponent,
      expanded: document.querySelector("button[aria-label='Category']")?.getAttribute("aria-expanded"),
      hidden: document.querySelector("#recipe-category-popover")?.getAttribute("aria-hidden")
    }))
    throw new Error(`Restored category control did not open: ${JSON.stringify(state)}`)
  }

  await page.locator("button[aria-label='Sort']").click()
  try {
    await page.waitForFunction(() => document.querySelector("#recipe-sort-popover")?.getAttribute("aria-hidden") === "false", null, { timeout: 3_000 })
  } catch {
    const state = await page.evaluate(() => ({
      initialized: document.querySelector("#recipe-sort-menu")?.dataset.dropdownMenuInitialized,
      component: document.querySelector("#recipe-sort-menu")?.dataset.basecoatComponent,
      expanded: document.querySelector("button[aria-label='Sort']")?.getAttribute("aria-expanded"),
      hidden: document.querySelector("#recipe-sort-popover")?.getAttribute("aria-hidden")
    }))
    throw new Error(`Restored sort control did not open: ${JSON.stringify(state)}`)
  }
}

async function main() {
  let browser

  try {
    seedData()
    await assertServerReady()

    const browserSession = await launchBrowser({ width: 1280, height: 900 })
    browser = browserSession.browser
    const { page } = browserSession

    await page.goto(`${baseUrl}/recipes`, { waitUntil: "networkidle" })
    await page.locator("input[name='q']").fill("E2E Turbo Filter Tomato")
    await page.waitForURL(/q=E2E\+Turbo\+Filter\+Tomato/)

    await selectCategory(page, "E2E Dinner", "e2e dinner")
    await page.waitForURL(/\/recipes\/e2e-dinner/)

    await page.locator("input[name='quick']").check({ force: true })
    await page.waitForURL(/quick=1/)
    await page.locator("input[name='popular']").check({ force: true })
    await page.waitForURL(/popular=1/)
    await waitForFilteredResults(page)

    const frameText = await page.locator("#recipe-results-frame").innerText()
    if (!frameText.includes(expectedTitle)) throw new Error(`Expected ${expectedTitle} in filtered results.`)
    for (const title of excludedTitles) {
      if (frameText.includes(title)) throw new Error(`Did not expect ${title} in filtered results.`)
    }

    const activeToggles = await page.locator(".recipe-toolbar-toggle[data-state='active']").count()
    const fabCount = await page.locator("#recipe-ingredients-fab[data-turbo-permanent]").count()
    const currentUrl = new URL(page.url())

    if (activeToggles < 2) throw new Error("Quick and popular switches were not both active after filtering.")
    if (fabCount !== 1) throw new Error("Ingredients FAB was not preserved during filter navigation.")
    if (currentUrl.pathname !== "/recipes/e2e-dinner") throw new Error(`Expected category slug path, got ${currentUrl.pathname}.`)

    await assertToolbarIconControlsOpenAfterTurboRestore(page)

    console.log(JSON.stringify({
      baseUrl,
      path: currentUrl.pathname,
      query: Object.fromEntries(currentUrl.searchParams.entries()),
      result: expectedTitle,
      excluded: excludedTitles
    }, null, 2))
  } finally {
    await browser?.close()
    cleanupData()
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})

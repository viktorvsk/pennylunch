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
          ingredients_vector_names: ["e2e tomato", "e2e pasta"],
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
          ingredients_vector_names: ["e2e tomato", "e2e pasta"],
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
          ingredients_vector_names: ["e2e tomato"],
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
          ingredients_vector_names: ["e2e garlic"],
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
          ingredients_vector_names: ["e2e tomato"],
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
  `)
}

function cleanupData() {
  runRailsRunner(`
    ActiveRecord::Base.transaction do
      Recipe.where("title LIKE ?", "E2E Turbo Filter%").delete_all
      Ingredient.where(name: ["e2e tomato", "e2e pasta", "e2e garlic"]).delete_all
    end
  `)
}

async function waitForFilteredResults(page) {
  await page.waitForFunction(({ expectedTitle, excludedTitles }) => {
    const frame = document.querySelector("#recipe-results-frame")
    const text = frame?.textContent || ""
    return text.includes(expectedTitle) && excludedTitles.every((title) => !text.includes(title))
  }, { expectedTitle, excludedTitles })
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

    await page.locator("button[aria-label='Category']").click()
    await page.locator("#recipe-category-popover input").fill("E2E Dinner")
    await page.locator("[role='option'][data-value='e2e dinner']").click()
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

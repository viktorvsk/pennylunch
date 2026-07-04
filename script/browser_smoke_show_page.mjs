import { assertServerReady, baseUrl, launchBrowser } from "./browser_helpers.mjs"

async function main() {
  await assertServerReady()

  const { browser, page } = await launchBrowser({ width: 1440, height: 1000 })

  try {
    await page.goto(`${baseUrl}/recipes`, { waitUntil: "networkidle" })

    if (await page.locator(".recipe-card > a[href^='/recipes/']").count() === 0) {
      throw new Error("No recipe cards found on /recipes. Import recipe data before running the show-page smoke check.")
    }

    const indexTarget = await page.locator(".recipe-card").evaluateAll((cards) => {
      const catalog = JSON.parse(document.querySelector("[data-recipe-ui-catalog]")?.textContent || "{}")
      const options = new Set((catalog.ingredientOptions || []).map((option) => typeof option === "string" ? option : option.name))

      for (const card of cards) {
        const link = card.querySelector("a[href^='/recipes/']")
        const summary = card.querySelector("[data-recipe-ingredients]")
        if (!link || !summary) continue

        const names = JSON.parse(summary.dataset.ingredientNames || "[]")
        const match = names.find((name) => options.has(name))
        if (match) return { ingredient: match, href: link.getAttribute("href") }
      }

      return null
    })
    const exactIndexIngredient = indexTarget?.ingredient
    if (!exactIndexIngredient) throw new Error("No card ingredient names found for basket highlight smoke check.")

    await page.evaluate((name) => {
      localStorage.setItem("pennylunch.ingredients.selected", JSON.stringify([name]))
      localStorage.setItem("pennylunch.ingredients.text", name)
      localStorage.setItem("pennylunch.ingredients.enabled", "false")
    }, exactIndexIngredient)
    await page.reload({ waitUntil: "networkidle" })

    const indexMatchedIngredient = (await page.locator(".recipe-card-ingredients .recipe-ingredient-match").first().innerText()).trim()
    if (indexMatchedIngredient !== exactIndexIngredient) {
      throw new Error(`Index basket highlight mismatch: expected ${exactIndexIngredient}, got ${indexMatchedIngredient}.`)
    }

    await page.goto(new URL(indexTarget.href, baseUrl).toString(), { waitUntil: "networkidle" })

    const showIngredientName = await page.locator(".recipe-ingredient-link[data-ingredient-name]").evaluateAll((elements) => {
      const catalog = JSON.parse(document.querySelector("[data-recipe-ui-catalog]")?.textContent || "{}")
      const options = new Set((catalog.ingredientOptions || []).map((option) => typeof option === "string" ? option : option.name))

      for (const element of elements) {
        const name = element.dataset.ingredientName
        if (options.has(name)) return name
      }

      return null
    })
    if (!showIngredientName) throw new Error("No show ingredient names found for basket highlight smoke check.")
    await page.evaluate((name) => {
      localStorage.setItem("pennylunch.ingredients.selected", JSON.stringify([name]))
      localStorage.setItem("pennylunch.ingredients.text", name)
    }, showIngredientName)
    await page.reload({ waitUntil: "networkidle" })

    const title = (await page.locator("h1").first().innerText()).trim()
    const breadcrumbCount = await page.locator("[aria-label='Breadcrumb']").count()
    const ingredientRows = await page.locator(".recipe-ingredient-row").count()
    const fabCount = await page.locator("#recipe-ingredients-fab").count()
    const showMatchedIngredient = (await page.locator(".recipe-ingredient-link.recipe-ingredient-match").first().innerText()).trim()
    const similarCards = await page.locator("section:has-text('Similar recipes') .recipe-card").count()
    const columns = await page.locator("main > section").nth(1).evaluate((element) => getComputedStyle(element).gridTemplateColumns)
    const cardBox = await page.locator(".recipe-show-card").boundingBox()
    const ingredientsBox = await page.locator(".recipe-show-ingredients-panel").boundingBox()
    const imageBox = await page.locator(".recipe-show-card .recipe-card-image").boundingBox()
    const image = page.locator(".recipe-show-card .recipe-card-image img")
    await page.mouse.move(4, 4)
    await page.waitForTimeout(100)
    const beforeTransform = await image.evaluate((element) => getComputedStyle(element).transform)
    await page.locator(".recipe-show-card").hover()
    await page.waitForTimeout(350)
    const afterTransform = await image.evaluate((element) => getComputedStyle(element).transform)

    if (!title) throw new Error("Show page is missing its h1 title.")
    if (breadcrumbCount !== 0) throw new Error("Show page still renders breadcrumbs.")
    if (fabCount !== 1) throw new Error("Show page is missing the shared ingredients FAB.")
    if (showMatchedIngredient !== showIngredientName) {
      throw new Error(`Show basket highlight mismatch: expected ${showIngredientName}, got ${showMatchedIngredient}.`)
    }
    if (ingredientRows < 1) throw new Error("Show page ingredient list has no rows.")
    if (similarCards > 3) throw new Error(`Show page renders ${similarCards} similar recipe cards; expected at most 3.`)
    if (columns.split(" ").length < 2) throw new Error("Show page detail layout did not render as two columns at desktop width.")
    if (!cardBox || !imageBox || imageBox.height < cardBox.height * 0.4) throw new Error("Show page image does not occupy the top part of the card.")
    if (!ingredientsBox || Math.abs(cardBox.height - ingredientsBox.height) > 2) throw new Error("Show page media and ingredients columns are not equal height.")
    if (afterTransform === beforeTransform) throw new Error("Show page image hover transform did not change.")

    console.log(JSON.stringify({
      baseUrl,
      title,
      indexMatchedIngredient,
      showMatchedIngredient,
      ingredientRows,
      fabCount,
      similarCards,
      columns,
      imageHeight: Math.round(imageBox.height),
      cardHeight: Math.round(cardBox.height),
      ingredientsHeight: Math.round(ingredientsBox.height)
    }, null, 2))
  } finally {
    await browser.close()
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})

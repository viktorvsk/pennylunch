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
        const summary = card.querySelector("[data-ingredient-matches-target~='summary']")
        const timeTooltip = card.querySelector(".recipe-card-footer .recipe-meta-item[data-tooltip]")
        if (!link || !summary || !timeTooltip) continue

        const names = JSON.parse(summary.dataset.ingredientNames || "[]")
        const match = names.find((name) => options.has(name))
        if (match) return { ingredient: match, href: link.getAttribute("href") }
      }

      return null
    })
    const exactIndexIngredient = indexTarget?.ingredient
    if (!exactIndexIngredient) throw new Error("No timed recipe card ingredient names found for show-page smoke check.")

    await page.evaluate((name) => {
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: [name], enabled: false }))}; Path=/; SameSite=Lax`
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"))
    }, exactIndexIngredient)
    await page.reload({ waitUntil: "networkidle" })

    const disabledIndexMatches = await page.locator(".recipe-card-ingredients .recipe-ingredient-match").count()
    if (disabledIndexMatches !== 0) {
      throw new Error(`Disabled basket highlighted ${disabledIndexMatches} index ingredients.`)
    }

    await page.evaluate((name) => {
      document.querySelector("[data-auto-submit-target~='ingredients']").value = name
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"))
    }, exactIndexIngredient)

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
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: [name], enabled: true }))}; Path=/; SameSite=Lax`
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"))
    }, showIngredientName)
    await page.reload({ waitUntil: "networkidle" })

    const title = (await page.locator("h1").first().innerText()).trim()
    const breadcrumbCount = await page.locator("[aria-label='Breadcrumb']").count()
    const ingredientRows = await page.locator(".recipe-ingredient-row").count()
    const fabCount = await page.locator("#recipe-ingredients-fab").count()
    const showMatchedIngredient = (await page.locator(".recipe-ingredient-row--matched .recipe-ingredient-link").first().innerText()).trim()
    const showLinkHighlightCount = await page.locator(".recipe-ingredient-link.recipe-ingredient-match").count()
    const showMatchedMarker = page.locator(".recipe-ingredient-row--matched .recipe-ingredient-match-icon").first()
    await page.waitForFunction(() => {
      const marker = document.querySelector(".recipe-ingredient-row--matched .recipe-ingredient-match-icon")
      return marker && Number(getComputedStyle(marker).opacity) >= 0.9
    })
    const showMatchedMarkerOpacity = await showMatchedMarker.evaluate((element) => Number(getComputedStyle(element).opacity))
    const showUnmatchedMarker = page.locator(".recipe-ingredient-row:not(.recipe-ingredient-row--matched) .recipe-ingredient-match-icon")
    const showUnmatchedMarkerCount = await showUnmatchedMarker.count()
    const showUnmatchedMarkerOpacity = showUnmatchedMarkerCount > 0 ? await showUnmatchedMarker.first().evaluate((element) => Number(getComputedStyle(element).opacity)) : null
    const similarCards = await page.locator("section:has-text('Similar recipes') .recipe-card").count()
    const columns = await page.locator("main > section").nth(1).evaluate((element) => getComputedStyle(element).gridTemplateColumns)
    const cardBox = await page.locator(".recipe-show-card").boundingBox()
    const ingredientsBox = await page.locator(".recipe-show-ingredients-panel").boundingBox()
    const imageBox = await page.locator(".recipe-show-card .recipe-card-image").boundingBox()
    const image = page.locator(".recipe-show-card .recipe-card-image img")
    const showTimeTooltip = page.locator(".recipe-show-card .recipe-meta-item[data-tooltip]").first()
    await page.mouse.move(4, 4)
    await page.waitForTimeout(100)
    const beforeTransform = await image.evaluate((element) => getComputedStyle(element).transform)
    await page.locator(".recipe-show-card").hover()
    await page.waitForTimeout(350)
    const afterTransform = await image.evaluate((element) => getComputedStyle(element).transform)
    await showTimeTooltip.hover()
    await page.waitForTimeout(200)
    const showTimeTooltipState = await showTimeTooltip.evaluate((element) => {
      const detail = element.closest(".recipe-show-detail")
      const detailRect = detail.getBoundingClientRect()
      const triggerRect = element.getBoundingClientRect()
      const detailStyle = getComputedStyle(detail)
      const tooltipStyle = getComputedStyle(element, "::before")
      const tooltipWidth = Number.parseFloat(tooltipStyle.width)
      const tooltipLeft = triggerRect.left + (triggerRect.width / 2) - (tooltipWidth / 2)

      return {
        detailLeft: detailRect.left,
        detailOverflow: detailStyle.overflow,
        tooltipLeft,
        tooltipOpacity: Number.parseFloat(tooltipStyle.opacity),
        tooltipVisibility: tooltipStyle.visibility,
        tooltipWidth
      }
    })

    if (!title) throw new Error("Show page is missing its h1 title.")
    if (breadcrumbCount !== 0) throw new Error("Show page still renders breadcrumbs.")
    if (fabCount !== 1) throw new Error("Show page is missing the shared ingredients FAB.")
    if (showMatchedIngredient !== showIngredientName) {
      throw new Error(`Show basket highlight mismatch: expected ${showIngredientName}, got ${showMatchedIngredient}.`)
    }
    if (showLinkHighlightCount !== 0) throw new Error("Show page still highlights matched ingredient links.")
    if (showMatchedMarkerOpacity < 0.9) throw new Error("Show page matched ingredient marker is not visible.")
    if (showUnmatchedMarkerOpacity !== null && showUnmatchedMarkerOpacity !== 0) throw new Error("Show page unmatched ingredient marker is visible.")
    if (ingredientRows < 1) throw new Error("Show page ingredient list has no rows.")
    if (similarCards > 3) throw new Error(`Show page renders ${similarCards} similar recipe cards; expected at most 3.`)
    if (columns.split(" ").length < 2) throw new Error("Show page detail layout did not render as two columns at desktop width.")
    if (!cardBox || !imageBox || imageBox.height < cardBox.height * 0.4) throw new Error("Show page image does not occupy the top part of the card.")
    if (!ingredientsBox || Math.abs(cardBox.height - ingredientsBox.height) > 2) throw new Error("Show page media and ingredients columns are not equal height.")
    if (afterTransform === beforeTransform) throw new Error("Show page image hover transform did not change.")
    if (showTimeTooltipState.tooltipVisibility !== "visible") throw new Error("Show page time tooltip is not visible on hover.")
    if (showTimeTooltipState.tooltipOpacity < 0.9) throw new Error("Show page time tooltip did not finish opening.")
    if (showTimeTooltipState.tooltipWidth < 8) throw new Error("Show page time tooltip has no measurable width.")
    if (showTimeTooltipState.tooltipLeft < showTimeTooltipState.detailLeft && showTimeTooltipState.detailOverflow !== "visible") throw new Error("Show page time tooltip is clipped by the detail panel.")

    await page.evaluate(() => {
      document.cookie = `pennylunch.ingredients=${encodeURIComponent(JSON.stringify({ selected: [], enabled: false }))}; Path=/; SameSite=Lax`
      window.dispatchEvent(new CustomEvent("pennylunch:ingredient-basket-change"))
    })
    await page.reload({ waitUntil: "networkidle" })

    const showActionTarget = await page.locator(".recipe-ingredient-row").evaluateAll((rows) => {
      for (const row of rows) {
        const button = row.querySelector(".recipe-ingredient-basket-button")
        const link = row.querySelector(".recipe-ingredient-link")
        if (!button || !link || !button.offsetParent) continue

        return {
          basketName: button.dataset.ingredientBasketName,
          displayName: link.textContent.trim(),
          label: button.textContent.trim()
        }
      }

      return null
    })
    if (!showActionTarget) throw new Error("No show-page ingredient basket action found.")
    if (showActionTarget.label !== "I have it") throw new Error(`Show-page ingredient action label mismatch: ${showActionTarget.label}.`)

    await page.locator(".recipe-ingredient-basket-button", { hasText: "I have it" }).first().click()
    await page.waitForFunction((name) => {
      const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="))
      if (!value) return false

      return JSON.parse(decodeURIComponent(value.split("=")[1])).selected.includes(name)
    }, showActionTarget.basketName)

    const showActionState = await page.locator(".recipe-ingredient-row").evaluateAll((rows, name) => {
      for (const row of rows) {
        const button = row.querySelector(".recipe-ingredient-basket-button")
        if (button?.dataset.ingredientBasketName !== name) continue

        return {
          buttonDisplay: getComputedStyle(button).display,
          matched: row.classList.contains("recipe-ingredient-row--matched")
        }
      }

      return null
    }, showActionTarget.basketName)
    const showActionBasket = await page.evaluate(() => {
      const value = document.cookie.split(";").map((item) => item.trim()).find((item) => item.startsWith("pennylunch.ingredients="))
      return JSON.parse(decodeURIComponent(value.split("=")[1]))
    })
    if (!showActionState?.matched) throw new Error("Show-page ingredient action did not mark the row as matched.")
    if (showActionState.buttonDisplay !== "none") throw new Error("Show-page ingredient action button is still visible after adding.")
    if (!showActionBasket.selected.includes(showActionTarget.basketName)) throw new Error("Show-page ingredient action did not update the basket cookie.")
    if (showActionBasket.enabled !== false) throw new Error("Show-page ingredient action changed the basket filter switch state.")

    console.log(JSON.stringify({
      baseUrl,
      title,
      indexMatchedIngredient,
      showMatchedIngredient,
      showActionAddedIngredient: showActionTarget.basketName,
      showMatchedRows: await page.locator(".recipe-ingredient-row--matched").count(),
      showMatchedMarkerOpacity,
      showUnmatchedMarkerOpacity,
      ingredientRows,
      fabCount,
      similarCards,
      columns,
      detailOverflow: showTimeTooltipState.detailOverflow,
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

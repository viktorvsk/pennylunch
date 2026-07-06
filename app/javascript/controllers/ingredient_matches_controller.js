import { Controller } from "@hotwired/stimulus"
import {
  ADD_BASKET_INGREDIENT_EVENT,
  BASKET_CHANGE_EVENT,
  normalizeIngredientName,
  RECIPES_UPDATED_EVENT,
  REMOVE_BASKET_INGREDIENT_EVENT,
  readBasket
} from "lib/recipe_filter_core"

const activeIngredientKeys = (basket) => {
  const container = document.querySelector("[data-controller~='auto-submit'] [data-auto-submit-target~='ingredients']")
  const keys = container
    ? Array.from(container.querySelectorAll("input[name='ingredients[]']"))
      .map((input) => normalizeIngredientName(input.value))
      .filter(Boolean)
    : []
  if (!basket.enabled) return keys

  return [...new Set([...keys, ...basket.selected.map(normalizeIngredientName)])]
}

const matchNamesFor = (entry) => {
  const names = [
    ...(Array.isArray(entry.matchNames) ? entry.matchNames : []),
    entry.matchName,
    entry.name
  ].map((name) => name?.toString().trim()).filter(Boolean)

  return [...new Set(names)]
}

const ingredientMatches = (entry, selectedKeys) => {
  return matchNamesFor(entry).some((name) => selectedKeys.includes(normalizeIngredientName(name)))
}

const matchingIngredientName = (entry, selectedKeys) => {
  return matchNamesFor(entry).find((name) => selectedKeys.includes(normalizeIngredientName(name))) || ""
}

const ingredientMatchRank = (entry, selectedKeys) => {
  const indexes = matchNamesFor(entry)
    .map((name) => selectedKeys.indexOf(normalizeIngredientName(name)))
    .filter((index) => index >= 0)

  return indexes.length > 0 ? Math.min(...indexes) : Number.POSITIVE_INFINITY
}

const recipeIngredientEntriesFor = (element) => {
  return JSON.parse(element.dataset.recipeIngredients).map((entry) => {
    const displayName = entry.name.toString().trim()
    const catalogName = entry.matchName ? entry.matchName.toString().trim() : ""
    return { name: displayName, matchName: catalogName || displayName }
  }).filter((entry) => entry.name)
}

const renderIngredientName = (name, matched) => {
  if (!matched) return document.createTextNode(name)

  const element = document.createElement("span")
  element.className = "recipe-ingredient-match"
  element.textContent = name
  return element
}

const renderRecipeIngredientSummary = (element, selectedKeys) => {
  const entries = recipeIngredientEntriesFor(element)
  const ordered = entries.slice().sort((left, right) => {
    const leftRank = ingredientMatchRank(left, selectedKeys)
    const rightRank = ingredientMatchRank(right, selectedKeys)
    if (leftRank !== rightRank) return leftRank - rightRank

    return entries.indexOf(left) - entries.indexOf(right)
  })
  const visibleEntries = ordered.slice(0, 8)
  const remainingCount = ordered.length - visibleEntries.length

  element.replaceChildren()
  visibleEntries.forEach((entry, index) => {
    if (index > 0) element.append(document.createTextNode(", "))
    element.append(renderIngredientName(entry.name, ingredientMatches(entry, selectedKeys)))
  })
  if (remainingCount > 0) element.append(document.createTextNode(` + ${remainingCount} more`))
}

const renderRecipeMatchReadiness = (element, selectedKeys) => {
  const requiredKeys = [
    ...new Set(JSON.parse(element.dataset.requiredIngredientNames).map(normalizeIngredientName).filter(Boolean))
  ]
  const selectedKeySet = new Set(selectedKeys)
  const matchedCount = requiredKeys.filter((key) => selectedKeySet.has(key)).length
  const requiredCount = requiredKeys.length
  const tooltip = `Matches ${matchedCount} of ${requiredCount} required ingredients in your selected ingredients. ` +
    "Pantry staples are not counted."
  element.querySelector("[data-readiness-label]").textContent = `${Math.round((matchedCount / requiredCount) * 100)}%`

  element.dataset.state = matchedCount === requiredCount ? "ready" : "partial"
  element.dataset.tooltip = tooltip
  element.setAttribute("aria-label", tooltip)

  if (element._tippy?.setContent) element._tippy.setContent(tooltip)
}

export default class extends Controller {
  static targets = ["summary", "name", "readiness"]

  connect() {
    this.refresh = this.refresh.bind(this)
    window.addEventListener(BASKET_CHANGE_EVENT, this.refresh)
    document.addEventListener(RECIPES_UPDATED_EVENT, this.refresh)
    this.refresh()
  }

  disconnect() {
    window.removeEventListener(BASKET_CHANGE_EVENT, this.refresh)
    document.removeEventListener(RECIPES_UPDATED_EVENT, this.refresh)
  }

  refresh() {
    const basket = readBasket()
    const activeKeys = activeIngredientKeys(basket)
    const basketKeys = basket.selected.map(normalizeIngredientName)
    const displayKeys = [...new Set([...activeKeys, ...basketKeys])]

    this.summaryTargets.forEach((element) => {
      renderRecipeIngredientSummary(element, displayKeys)
    })

    this.readinessTargets.forEach((element) => {
      renderRecipeMatchReadiness(element, displayKeys)
    })

    this.nameTargets.forEach((element) => {
      const row = element.closest("[data-recipe-ingredient-row]")
      const entry = {
        name: element.dataset.ingredientName || element.textContent,
        matchName: element.dataset.ingredientMatchName || element.dataset.ingredientName || element.textContent,
        matchNames: JSON.parse(element.dataset.ingredientMatchNames || "[]")
      }
      const matched = ingredientMatches(entry, row ? basketKeys : displayKeys)

      if (row) {
        row.classList.toggle("recipe-ingredient-row--matched", matched)
        this.syncBasketRemoveButton(row, matched ? matchingIngredientName(entry, basketKeys) : "")
        element.classList.remove("recipe-ingredient-match")
      } else {
        element.classList.toggle("recipe-ingredient-match", matched)
      }
    })
  }

  syncBasketRemoveButton(row, matchedName) {
    const button = row.querySelector("[data-ingredient-basket-remove]")
    if (!button) return

    const defaultName = button.dataset.ingredientBasketDefaultName.trim()
    const name = matchedName || defaultName
    button.dataset.ingredientBasketName = name
    button.disabled = !matchedName
    button.setAttribute("aria-label", name ? `Remove ${name} from basket` : "Remove ingredient from basket")
  }

  addToBasket(event) {
    event.preventDefault()

    const name = event.currentTarget.dataset.ingredientBasketName.trim()
    if (!name) return

    window.dispatchEvent(new CustomEvent(ADD_BASKET_INGREDIENT_EVENT, { detail: { name } }))
  }

  removeFromBasket(event) {
    event.preventDefault()

    const name = event.currentTarget.dataset.ingredientBasketName.trim()
    if (!name) return

    window.dispatchEvent(new CustomEvent(REMOVE_BASKET_INGREDIENT_EVENT, { detail: { name } }))
  }
}

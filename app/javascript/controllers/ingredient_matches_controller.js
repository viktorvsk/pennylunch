import { Controller } from "@hotwired/stimulus"
import {
  activeIngredientKeys,
  basketIngredientKeys,
  ADD_BASKET_INGREDIENT_EVENT,
  REMOVE_BASKET_INGREDIENT_EVENT,
  ingredientMatches,
  matchingIngredientName,
  renderRecipeMatchReadiness,
  renderRecipeIngredientSummary
} from "lib/ingredient_matches"

export default class extends Controller {
  static targets = ["summary", "name", "readiness"]

  connect() {
    this.refresh()
  }

  refresh() {
    const activeKeys = activeIngredientKeys()
    const basketKeys = basketIngredientKeys()
    const displayKeys = [...new Set([...activeKeys, ...basketKeys])]

    this.summaryTargets.forEach((element) => {
      renderRecipeIngredientSummary(element, displayKeys)
    })

    this.readinessTargets.forEach((element) => {
      renderRecipeMatchReadiness(element, displayKeys)
    })

    this.nameTargets.forEach((element) => {
      let matchNames = []

      try {
        matchNames = JSON.parse(element.dataset.ingredientMatchNames || "[]")
      } catch {
        matchNames = []
      }

      const row = element.closest("[data-recipe-ingredient-row]")
      const entry = {
        name: element.dataset.ingredientName || element.textContent,
        matchName: element.dataset.ingredientMatchName || element.dataset.ingredientName || element.textContent,
        matchNames
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

    const defaultName = button.dataset.ingredientBasketDefaultName?.trim() || ""
    const name = matchedName || defaultName
    button.dataset.ingredientBasketName = name
    button.disabled = !matchedName
    button.setAttribute("aria-label", name ? `Remove ${name} from basket` : "Remove ingredient from basket")
  }

  addToBasket(event) {
    event.preventDefault()

    const name = event.currentTarget.dataset.ingredientBasketName?.trim()
    if (!name) return

    window.dispatchEvent(new CustomEvent(ADD_BASKET_INGREDIENT_EVENT, { detail: { name } }))
  }

  removeFromBasket(event) {
    event.preventDefault()

    const name = event.currentTarget.dataset.ingredientBasketName?.trim()
    if (!name) return

    window.dispatchEvent(new CustomEvent(REMOVE_BASKET_INGREDIENT_EVENT, { detail: { name } }))
  }
}

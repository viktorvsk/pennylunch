import { Controller } from "@hotwired/stimulus"
import {
  activeIngredientKeys,
  ingredientMatches,
  renderRecipeIngredientSummary
} from "lib/ingredient_matches"

export default class extends Controller {
  static targets = ["summary", "name"]

  connect() {
    this.refresh()
  }

  refresh() {
    const selectedKeys = activeIngredientKeys()

    this.summaryTargets.forEach((element) => {
      renderRecipeIngredientSummary(element, selectedKeys)
    })

    this.nameTargets.forEach((element) => {
      let matchNames = []

      try {
        matchNames = JSON.parse(element.dataset.ingredientMatchNames || "[]")
      } catch {
        matchNames = []
      }

      const matched = ingredientMatches({ matchName: element.dataset.ingredientMatchName || element.dataset.ingredientName || element.textContent, matchNames }, selectedKeys)
      const row = element.closest("[data-recipe-ingredient-row]")

      if (row) {
        row.classList.toggle("recipe-ingredient-row--matched", matched)
        element.classList.remove("recipe-ingredient-match")
      } else {
        element.classList.toggle("recipe-ingredient-match", matched)
      }
    })
  }
}

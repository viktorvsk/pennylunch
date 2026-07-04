import {
  normalizeIngredientName,
  readBasket,
  splitIngredientText
} from "lib/recipe_filter_core"

export const DEFAULT_VISIBLE_INGREDIENT_LIMIT = 8

export const storedIngredientNames = () => {
  const basket = readBasket()
  if (!basket.enabled) return []

  return basket.selected.map((name) => name.toString().trim()).filter(Boolean)
}

export const activeIngredientNames = () => {
  const hidden = document.querySelector("[data-controller~='auto-submit'] [data-auto-submit-target~='ingredients']")
  if (hidden) return splitIngredientText(hidden.value || "")

  return storedIngredientNames()
}

export const activeIngredientKeys = () => activeIngredientNames().map(normalizeIngredientName)

export const matchNamesFor = (entry) => (Array.isArray(entry.matchNames) && entry.matchNames.length > 0 ? entry.matchNames : [entry.matchName])

export const ingredientMatches = (entry, selectedKeys) => {
  return matchNamesFor(entry).some((name) => selectedKeys.includes(normalizeIngredientName(name || "")))
}

export const ingredientMatchRank = (entry, selectedKeys) => {
  const indexes = matchNamesFor(entry)
    .map((name) => selectedKeys.indexOf(normalizeIngredientName(name || "")))
    .filter((index) => index >= 0)

  return indexes.length > 0 ? Math.min(...indexes) : Number.POSITIVE_INFINITY
}

export const recipeIngredientEntriesFor = (element) => {
  try {
    const parsed = JSON.parse(element.dataset.ingredientNames || "[]")
    const catalogNames = JSON.parse(element.dataset.ingredientCatalogNames || "[]")
    if (Array.isArray(parsed)) {
      return parsed.map((name, index) => {
        const displayName = name.toString().trim()
        const catalogName = Array.isArray(catalogNames) && catalogNames[index] ? catalogNames[index].toString().trim() : ""
        return { name: displayName, matchName: catalogName || displayName }
      }).filter((entry) => entry.name)
    }
  } catch {
  }

  return []
}

export const renderIngredientName = (name, matched) => {
  if (!matched) return document.createTextNode(name)

  const element = document.createElement("span")
  element.className = "recipe-ingredient-match"
  element.textContent = name
  return element
}

export const renderRecipeIngredientSummary = (element, selectedKeys) => {
  const entries = recipeIngredientEntriesFor(element)
  const limit = Number(element.dataset.visibleLimit || DEFAULT_VISIBLE_INGREDIENT_LIMIT)
  const ordered = entries.slice().sort((left, right) => {
    const leftRank = ingredientMatchRank(left, selectedKeys)
    const rightRank = ingredientMatchRank(right, selectedKeys)
    if (leftRank !== rightRank) return leftRank - rightRank

    return entries.indexOf(left) - entries.indexOf(right)
  })
  const visibleEntries = ordered.slice(0, limit)
  const remainingCount = ordered.length - visibleEntries.length

  element.replaceChildren()
  visibleEntries.forEach((entry, index) => {
    if (index > 0) element.append(document.createTextNode(", "))
    element.append(renderIngredientName(entry.name, ingredientMatches(entry, selectedKeys)))
  })
  if (remainingCount > 0) element.append(document.createTextNode(` + ${remainingCount} more`))
}

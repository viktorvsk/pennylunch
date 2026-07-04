import {
  ADD_BASKET_INGREDIENT_EVENT,
  REMOVE_BASKET_INGREDIENT_EVENT,
  normalizeIngredientName,
  readBasket,
  splitIngredientText
} from "lib/recipe_filter_core"

export { ADD_BASKET_INGREDIENT_EVENT, REMOVE_BASKET_INGREDIENT_EVENT }

export const DEFAULT_VISIBLE_INGREDIENT_LIMIT = 8

export const storedIngredientNames = () => {
  const basket = readBasket()
  if (!basket.enabled) return []

  return basket.selected.map((name) => name.toString().trim()).filter(Boolean)
}

export const activeIngredientNames = () => {
  const hidden = document.querySelector("[data-controller~='auto-submit'] [data-auto-submit-target~='ingredients']")
  const filterNames = hidden ? splitIngredientText(hidden.value || "") : []
  const basketNames = storedIngredientNames()
  if (!hidden) return basketNames

  const selectedKeys = new Set(filterNames.map(normalizeIngredientName))
  basketNames.forEach((name) => {
    const key = normalizeIngredientName(name)
    if (selectedKeys.has(key)) return

    selectedKeys.add(key)
    filterNames.push(name)
  })

  return filterNames
}

export const activeIngredientKeys = () => activeIngredientNames().map(normalizeIngredientName)

export const basketIngredientKeys = () => readBasket().selected.map(normalizeIngredientName)

export const matchNamesFor = (entry) => (Array.isArray(entry.matchNames) && entry.matchNames.length > 0 ? entry.matchNames : [entry.matchName])

export const ingredientMatches = (entry, selectedKeys) => {
  return matchNamesFor(entry).some((name) => selectedKeys.includes(normalizeIngredientName(name || "")))
}

export const matchingIngredientName = (entry, selectedKeys) => {
  return matchNamesFor(entry).find((name) => selectedKeys.includes(normalizeIngredientName(name || "")))?.toString().trim() || ""
}

export const ingredientMatchRank = (entry, selectedKeys) => {
  const indexes = matchNamesFor(entry)
    .map((name) => selectedKeys.indexOf(normalizeIngredientName(name || "")))
    .filter((index) => index >= 0)

  return indexes.length > 0 ? Math.min(...indexes) : Number.POSITIVE_INFINITY
}

export const recipeIngredientEntriesFor = (element) => {
  try {
    const parsed = JSON.parse(element.dataset.recipeIngredients || "[]")
    if (Array.isArray(parsed)) {
      return parsed.map((entry) => {
        const displayName = entry.name.toString().trim()
        const catalogName = entry.matchName ? entry.matchName.toString().trim() : ""
        return { name: displayName, matchName: catalogName || displayName }
      }).filter((entry) => entry.name)
    }
  } catch {
  }

  return []
}

export const requiredIngredientNamesFor = (element) => {
  try {
    const parsed = JSON.parse(element.dataset.requiredIngredientNames || "[]")
    return Array.isArray(parsed) ? parsed.map((name) => name.toString().trim()).filter(Boolean) : []
  } catch {
    return []
  }
}

export const recipeMatchReadinessFor = (requiredNames, selectedKeys) => {
  const requiredKeys = [...new Set(requiredNames.map(normalizeIngredientName).filter(Boolean))]
  const selectedKeySet = new Set(selectedKeys)
  const matchedCount = requiredKeys.filter((key) => selectedKeySet.has(key)).length
  const requiredCount = requiredKeys.length
  const percentage = requiredCount > 0 ? Math.round((matchedCount / requiredCount) * 100) : 0
  const ready = requiredCount > 0 && matchedCount === requiredCount

  return {
    matchedCount,
    requiredCount,
    percentage,
    ready,
    label: `${percentage}%`,
    tooltip: `Matches ${matchedCount} of ${requiredCount} required ingredients in your selected ingredients. Pantry staples are not counted.`
  }
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

export const renderRecipeMatchReadiness = (element, selectedKeys) => {
  const readiness = recipeMatchReadinessFor(requiredIngredientNamesFor(element), selectedKeys)
  const label = element.querySelector("[data-readiness-label]")

  if (label) label.textContent = readiness.label

  element.dataset.state = readiness.ready ? "ready" : "partial"
  element.dataset.tooltip = readiness.tooltip
  element.setAttribute("aria-label", readiness.tooltip)

  if (element._tippy?.setContent) element._tippy.setContent(readiness.tooltip)
}

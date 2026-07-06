const BASKET_COOKIE = "pennylunch.ingredients"
const BASKET_COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365
export const BASKET_CHANGE_EVENT = "pennylunch:ingredient-basket-change"
export const ADD_BASKET_INGREDIENT_EVENT = "pennylunch:add-basket-ingredient"
export const REMOVE_BASKET_INGREDIENT_EVENT = "pennylunch:remove-basket-ingredient"
export const RECIPES_UPDATED_EVENT = "recipes:updated"

export const normalizeIngredientName = (value) => value.toString().trim().replace(/\s+/g, " ").toLowerCase()

const normalizeBasketPayload = (payload = {}) => {
  const selected = []
  const selectedKeys = new Set()

  if (Array.isArray(payload.selected)) {
    payload.selected.forEach((value) => {
      const name = value?.toString().trim().replace(/\s+/g, " ")
      const key = name ? normalizeIngredientName(name) : ""
      if (!key || selectedKeys.has(key)) return

      selectedKeys.add(key)
      selected.push(name)
    })
  }

  return { enabled: payload.enabled === true, selected }
}

export const writeBasket = (basket) => {
  const normalized = normalizeBasketPayload(basket)
  document.cookie = `${BASKET_COOKIE}=${encodeURIComponent(JSON.stringify(normalized))}; Path=/; Max-Age=${BASKET_COOKIE_MAX_AGE_SECONDS}; SameSite=Lax`
  window.dispatchEvent(new CustomEvent(BASKET_CHANGE_EVENT, { detail: normalized }))

  return normalized
}

export const readBasket = () => {
  try {
    const prefix = `${BASKET_COOKIE}=`
    const entry = document.cookie.split(";").map((value) => value.trim()).find((value) => value.startsWith(prefix))

    return entry ? normalizeBasketPayload(JSON.parse(decodeURIComponent(entry.slice(prefix.length)))) : normalizeBasketPayload()
  } catch {
    return normalizeBasketPayload()
  }
}

const recipeCatalog = () => JSON.parse(document.querySelector("[data-recipe-catalog]").textContent)

export const recipeIngredientOptions = () => recipeCatalog().ingredientOptions

export const filterUrlFor = (form) => {
  const root = new URL(form.action, window.location.origin)
  const rootPath = root.pathname.replace(/\/$/, "")
  const formData = new FormData(form)
  const category = formData.get("category").toString().trim()
  const categorySlug = recipeCatalog().categorySlugs[category]
  const url = new URL(rootPath, window.location.origin)

  if (categorySlug) {
    url.pathname = `${rootPath}/${categorySlug}`
  }

  formData.forEach((value, key) => {
    const normalizedKey = key.endsWith("[]") ? key.slice(0, -2) : key
    if (normalizedKey === "category" || normalizedKey === "page") return
    if (!value || value.toString().trim() === "") return
    if (normalizedKey === "sort" && value === "best_match") return

    if (key.endsWith("[]")) {
      url.searchParams.append(key, value)
    } else {
      url.searchParams.set(key, value)
    }
  })

  return url.toString()
}

export const BASKET_COOKIE = "pennylunch.ingredients"
export const BASKET_CHANGE_EVENT = "pennylunch:ingredient-basket-change"
export const BASKET_COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 365
export const LEGACY_STORAGE_KEYS = {
  enabled: "pennylunch.ingredients.enabled",
  selected: "pennylunch.ingredients.selected",
  text: "pennylunch.ingredients.text"
}

export const present = (value) => value && value.toString().trim() !== ""

export const normalizeIngredientName = (value) => value.toString().trim().replace(/\s+/g, " ").toLowerCase()

export const splitIngredientText = (text) => text.split(/[\n,;]+/).map((name) => name.trim()).filter(Boolean)

export const readStorage = (key) => {
  try {
    return window.localStorage.getItem(key)
  } catch {
    return null
  }
}

export const writeStorage = (key, value) => {
  try {
    window.localStorage.setItem(key, value)
  } catch {
    return null
  }
}

export const readCookie = (name) => {
  try {
    const prefix = `${name}=`
    const entry = document.cookie.split(";").map((value) => value.trim()).find((value) => value.startsWith(prefix))

    return entry ? decodeURIComponent(entry.slice(prefix.length)) : null
  } catch {
    return null
  }
}

export const writeCookie = (name, value) => {
  document.cookie = `${name}=${encodeURIComponent(value)}; Path=/; Max-Age=${BASKET_COOKIE_MAX_AGE_SECONDS}; SameSite=Lax`
}

export const normalizeBasketPayload = (payload = {}) => {
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

  return { enabled: payload.enabled === true || payload.enabled === "true", selected }
}

export const readBasketCookie = () => {
  const value = readCookie(BASKET_COOKIE)
  if (!present(value)) return null

  try {
    return normalizeBasketPayload(JSON.parse(value))
  } catch {
    return null
  }
}

export const readLegacyBasket = () => {
  let selected = []

  try {
    const parsed = JSON.parse(readStorage(LEGACY_STORAGE_KEYS.selected) || "[]")
    if (Array.isArray(parsed)) selected = parsed
  } catch {
    selected = []
  }

  if (selected.length === 0) selected = splitIngredientText(readStorage(LEGACY_STORAGE_KEYS.text) || "")

  return normalizeBasketPayload({
    enabled: readStorage(LEGACY_STORAGE_KEYS.enabled) === "true",
    selected
  })
}

export const writeBasket = (basket) => {
  const normalized = normalizeBasketPayload(basket)
  writeCookie(BASKET_COOKIE, JSON.stringify(normalized))
  window.dispatchEvent(new CustomEvent(BASKET_CHANGE_EVENT, { detail: normalized }))

  return normalized
}

export const readBasket = () => {
  const cookieBasket = readBasketCookie()
  if (cookieBasket) return cookieBasket

  const legacyBasket = readLegacyBasket()
  if (legacyBasket.enabled || legacyBasket.selected.length > 0) writeBasket(legacyBasket)

  return legacyBasket
}

export const recipeUiCatalog = () => {
  const element = document.querySelector("[data-recipe-ui-catalog]")

  if (!element) return {}

  try {
    return JSON.parse(element.textContent || "{}")
  } catch {
    return {}
  }
}

export const categorySlugsFor = (form) => {
  const slugs = recipeUiCatalog().categorySlugs
  if (slugs && typeof slugs === "object") return slugs

  try {
    return JSON.parse(form.dataset.categorySlugs || "{}")
  } catch {
    return {}
  }
}

export const recipeIngredientOptions = () => {
  const options = recipeUiCatalog().ingredientOptions
  return Array.isArray(options) ? options : []
}

export const filterUrlFor = (form) => {
  const filterRoot = form.dataset.autoSubmitFilterRootValue || form.dataset.filterRoot || form.action
  const root = new URL(filterRoot, window.location.origin)
  const rootPath = root.pathname.replace(/\/$/, "")
  const formData = new FormData(form)
  const category = formData.get("category")?.toString().trim() || ""
  const categorySlug = categorySlugsFor(form)[category]
  const url = new URL(rootPath, window.location.origin)

  if (category && categorySlug) {
    url.pathname = `${rootPath}/${categorySlug}`
  }

  formData.forEach((value, key) => {
    if (key === "category" || key === "page") return
    if (!present(value)) return
    if (key === "sort" && value === "best_match") return

    url.searchParams.set(key, value)
  })

  return url.toString()
}

export const visit = (url) => {
  if (window.Turbo?.visit) {
    window.Turbo.visit(url)
  } else {
    window.location.assign(url)
  }
}

export const submitFilterForm = (form, { frame } = {}) => {
  if (!form) return

  const url = filterUrlFor(form)

  if (frame && window.Turbo?.visit) {
    window.Turbo.visit(url, { frame })
  } else {
    visit(url)
  }
}

export const initBasecoat = ({ force = false } = {}) => {
  if (!window.basecoat) return

  if (force && window.basecoat.stop && window.basecoat.start) {
    window.basecoat.stop()
    window.basecoat.start()
  }

  window.basecoat.initAll({ force })
}

export const setTurboLoading = (loading) => {
  document.documentElement.toggleAttribute("data-turbo-loading", loading)
}

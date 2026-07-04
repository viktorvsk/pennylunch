import { Controller } from "@hotwired/stimulus"
import {
  normalizeIngredientName,
  present,
  recipeIngredientOptions,
  readBasket,
  submitFilterForm,
  writeBasket
} from "lib/recipe_filter_core"

const FIRST_OPTION_INDEX = 0
const NO_OPTION_INDEX = -1
const MAX_OPTION_COUNT = 30
const OPTION_BLUR_DELAY_MS = 120
const SUBMIT_DELAY_MS = 250

export default class extends Controller {
  static targets = [
    "enabledControl",
    "enabledInput",
    "enabledText",
    "imageDialog",
    "imageDropzone",
    "imageError",
    "imageFile",
    "imageForm",
    "imageIdle",
    "imageStatus",
    "imageThinking",
    "imageTrigger",
    "imageUrl",
    "input",
    "modeText",
    "options",
    "panel",
    "selectedList",
    "status",
    "trigger"
  ]

  static values = {
    currentIngredients: Array
  }

  connect() {
    this.optionRecords = this.parseOptionRecords()
    this.optionNames = this.optionRecords.map((option) => option.name)
    this.optionByKey = new Map(this.optionRecords.map((option) => [normalizeIngredientName(option.name), option]))
    this.currentIngredients = Array.isArray(this.currentIngredientsValue) ? this.currentIngredientsValue : []
    this.selected = []
    this.initialized = false
    this.activeOptionIndex = NO_OPTION_INDEX
    this.imageLoading = false

    const storedBasket = readBasket()
    if (storedBasket.selected.length > 0) this.seedSelected(storedBasket.selected)
    if (this.currentIngredients.length > 0) this.seedSelected(this.currentIngredients)

    this.enabledInputTarget.checked = this.currentIngredients.length > 0 || storedBasket.enabled
    this.sync()
    this.initialized = true
    this.setOpen(false)
  }

  disconnect() {
    window.clearTimeout(this.timeoutId)
  }

  toggle() {
    this.setOpen(this.panelTarget.hidden)
  }

  search() {
    this.renderOptions()
  }

  keydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.setActiveOption(this.activeOptionIndex + 1)
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.setActiveOption(this.activeOptionIndex - 1)
      return
    }

    if (event.key === "Enter") {
      event.preventDefault()
      this.addIngredient(this.selectedOptionValue(), { submit: true })
    }
  }

  blur() {
    window.setTimeout(() => this.hideOptions(), OPTION_BLUR_DELAY_MS)
  }

  changeEnabled() {
    this.sync({ submit: this.selected.length > 0 })
  }

  escape(event) {
    if (event.key === "Escape") this.setOpen(false)
  }

  closeFromOutside(event) {
    if (this.element.contains(event.target)) return

    this.setOpen(false)
  }

  refreshPageContext() {
    this.sync()
  }

  addIngredientFromEvent(event) {
    this.addIngredient(event.detail?.name || "", { submit: true })
  }

  removeIngredientFromEvent(event) {
    this.removeIngredient(event.detail?.name || "")
  }

  openImageDialog() {
    this.hideOptions()
    this.imageFormTarget.reset()
    this.clearImageFeedback()
    this.setImageLoading(false)
    if (!this.imageDialogTarget.open) this.imageDialogTarget.showModal()
    this.imageDropzoneTarget.focus()
  }

  closeImageDialog() {
    if (this.imageLoading) return
    if (this.imageDialogTarget.open) this.imageDialogTarget.close()
    this.setImageLoading(false)
  }

  cancelImageDialog(event) {
    if (this.imageLoading) {
      event.preventDefault()
      return
    }

    this.setImageLoading(false)
  }

  closeImageDialogFromBackdrop(event) {
    if (event.target === this.imageDialogTarget) this.closeImageDialog()
  }

  chooseImageFile(event) {
    event.preventDefault()
    if (this.imageLoading) return

    this.imageFileTarget.click()
  }

  imageDropzoneKeydown(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.chooseImageFile(event)
  }

  selectImageFile() {
    if (this.imageLoading || this.imageFileTarget.files.length === 0) return

    this.imageUrlTarget.value = ""
    this.startImageRead({ file: this.imageFileTarget.files[0] })
  }

  dragImageFile(event) {
    event.preventDefault()
    if (this.imageLoading) return

    if (event.dataTransfer) event.dataTransfer.dropEffect = "copy"
    this.setImageDropzoneActive(true)
  }

  leaveImageFile(event) {
    event.preventDefault()
    if (event.currentTarget.contains(event.relatedTarget)) return

    this.setImageDropzoneActive(false)
  }

  dropImageFile(event) {
    event.preventDefault()
    this.setImageDropzoneActive(false)
    if (this.imageLoading) return

    const file = Array.from(event.dataTransfer?.files || []).find((candidate) => candidate.type.startsWith("image/"))
    if (!file) {
      this.setImageError("Drop a photo file.")
      return
    }

    this.imageFileTarget.value = ""
    this.imageUrlTarget.value = ""
    this.startImageRead({ file })
  }

  pasteImageUrl() {
    if (this.imageLoading) return

    window.setTimeout(() => {
      if (this.imageLoading) return

      const url = this.imageUrlTarget.value.trim()
      if (!present(url)) return

      this.imageFileTarget.value = ""
      this.startImageRead({ url })
    }, 0)
  }

  imageUrlKeydown(event) {
    if (event.key !== "Enter") return

    event.preventDefault()
    this.imageFileTarget.value = ""
    this.startImageRead()
  }

  submitImage(event) {
    event.preventDefault()
    this.startImageRead()
  }

  async startImageRead({ file = null, url = "" } = {}) {
    if (this.imageLoading) return

    const selectedFile = file || this.imageFileTarget.files[0] || null
    const selectedUrl = (url || this.imageUrlTarget.value).trim()
    const hasFile = selectedFile !== null
    const hasUrl = present(selectedUrl)

    if (!hasFile && !hasUrl) {
      this.setImageError("Choose a photo or paste an image URL.")
      return
    }

    if (hasFile && hasUrl) {
      this.setImageError("Choose a photo or paste an image URL, not both.")
      return
    }

    const formData = new FormData()
    if (hasFile) formData.set("image[file]", selectedFile, selectedFile.name)
    if (hasUrl) formData.set("image[url]", selectedUrl)

    this.setImageLoading(true)
    this.clearImageFeedback()

    try {
      const response = await fetch(this.imageFormTarget.action, {
        method: this.imageFormTarget.method.toUpperCase(),
        body: formData,
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        }
      })
      const payload = await response.json().catch(() => ({}))

      if (!response.ok) throw new Error(payload.error || "Pen could not read that image right now.")

      const addedCount = this.addIngredients(payload.ingredients || [], { submit: true })
      if (addedCount === 0) {
        this.setImageLoading(false)
        this.setImageError("No catalog ingredients were found in that image.")
        return
      }

      this.imageFormTarget.reset()
      this.setImageLoading(false)
      this.closeImageDialog()
      this.setOpen(true)
      this.setImageStatus(`Added ${addedCount} ${addedCount === 1 ? "ingredient" : "ingredients"}.`)
    } catch (error) {
      this.setImageLoading(false)
      this.setImageError(error.message || "Pen could not read that image right now.")
    }
  }

  parseOptionRecords() {
    const rawOptions = this.element.dataset.ingredientOptions || JSON.stringify(recipeIngredientOptions())

    try {
      return JSON.parse(rawOptions).map((option) => {
        if (typeof option === "string") return { name: option.trim(), optional: false }

        return { name: option.name?.toString().trim() || "", optional: option.optional === true }
      }).filter((option) => option.name !== "")
    } catch {
      return []
    }
  }

  optionFor(value) {
    return this.optionByKey.get(normalizeIngredientName(value))
  }

  canonicalName(value) {
    return this.optionFor(value)?.name
  }

  optionalIngredient(value) {
    return this.optionFor(value)?.optional === true
  }

  filterableSelected() {
    return this.selected.filter((name) => !this.optionalIngredient(name))
  }

  selectedForDisplay() {
    return [...this.selected].sort((left, right) => Number(this.optionalIngredient(left)) - Number(this.optionalIngredient(right)))
  }

  selectedKeys() {
    return new Set(this.selected.map(normalizeIngredientName))
  }

  optionRank(name, query) {
    const key = name.toLowerCase()
    const words = key.split(/\s+/)

    if (key === query) return 0
    if (key.startsWith(query)) return 1
    if (words.includes(query)) return 2
    if (words.some((word) => word.startsWith(query))) return 3
    if (key.includes(query)) return 4

    return null
  }

  seedSelected(values) {
    values.forEach((value) => {
      const name = this.canonicalName(value)
      if (name && !this.selectedKeys().has(normalizeIngredientName(name))) this.selected.push(name)
    })
  }

  setOpen(open) {
    this.panelTarget.hidden = !open
    this.triggerTarget.setAttribute("aria-expanded", open ? "true" : "false")
    this.element.dataset.open = open ? "true" : "false"

    if (open) {
      this.inputTarget.focus()
    } else {
      this.optionsTarget.hidden = true
      this.optionsTarget.innerHTML = ""
      this.inputTarget.setAttribute("aria-expanded", "false")
    }
  }

  availableOptions(query) {
    const selectedKeySet = this.selectedKeys()
    const normalizedQuery = query.trim().toLowerCase()

    return this.optionNames
      .filter((name) => !selectedKeySet.has(normalizeIngredientName(name)))
      .map((name) => [name, this.optionRank(name, normalizedQuery)])
      .filter(([, rank]) => rank !== null)
      .sort(([leftName, leftRank], [rightName, rightRank]) => {
        if (leftRank !== rightRank) return leftRank - rightRank
        if (leftName.length !== rightName.length) return leftName.length - rightName.length

        return leftName.localeCompare(rightName)
      })
      .map(([name]) => name)
      .slice(0, MAX_OPTION_COUNT)
  }

  hideOptions() {
    this.optionsTarget.hidden = true
    this.optionsTarget.innerHTML = ""
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.activeOptionIndex = NO_OPTION_INDEX
  }

  renderOptions() {
    const query = this.inputTarget.value.trim()

    this.optionsTarget.innerHTML = ""

    if (query === "") {
      this.hideOptions()
      return
    }

    const matches = this.availableOptions(query)
    this.activeOptionIndex = matches.length > 0 ? FIRST_OPTION_INDEX : NO_OPTION_INDEX

    if (matches.length === 0) {
      const empty = document.createElement("div")
      empty.className = "recipe-ingredients-option text-muted-foreground"
      empty.textContent = "No matching ingredient"
      empty.setAttribute("aria-disabled", "true")
      this.optionsTarget.append(empty)
    } else {
      matches.forEach((name, index) => {
        const option = document.createElement("button")
        option.type = "button"
        option.className = "recipe-ingredients-option w-full text-left"
        option.dataset.value = name
        option.dataset.optional = this.optionalIngredient(name) ? "true" : "false"
        option.dataset.active = index === this.activeOptionIndex ? "true" : "false"
        option.setAttribute("role", "option")
        option.setAttribute("aria-selected", index === this.activeOptionIndex ? "true" : "false")
        option.textContent = name
        option.addEventListener("mousedown", (event) => {
          event.preventDefault()
          this.addIngredient(name, { submit: true })
        })
        this.optionsTarget.append(option)
      })
    }

    this.optionsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  setActiveOption(nextIndex) {
    const options = Array.from(this.optionsTarget.querySelectorAll("[role='option']"))
    if (options.length === 0) return

    this.activeOptionIndex = (nextIndex + options.length) % options.length
    options.forEach((option, index) => {
      const active = index === this.activeOptionIndex
      option.dataset.active = active ? "true" : "false"
      option.setAttribute("aria-selected", active ? "true" : "false")
    })
  }

  selectedOptionValue() {
    const query = this.inputTarget.value.trim()
    if (query === "") return ""

    const active = this.optionsTarget.hidden ? null : this.optionsTarget.querySelector("[data-active='true']")
    if (active?.dataset.value) return active.dataset.value

    const exact = this.canonicalName(query)
    if (exact && !this.selectedKeys().has(normalizeIngredientName(exact))) return exact

    return this.availableOptions(query)[0] || ""
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  clearImageFeedback() {
    this.imageErrorTarget.textContent = ""
    this.imageErrorTarget.hidden = true
    this.imageStatusTarget.textContent = ""
    this.imageStatusTarget.hidden = true
  }

  setImageError(message) {
    this.imageStatusTarget.hidden = true
    this.imageStatusTarget.textContent = ""
    this.imageErrorTarget.textContent = message
    this.imageErrorTarget.hidden = false
  }

  setImageStatus(message) {
    this.imageErrorTarget.hidden = true
    this.imageErrorTarget.textContent = ""
    this.imageStatusTarget.textContent = message
    this.imageStatusTarget.hidden = false
  }

  setImageLoading(loading) {
    this.imageLoading = loading
    this.imageDialogTarget.dataset.state = loading ? "loading" : "idle"
    this.imageIdleTarget.hidden = loading
    this.imageThinkingTarget.hidden = !loading
    this.setImageDropzoneActive(false)
    this.imageFormTarget.querySelectorAll("input, button").forEach((control) => {
      control.disabled = loading
    })
  }

  setImageDropzoneActive(active) {
    this.imageDropzoneTarget.dataset.state = active ? "active" : "idle"
  }

  setStatus() {
    const hasSelected = this.selected.length > 0
    const enabled = this.enabledInputTarget.checked
    const state = enabled ? "enabled" : "disabled"

    this.triggerTarget.dataset.state = state
    this.enabledControlTarget.dataset.state = state
    this.enabledTextTarget.textContent = enabled ? "On" : "Off"
    this.modeTextTarget.textContent = enabled ? "only matching recipes are displayed." : "you see all recipes."

    if (enabled && this.filterableSelected().length > 0) {
      this.statusTarget.textContent = `Filtering with ${this.filterableSelected().length} selected`
    } else if (enabled) {
      this.statusTarget.textContent = "On, add matches"
    } else if (hasSelected) {
      this.statusTarget.textContent = `${this.selected.length} saved, off`
    } else {
      this.statusTarget.textContent = "Add what you have"
    }

    this.triggerTarget.setAttribute("aria-label", `Ingredients: ${this.statusTarget.textContent.toLowerCase()}`)
  }

  renderSelected() {
    this.selectedListTarget.innerHTML = ""

    this.selectedForDisplay().forEach((name) => {
      const row = document.createElement("div")
      row.className = "recipe-ingredients-row"
      row.dataset.optional = this.optionalIngredient(name) ? "true" : "false"

      const label = document.createElement("span")
      label.textContent = name

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "recipe-ingredients-remove"
      remove.setAttribute("aria-label", `Remove ${name}`)
      remove.addEventListener("click", () => this.removeIngredient(name))

      row.append(label, remove)
      this.selectedListTarget.append(row)
    })
  }

  sync({ submit = false, delay = 0 } = {}) {
    const enabled = this.enabledInputTarget.checked
    const filterableNames = this.selected.filter((name) => !this.optionalIngredient(name))

    this.syncFilterInputs(enabled ? filterableNames : [])
    writeBasket({ selected: this.selected, enabled })
    this.renderSelected()
    this.setStatus()

    if (!submit || !this.initialized || !this.currentForm()) return

    window.clearTimeout(this.timeoutId)
    this.timeoutId = window.setTimeout(() => submitFilterForm(this.currentForm(), { frame: "recipe-results-frame" }), delay)
  }

  addIngredient(value, { submit = false } = {}) {
    const name = this.canonicalName(value)
    if (!name || this.selectedKeys().has(normalizeIngredientName(name))) return false

    this.selected.push(name)
    this.inputTarget.value = ""
    this.hideOptions()
    this.sync({ submit: this.enabledInputTarget.checked && submit, delay: SUBMIT_DELAY_MS })
    return true
  }

  addIngredients(values, { submit = false } = {}) {
    let addedCount = 0
    const selectedKeys = this.selectedKeys()

    values.forEach((value) => {
      const name = this.canonicalName(value)
      const key = name ? normalizeIngredientName(name) : ""
      if (!name || selectedKeys.has(key)) return

      selectedKeys.add(key)
      this.selected.push(name)
      addedCount += 1
    })

    if (addedCount > 0) this.sync({ submit: this.enabledInputTarget.checked && submit, delay: SUBMIT_DELAY_MS })

    return addedCount
  }

  removeIngredient(value) {
    const key = normalizeIngredientName(value)
    const index = this.selected.findIndex((name) => normalizeIngredientName(name) === key)
    if (index === NO_OPTION_INDEX) return

    this.selected.splice(index, 1)
    this.renderOptions()
    this.sync({ submit: this.enabledInputTarget.checked, delay: SUBMIT_DELAY_MS })
  }

  currentForm() {
    return document.querySelector("form[data-controller~='auto-submit']")
  }

  currentIngredientsContainer() {
    return this.currentForm()?.querySelector("[data-auto-submit-target~='ingredients']")
  }

  syncFilterInputs(names) {
    const container = this.currentIngredientsContainer()
    if (!container) return

    container.replaceChildren(...names.map((name) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ingredients[]"
      input.value = name
      return input
    }))
  }
}

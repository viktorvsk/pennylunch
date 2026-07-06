import { Controller } from "@hotwired/stimulus"
import { RECIPES_UPDATED_EVENT } from "lib/recipe_filter_core"

const initBasecoat = (force = false) => {
  if (force) {
    window.basecoat.stop()
    window.basecoat.start()
  }

  window.basecoat.initAll({ force })
}

export default class extends Controller {
  connect() {
    this.recipesUpdated = this.recipesUpdated.bind(this)
    document.addEventListener(RECIPES_UPDATED_EVENT, this.recipesUpdated)
    initBasecoat()
    this.stopLoading()
  }

  disconnect() {
    document.removeEventListener(RECIPES_UPDATED_EVENT, this.recipesUpdated)
  }

  turboLoad() {
    initBasecoat(true)
    this.stopLoading()
  }

  turboRender() {
    initBasecoat(true)
  }

  recipesUpdated() {
    initBasecoat()
  }

  startLoading() {
    document.documentElement.toggleAttribute("data-turbo-loading", true)
  }

  stopLoading() {
    document.documentElement.toggleAttribute("data-turbo-loading", false)
  }
}

import { Controller } from "@hotwired/stimulus"
import { initBasecoat, setTurboLoading } from "lib/recipe_filter_core"

export default class extends Controller {
  connect() {
    this.init()
    this.stopLoading()
  }

  init() {
    initBasecoat()
  }

  forceInit() {
    initBasecoat({ force: true })
  }

  turboLoad() {
    this.forceInit()
    this.stopLoading()
  }

  turboRender() {
    this.forceInit()
  }

  turboFrameRender() {
    this.forceInit()
  }

  recipesUpdated() {
    this.init()
  }

  startLoading() {
    setTurboLoading(true)
  }

  stopLoading() {
    setTurboLoading(false)
  }
}

import { Controller } from "@hotwired/stimulus"
import { filterUrlFor, visit } from "lib/recipe_filter_core"

const DEFAULT_DEBOUNCE_MS = 300

export default class extends Controller {
  static targets = ["ingredients"]

  submit(event) {
    if (!this.filterRoot) return

    event.preventDefault()
    visit(filterUrlFor(this.element))
  }

  input(event) {
    if (!event.target.matches("[data-auto-submit-delay]")) return

    this.queue(Number(event.target.dataset.autoSubmitDelay || DEFAULT_DEBOUNCE_MS))
  }

  change(event) {
    if (!event.target.closest("[data-auto-submit-on-change]")) return

    this.queue(0)
  }

  disconnect() {
    window.clearTimeout(this.timeoutId)
  }

  queue(delay) {
    window.clearTimeout(this.timeoutId)
    this.timeoutId = window.setTimeout(() => {
      if (this.filterRoot) {
        visit(filterUrlFor(this.element))
      } else if (this.element.requestSubmit) {
        this.element.requestSubmit()
      } else {
        this.element.submit()
      }
    }, delay)
  }

  get filterRoot() {
    return this.element.dataset.autoSubmitFilterRootValue || this.element.dataset.filterRoot
  }
}

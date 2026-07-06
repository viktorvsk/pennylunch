import { Controller } from "@hotwired/stimulus"
import { filterUrlFor } from "lib/recipe_filter_core"

export default class extends Controller {
  submit(event) {
    event.preventDefault()
    window.Turbo.visit(filterUrlFor(this.element))
  }

  input(event) {
    if (!event.target.matches("[data-auto-submit-delay]")) return

    this.queue(Number(event.target.dataset.autoSubmitDelay || 300))
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
      window.Turbo.visit(filterUrlFor(this.element))
    }, delay)
  }
}

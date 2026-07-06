import { Controller } from "@hotwired/stimulus"
import { RECIPES_UPDATED_EVENT } from "lib/recipe_filter_core"

const NEAR_VIEWPORT_MARGIN_PX = 600

export default class extends Controller {
  static targets = ["status"]
  static values = {
    nextUrl: String
  }

  connect() {
    this.loading = false

    if (!this.nextUrlValue) {
      this.element.remove()
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.appendNextPage()
    }, { rootMargin: `${NEAR_VIEWPORT_MARGIN_PX}px 0px` })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async appendNextPage() {
    if (this.loading) return

    const nextUrl = this.nextUrlValue
    if (!nextUrl) {
      this.element.remove()
      return
    }

    this.loading = true

    try {
      const response = await fetch(nextUrl, {
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const html = await response.text()
      const documentFragment = new DOMParser().parseFromString(html, "text/html")
      const nextResults = documentFragment.querySelector("#recipe-results")
      const currentResults = document.querySelector("#recipe-results")
      const nextSentinel = documentFragment.querySelector("[data-controller~='infinite-scroll']")

      if (!nextResults || !currentResults) {
        this.element.remove()
        return
      }

      Array.from(nextResults.children).forEach((child) => currentResults.appendChild(child))
      document.dispatchEvent(new CustomEvent(RECIPES_UPDATED_EVENT))

      const nextSentinelUrl = nextSentinel?.dataset.infiniteScrollNextUrlValue
      if (nextSentinelUrl) {
        this.nextUrlValue = nextSentinelUrl
        this.loading = false
        if (this.element.getBoundingClientRect().top < window.innerHeight + NEAR_VIEWPORT_MARGIN_PX) this.appendNextPage()
      } else {
        this.element.remove()
      }
    } catch {
      this.loading = false
      this.statusTarget.textContent = "Scroll to retry loading more recipes."
    }
  }
}

import { Controller } from "@hotwired/stimulus"

const NEAR_VIEWPORT_MARGIN_PX = 600

export default class extends Controller {
  static targets = ["status"]
  static values = {
    nextUrl: String
  }

  connect() {
    this.loading = false

    if (!this.hasNextUrlValue || this.nextUrlValue === "") {
      this.element.remove()
      return
    }

    if (!("IntersectionObserver" in window)) {
      this.appendNextPage()
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) this.appendNextPage()
      })
    }, { rootMargin: `${NEAR_VIEWPORT_MARGIN_PX}px 0px` })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
    this.loading = false
  }

  nearViewport() {
    const rect = this.element.getBoundingClientRect()
    return rect.top < window.innerHeight + NEAR_VIEWPORT_MARGIN_PX
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

      currentResults.append(...Array.from(nextResults.children))
      document.dispatchEvent(new CustomEvent("recipes:updated"))
      window.basecoat?.initAll()

      const nextSentinelUrl = nextSentinel?.dataset.infiniteScrollNextUrlValue
      if (nextSentinelUrl) {
        this.nextUrlValue = nextSentinelUrl
        this.loading = false
        if (this.nearViewport()) this.appendNextPage()
      } else {
        this.element.remove()
      }
    } catch {
      this.loading = false
      if (this.hasStatusTarget) this.statusTarget.textContent = "Scroll to retry loading more recipes."
    }
  }
}

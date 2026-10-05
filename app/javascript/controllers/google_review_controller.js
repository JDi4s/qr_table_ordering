import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { establishment: Number }

  connect() {
    this.dismissedOn = null
    this.onDismiss = (event) => {
      if (event.detail === this.establishmentValue) {
        this.dismissedOn = this.today
        this.updateVisibility()
      }
    }
    this.onRefresh = () => { this.readDismissal(); this.updateVisibility() }
    this.onStorage = (event) => {
      if (event.key === this.storageKey || event.key === null) this.onRefresh()
    }
    window.addEventListener("mesa:review-dismissed", this.onDismiss)
    window.addEventListener("storage", this.onStorage)
    document.addEventListener("visibilitychange", this.onRefresh)
    this.readDismissal()
    this.orders = document.getElementById("my_orders")
    this.observer = new MutationObserver(() => this.updateVisibility())
    if (this.orders) this.observer.observe(this.orders, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-google-review-eligible"] })
    this.dayTimer = window.setInterval(this.onRefresh, 60_000)
    this.updateVisibility()
  }

  disconnect() {
    window.removeEventListener("mesa:review-dismissed", this.onDismiss)
    window.removeEventListener("storage", this.onStorage)
    document.removeEventListener("visibilitychange", this.onRefresh)
    window.clearInterval(this.dayTimer)
    this.observer?.disconnect()
  }

  readDismissal() {
    try {
      const saved = localStorage.getItem(this.storageKey)
      // Old permanent dismissals have no date: keep them hidden only for today.
      this.dismissedOn = saved === "1" ? this.today : saved
      if (saved === "1") localStorage.setItem(this.storageKey, this.dismissedOn)
    } catch (_) { /* Keep the in-memory dismissal when storage is blocked. */ }
  }

  dismiss() {
    this.dismissedOn = this.today
    try { localStorage.setItem(this.storageKey, this.dismissedOn) } catch (_) {}
    this.updateVisibility()
    window.dispatchEvent(new CustomEvent("mesa:review-dismissed", { detail: this.establishmentValue }))
  }

  updateVisibility() {
    const eligible = !this.orders || Boolean(this.orders.querySelector('[data-google-review-eligible="true"]'))
    this.element.hidden = this.dismissedOn === this.today || !eligible
  }

  get today() {
    return new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Lisbon", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date())
  }

  get storageKey() {
    return `mesa:google-review-tab-v2-dismissed:${this.establishmentValue}`
  }
}

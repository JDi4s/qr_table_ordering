import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { establishment: Number }

  connect() {
    this.onDismiss = (event) => {
      if (event.detail === this.establishmentValue) { this.dismissed = true; this.updateVisibility() }
    }
    window.addEventListener("mesa:review-dismissed", this.onDismiss)
    try {
      this.dismissed = localStorage.getItem(this.storageKey) === "1"
    } catch (_) { /* The invitation remains usable if storage is blocked. */ }
    this.orders = document.getElementById("my_orders")
    this.observer = new MutationObserver(() => this.updateVisibility())
    if (this.orders) this.observer.observe(this.orders, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-google-review-eligible"] })
    this.updateVisibility()
  }

  disconnect() {
    window.removeEventListener("mesa:review-dismissed", this.onDismiss)
    this.observer?.disconnect()
  }

  dismiss() {
    this.dismissed = true
    this.updateVisibility()
    try { localStorage.setItem(this.storageKey, "1") } catch (_) {}
    window.dispatchEvent(new CustomEvent("mesa:review-dismissed", { detail: this.establishmentValue }))
  }

  updateVisibility() {
    const eligible = !this.orders || Boolean(this.orders.querySelector('[data-google-review-eligible="true"]'))
    this.element.hidden = Boolean(this.dismissed) || !eligible
  }

  get storageKey() {
    return `mesa:google-review-dismissed:${this.establishmentValue}`
  }
}

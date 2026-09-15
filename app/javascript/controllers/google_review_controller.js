import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { establishment: Number }

  connect() {
    this.onDismiss = (event) => {
      if (event.detail === this.establishmentValue) this.element.hidden = true
    }
    window.addEventListener("mesa:review-dismissed", this.onDismiss)
    try {
      this.element.hidden = localStorage.getItem(this.storageKey) === "1"
    } catch (_) { /* The invitation remains usable if storage is blocked. */ }
  }

  disconnect() {
    window.removeEventListener("mesa:review-dismissed", this.onDismiss)
  }

  dismiss() {
    this.element.hidden = true
    try { localStorage.setItem(this.storageKey, "1") } catch (_) {}
    window.dispatchEvent(new CustomEvent("mesa:review-dismissed", { detail: this.establishmentValue }))
  }

  get storageKey() {
    return `mesa:google-review-dismissed:${this.establishmentValue}`
  }
}

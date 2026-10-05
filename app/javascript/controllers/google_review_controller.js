import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { establishment: Number }
  static targets = ["launcher", "panel", "openButton"]

  connect() {
    this.expanded = false
    this.onKeydown = (event) => { if (event.key === "Escape" && this.expanded) this.close() }
    this.element.addEventListener("keydown", this.onKeydown)
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
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  open() {
    this.expanded = true
    this.updateVisibility()
    this.panelTarget.querySelector("a")?.focus({ preventScroll: true })
  }

  close() {
    this.expanded = false
    this.updateVisibility()
    this.openButtonTarget.focus({ preventScroll: true })
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
    this.launcherTarget.hidden = Boolean(this.expanded)
    this.panelTarget.hidden = !this.expanded
    this.openButtonTarget.setAttribute("aria-expanded", String(Boolean(this.expanded)))
  }

  get storageKey() {
    return `mesa:google-review-dismissed:${this.establishmentValue}`
  }
}

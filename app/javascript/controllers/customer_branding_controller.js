import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "entry", "content"]
  static values = { enabled: Boolean, key: String }

  connect() {
    if (!this.enabledValue || this.wasAlreadySeen()) return

    this.contentTarget.hidden = true
    this.loadingTarget.hidden = false
    this.entryTimer = window.setTimeout(() => this.showEntry(), 650)
  }

  disconnect() {
    if (this.entryTimer) window.clearTimeout(this.entryTimer)
  }

  showEntry() {
    this.loadingTarget.hidden = true
    this.entryTarget.hidden = false
  }

  enter() {
    this.rememberVisit()
    this.entryTarget.hidden = true
    this.contentTarget.hidden = false
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  wasAlreadySeen() {
    try {
      return window.sessionStorage.getItem(this.storageKey()) === "1"
    } catch (_error) {
      return false
    }
  }

  rememberVisit() {
    try {
      window.sessionStorage.setItem(this.storageKey(), "1")
    } catch (_error) {
      // Private browsing can disable sessionStorage; the flow still works.
    }
  }

  storageKey() {
    return `mesa-branding-seen:${this.keyValue}`
  }
}

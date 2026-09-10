import { Controller } from "@hotwired/stimulus"

const DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000

export default class extends Controller {
  static values = {
    key: { type: String, default: "dismissible-help" },
    duration: { type: Number, default: DAY_IN_MILLISECONDS }
  }

  connect() {
    this.showAgainAt = Number(window.localStorage.getItem(this.keyValue) || 0)

    if (this.showAgainAt > Date.now()) {
      this.hide()
      this.timer = window.setTimeout(() => this.show(), this.showAgainAt - Date.now())
    } else {
      window.localStorage.removeItem(this.keyValue)
    }
  }

  disconnect() {
    if (this.timer) window.clearTimeout(this.timer)
  }

  close() {
    this.showAgainAt = Date.now() + this.durationValue
    window.localStorage.setItem(this.keyValue, String(this.showAgainAt))
    this.hide()
  }

  hide() {
    this.element.hidden = true
  }

  show() {
    window.localStorage.removeItem(this.keyValue)
    this.element.hidden = false
  }
}

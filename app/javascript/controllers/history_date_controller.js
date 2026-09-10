import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "display"]

  connect() {
    this.update()
    this.element.classList.add("is-enhanced")
  }

  update() {
    const value = this.inputTarget.value
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value)
    this.displayTarget.textContent = match
      ? `${match[3]}-${match[2]}-${match[1]} ${match[4]}:${match[5]}`
      : "dd-mm-aaaa hh:mm"
    this.displayTarget.classList.toggle("is-empty", !match)
  }
}

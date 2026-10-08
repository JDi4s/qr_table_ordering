import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enabled", "fields", "basis", "portion"]

  connect() {
    this.update()
    this.revealInvalidField = event => {
      const section = event.target.closest("details")
      if (section) section.open = true
    }
    this.element.addEventListener("invalid", this.revealInvalidField, true)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.revealInvalidField, true)
  }

  update() {
    this.fieldsTarget.hidden = !this.enabledTarget.checked
    const portion = this.enabledTarget.checked && this.basisTarget.value === "portion"
    this.portionTarget.hidden = !portion
    this.portionTarget.querySelector("input").required = portion
  }
}

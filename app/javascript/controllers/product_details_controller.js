import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enabled", "fields", "basis", "portion"]

  connect() { this.update() }

  update() {
    this.fieldsTarget.hidden = !this.enabledTarget.checked
    const portion = this.enabledTarget.checked && this.basisTarget.value === "portion"
    this.portionTarget.hidden = !portion
    this.portionTarget.querySelector("input").required = portion
  }
}

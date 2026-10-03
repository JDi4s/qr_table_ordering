import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "nav"]

  toggle() {
    const open = this.element.classList.toggle("is-menu-open")
    this.toggleTarget.setAttribute("aria-expanded", String(open))
    this.toggleTarget.setAttribute("aria-label", open ? "Fechar menu" : "Abrir menu")
  }

  close() {
    this.element.classList.remove("is-menu-open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.toggleTarget.setAttribute("aria-label", "Abrir menu")
  }
}

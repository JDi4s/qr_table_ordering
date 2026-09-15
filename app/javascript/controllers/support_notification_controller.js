import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Keep the newest alerts without an unbounded stack on long-running tabs.
    const container = this.element.parentElement
    while (container.children.length > 5) container.firstElementChild.remove()
  }

  dismiss() {
    this.element.remove()
  }
}

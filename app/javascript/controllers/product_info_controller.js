import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dialog = document.createElement("dialog")
    this.dialog.className = "product-info-dialog"
    this.dialog.setAttribute("aria-labelledby", "product-info-heading")
    this.dialog.addEventListener("click", event => {
      if (event.target.closest("[data-product-info-close]")) this.dialog.close()
    })
    this.dialog.addEventListener("close", () => {
      document.body.classList.remove("product-info-open")
      if (this.opener?.isConnected) this.opener.focus()
      this.dialog.replaceChildren()
    })
    document.body.append(this.dialog)
  }

  disconnect() {
    this.dialog.close()
    this.dialog.remove()
    document.body.classList.remove("product-info-open")
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    const template = event.currentTarget.closest(".customer-product-card").querySelector(".product-information-template")
    if (!template) return
    this.opener = event.currentTarget
    this.dialog.replaceChildren(template.content.cloneNode(true))
    this.dialog.showModal()
    document.body.classList.add("product-info-open")
  }
}

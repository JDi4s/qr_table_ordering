import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "image", "imagePlaceholder", "name", "description", "price"]

  connect() {
    this.boundKeydown = (event) => {
      if (event.key === "Escape" && !this.modalTarget.hidden) this.close()
    }
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open(event) {
    event.preventDefault()
    this.updatePreview()
    this.modalTarget.hidden = false
    document.body.classList.add("menu-item-preview-open")
  }

  close(event) {
    event?.preventDefault()
    this.modalTarget.hidden = true
    document.body.classList.remove("menu-item-preview-open")
  }

  updatePreview() {
    const name = this.fieldValue("name") || "Nome do produto"
    const description = this.fieldValue("description")
    const price = Number.parseFloat(this.fieldValue("price").replace(",", "."))
    const cropImage = this.element.querySelector("[data-image-preview-target='image']")
    const existingImage = this.element.querySelector("[data-image-preview-target='preview'] img")
    const source = cropImage?.getAttribute("src") || existingImage?.getAttribute("src")

    this.nameTarget.textContent = name
    this.descriptionTarget.textContent = description
    this.descriptionTarget.hidden = description.length === 0
    this.priceTarget.textContent = Number.isFinite(price)
      ? `${price.toLocaleString("pt-PT", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`
      : "0,00 €"

    if (source) {
      this.imageTarget.src = source
      this.imageTarget.hidden = false
      this.imagePlaceholderTarget.hidden = true
    } else {
      this.imageTarget.removeAttribute("src")
      this.imageTarget.hidden = true
      this.imagePlaceholderTarget.hidden = false
    }
  }

  fieldValue(name) {
    return this.element.querySelector(`[name='menu_item[${name}]']`)?.value?.trim() || ""
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "selectedCount", "selectedTotal", "submit"]

  connect() {
    this.updateSummary()
  }

  toggle(event) {
    const item = event.currentTarget.closest("[data-payment-selection-target='item']")
    const maximum = Number(item.dataset.maxQuantity || 0)
    const current = Number(item.dataset.selectedQuantity || 0)
    const next = current >= maximum ? 0 : current + 1

    item.dataset.selectedQuantity = String(next)
    item.querySelector("input[type='hidden']").value = String(next)
    item.querySelector("[data-selection-count]").textContent = `${next}/${maximum}`
    event.currentTarget.setAttribute("aria-pressed", String(next > 0))
    item.classList.toggle("is-selected", next > 0)
    this.updateSummary()
  }

  updateSummary() {
    let selectedQuantity = 0
    let selectedTotal = 0

    this.itemTargets.forEach((item) => {
      const quantity = Number(item.dataset.selectedQuantity || 0)
      const unitPrice = Number(item.dataset.unitPrice || 0)
      selectedQuantity += quantity
      selectedTotal += quantity * unitPrice
    })

    this.selectedCountTarget.textContent = `${selectedQuantity} ${selectedQuantity === 1 ? "artigo selecionado" : "artigos selecionados"}`
    this.selectedTotalTarget.textContent = new Intl.NumberFormat("pt-PT", {
      style: "currency",
      currency: "EUR"
    }).format(selectedTotal)
    this.submitTarget.disabled = selectedQuantity === 0
  }
}

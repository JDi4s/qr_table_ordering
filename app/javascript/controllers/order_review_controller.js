import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suggestion", "total"]
  static values = { baseTotal: Number }

  connect() {
    this.updateTotal()
  }

  updateTotal() {
    const total = this.suggestionTargets.reduce((sum, row) => {
      const checkbox = row.querySelector("input[type='checkbox']")
      return checkbox.checked ? sum + Number(row.dataset.price || 0) : sum
    }, this.baseTotalValue)

    this.totalTarget.textContent = `${total.toFixed(2).replace('.', ',')} €`
  }
}

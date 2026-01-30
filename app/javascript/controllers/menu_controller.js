// app/javascript/controllers/menu_controller.js  (FULL FILE — create)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "qty", "checkbox", "count", "total", "submit"]

  connect() {
    this.syncAll()
  }

  toggleRow(event) {
    const cb = event.target
    const row = cb.closest("[data-menu-target='row']")
    const qty = row.querySelector("[data-menu-target='qty']")
    qty.disabled = !cb.checked
    if (!cb.checked) qty.value = 1
    this.updateSummary()
  }

  updateSummary() {
    let count = 0
    let total = 0

    this.rowTargets.forEach((row) => {
      const cb = row.querySelector("[data-menu-target='checkbox']")
      const qty = row.querySelector("[data-menu-target='qty']")
      const price = parseFloat(row.dataset.price || "0")

      if (cb.checked) {
        const q = parseInt(qty.value || "1", 10)
        count += q
        total += price * q
      }
    })

    this.countTarget.textContent = String(count)
    this.totalTarget.textContent = total.toFixed(2)
    this.submitTarget.disabled = count === 0
  }

  syncAll() {
    this.rowTargets.forEach((row) => {
      const cb = row.querySelector("[data-menu-target='checkbox']")
      const qty = row.querySelector("[data-menu-target='qty']")
      qty.disabled = !cb.checked
    })
    this.updateSummary()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summary"]

  connect() {
    this.orders = this.element.querySelector("#my_orders")
    if (!this.orders) return
    this.observer = new MutationObserver(() => this.updateSummary())
    this.observer.observe(this.orders, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-visit-outstanding"] })
    this.updateSummary()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return
    const orders = [...this.orders.querySelectorAll("[data-visit-order]")]
    const outstanding = orders.reduce((total, order) => total + Number(order.dataset.visitOutstanding || 0), 0)
    const amount = new Intl.NumberFormat("pt-PT", { style: "currency", currency: "EUR" }).format(outstanding)
    this.summaryTarget.textContent = `${orders.length} ${orders.length === 1 ? "pedido" : "pedidos"} · ${amount} por pagar`
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "count", "total", "empty"]

  connect() {
    this.update()
  }

  cardTargetConnected() {
    this.update()
  }

  cardTargetDisconnected() {
    queueMicrotask(() => this.update())
  }

  filter() {
    this.update()
  }

  update() {
    if (!this.hasInputTarget || !this.hasEmptyTarget) return

    const query = this.inputTarget.value.trim()
    let visible = 0
    let cents = 0

    this.cardTargets.forEach((card) => {
      card.hidden = query !== "" && !card.dataset.number.startsWith(query)
      if (!card.hidden) visible += 1
      cents += Number(card.dataset.amountCents || 0)
    })

    this.countTarget.textContent = this.cardTargets.length
    this.totalTarget.textContent = new Intl.NumberFormat("pt-PT", { style: "currency", currency: "EUR" }).format(cents / 100)
    this.emptyTarget.textContent = this.cardTargets.length ? "Não há mesas com esse número." : "Não há mesas com consumo em aberto."
    this.emptyTarget.hidden = visible !== 0
  }
}

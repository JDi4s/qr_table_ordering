import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "card", "empty"]

  filter() {
    const query = this.queryTarget.value.trim()
    let matches = 0

    this.cardTargets.forEach((card) => {
      card.hidden = query !== "" && !card.dataset.number.startsWith(query)
      if (!card.hidden) matches += 1
    })

    this.emptyTarget.textContent = this.cardTargets.length ? "Não há mesas com esse número." : "Ainda não existem mesas."
    this.emptyTarget.hidden = matches !== 0
  }
}

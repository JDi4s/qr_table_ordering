import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suggestion", "total"]
  static values = { baseTotal: Number }

  connect() {
    this.updateTotal()
  }

  toggleSuggestion(event) {
    if (event.type === 'keydown' && !['Enter', ' '].includes(event.key)) return
    if (event.target.closest('button, input, a')) return
    if (event.type === 'keydown') event.preventDefault()

    const card = event.currentTarget.closest('.suggestion-card')
    this.setSuggestionQuantity(card, this.suggestionQuantity(card) + 1)
  }

  removeSuggestion(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest('.suggestion-card')
    this.setSuggestionQuantity(card, this.suggestionQuantity(card) - 1)
  }

  increaseSuggestion(event) {
    const card = event.currentTarget.closest('.suggestion-card')
    this.setSuggestionQuantity(card, this.suggestionQuantity(card) + 1)
  }

  decreaseSuggestion(event) {
    const card = event.currentTarget.closest('.suggestion-card')
    this.setSuggestionQuantity(card, this.suggestionQuantity(card) - 1)
  }

  setSuggestionQuantity(card, quantity) {
    if (!card) return

    const nextQuantity = Math.max(0, Math.min(99, quantity))
    const input = card.querySelector('.suggestion-quantity-input')
    const value = card.querySelector('.suggestion-quantity-value')
    const action = card.querySelector('.suggestion-card-action')
    const removeButton = card.querySelector('.suggestion-remove-button')
    if (!input || !value || !action || !removeButton) return
    input.value = String(nextQuantity)
    value.textContent = String(nextQuantity)
    value.hidden = nextQuantity === 0
    action.hidden = nextQuantity > 0
    removeButton.hidden = nextQuantity === 0
    card.classList.toggle('is-added', nextQuantity > 0)
    card.setAttribute('aria-label', nextQuantity > 0 ? `Aumentar quantidade de ${this.cardName(card)}` : `Adicionar ${this.cardName(card)}`)
    this.updateTotal()
  }

  cardName(card) {
    return card.querySelector('.suggestion-name')?.textContent?.trim() || 'produto'
  }

  suggestionQuantity(card) {
    return Number.parseInt(card?.querySelector('.suggestion-quantity-input')?.value || '0', 10) || 0
  }

  updateTotal() {
    const total = this.suggestionTargets.reduce((sum, row) => {
      return sum + this.suggestionQuantity(row) * Number(row.dataset.price || 0)
    }, this.baseTotalValue)

    this.totalTarget.textContent = `${total.toFixed(2).replace('.', ',')} €`
  }
}

import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["dialog", "input", "selected", "price", "error"]

  connect() {
    if (!this.hasInputTarget) return
    try { this.combos = JSON.parse(this.inputTarget.value) } catch { this.combos = [] }
    const before = this.combos.length
    this.combos = this.combos.slice(0, 10).filter(combo => this.validate(combo))
    this.render()
    if (before !== this.combos.length) this.dispatch("changed", { detail: { removed: true } })
  }
  disconnect() { if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close() }
  open() { this.errorTarget.hidden = true; this.price(); this.dialogTarget.showModal() }
  close() { this.dialogTarget.close() }
  price() {
    let cents = Number(this.dialogTarget.dataset.baseCents)
    this.dialogTarget.querySelectorAll('input:checked').forEach(input => { cents += Number(input.dataset.supplement) })
    this.priceTarget.textContent = this.money(cents)
  }
  add() {
    if (this.combos.length >= 10) {
      this.errorTarget.textContent = 'Podes adicionar até 10 combinações. Usa + para repetir um menu.'
      this.errorTarget.hidden = false
      return
    }
    const choices = {}
    this.dialogTarget.querySelectorAll('[data-group]').forEach(group => {
      choices[group.dataset.group] = group.querySelector('input:checked')?.value || ''
    })
    const combo = { quantity: 1, choices }
    if (!this.validate(combo)) return
    this.combos.push(combo)
    this.close()
    this.render()
  }
  change(event) {
    const index = Number(event.currentTarget.dataset.index), delta = Number(event.currentTarget.dataset.delta)
    this.combos[index].quantity = Math.min(99, this.combos[index].quantity + delta)
    if (this.combos[index].quantity <= 0 || delta === 0) this.combos.splice(index, 1)
    this.render()
  }
  validate(combo) {
    if (!combo || typeof combo.choices !== 'object' || !combo.choices) return false
    const quantity = Number(combo.quantity)
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 99) return false
    combo.quantity = quantity
    let cents = Number(this.dialogTarget.dataset.baseCents), labels = []
    for (const group of this.dialogTarget.querySelectorAll('[data-group]')) {
      const id = String(combo.choices[group.dataset.group] ?? '')
      const input = Array.from(group.querySelectorAll('input')).find(input => input.value === id)
      if (!input) return false
      cents += Number(input.dataset.supplement)
      labels.push(input.dataset.name)
    }
    combo.priceCents = cents
    combo.labels = labels
    return true
  }
  render() {
    this.inputTarget.value = JSON.stringify(this.combos)
    this.selectedTarget.replaceChildren()
    this.combos.forEach((combo, index) => {
      const row = document.createElement('div'); row.className = 'panel lunch-selected-row'
      const copy = document.createElement('div'), title = document.createElement('strong'), details = document.createElement('p')
      title.textContent = `Menu completo · ${this.money(combo.priceCents)}`
      details.textContent = combo.labels.join(' · ')
      copy.append(title, details)
      const controls = document.createElement('div'); controls.className = 'lunch-combo-controls'
      for (const [text, delta, label] of [['−', -1, 'Remover um menu'], [String(combo.quantity), null, ''], ['+', 1, 'Adicionar um menu'], ['×', 0, 'Retirar esta combinação']]) {
        const control = document.createElement(delta === null ? 'strong' : 'button')
        control.textContent = text
        if (delta !== null) {
          control.type = 'button'; control.dataset.action = 'lunch-menu#change'; control.dataset.index = index; control.dataset.delta = delta
          control.setAttribute('aria-label', label)
          control.disabled = delta === 1 && combo.quantity >= 99
        }
        controls.append(control)
      }
      row.append(copy, controls); this.selectedTarget.append(row)
    })
    this.dispatch('changed')
  }
  money(cents) { return `${(cents / 100).toFixed(2).replace('.', ',')} €` }
}

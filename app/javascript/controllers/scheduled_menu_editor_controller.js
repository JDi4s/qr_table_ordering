import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  connect() { this.changed = () => this.sync(); this.element.addEventListener('change', this.changed); this.sync() }
  disconnect() { this.element.removeEventListener('change', this.changed) }
  sync() {
    this.element.querySelectorAll('[data-section-toggle]').forEach(input => {
      const panel = this.element.querySelector(`[data-sale-section="${input.dataset.sectionToggle}"]`)
      if (panel) panel.hidden = !input.checked
    })
    this.element.querySelectorAll('[data-group-key]').forEach(input => {
      const panel = this.element.querySelector(`[data-group-panel="${input.dataset.groupKey}"]`)
      if (!panel) return
      panel.hidden = !input.checked
      panel.querySelectorAll('.lunch-option-row input').forEach(field => { field.disabled = !input.checked })
      const count = panel.querySelectorAll('.lunch-option-row input[type=checkbox]:checked').length
      panel.querySelector('[data-selection-count]').textContent = `${count} ${count === 1 ? 'produto selecionado' : 'produtos selecionados'}`
    })
  }
}

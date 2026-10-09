import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  connect() { this.changed = () => this.sync(); this.element.addEventListener('change', this.changed); this.sync() }
  disconnect() { this.element.removeEventListener('change', this.changed) }
  addGroup() {
    const editor = Array.from(this.element.querySelectorAll('[data-group-editor][hidden]')).find(row => row.querySelector('[data-group-name]'))
    if (!editor) return
    editor.hidden = false
    editor.querySelector('[data-group-key]').checked = true
    this.sync()
    editor.querySelector('[data-group-name]').focus()
  }
  sync() {
    this.element.querySelectorAll('[data-section-toggle]').forEach(input => {
      const panel = this.element.querySelector(`[data-sale-section="${input.dataset.sectionToggle}"]`)
      if (panel) panel.hidden = !input.checked
    })
    this.element.querySelectorAll('[data-group-key]').forEach(input => {
      const key = input.dataset.groupKey
      const editor = this.element.querySelector(`[data-group-editor="${key}"]`)
      const name = editor.querySelector('[data-group-name]')
      const types = editor.querySelector('[data-group-types-field]')
      if (name) { name.disabled = editor.hidden; name.required = !editor.hidden && input.checked }
      if (types) { types.disabled = editor.hidden; types.required = !editor.hidden && input.checked; input.dataset.groupTypes = JSON.stringify(types.value.split(',').filter(Boolean)) }
      const panel = this.element.querySelector(`[data-group-panel="${key}"]`)
      if (!panel) return
      if (name) panel.querySelector('[data-group-title]').textContent = name.value.trim() || 'Novo grupo'
      panel.hidden = !input.checked || editor.hidden
      const allowedTypes = JSON.parse(input.dataset.groupTypes)
      panel.querySelectorAll('.lunch-option-row').forEach(row => {
        const allowed = !types || allowedTypes.includes(row.dataset.productKind)
        row.dataset.groupExcluded = String(!allowed)
        row.hidden = !allowed || row.dataset.searchExcluded === 'true'
        row.querySelectorAll('input').forEach(field => { field.disabled = !input.checked || !allowed })
      })
      const count = panel.querySelectorAll('.lunch-option-row input[type=checkbox]:checked:not(:disabled)').length
      panel.querySelector('[data-selection-count]').textContent = `${count} ${count === 1 ? 'produto selecionado' : 'produtos selecionados'}`
    })
    const selected = this.element.querySelectorAll('[data-group-key]:checked').length
    this.element.querySelectorAll('[data-no-groups]').forEach(hint => { hint.hidden = selected > 0 })
    const add = this.element.querySelector('[data-add-group]')
    if (add) add.hidden = !Array.from(this.element.querySelectorAll('[data-group-editor][hidden]')).some(row => row.querySelector('[data-group-name]'))
  }
}

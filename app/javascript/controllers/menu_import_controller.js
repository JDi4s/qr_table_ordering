import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "product", "count", "countLabel", "submit"]
  connect() { this.sync() }
  stopToggle(event) { event.stopPropagation() }
  categoryChanged(event) {
    const node = event.target.closest('[data-category-node]')
    node.querySelectorAll('input[type=checkbox]').forEach(input => { input.checked = event.target.checked; input.indeterminate = false })
    this.sync()
  }
  productChanged() { this.sync() }
  selectAll() { this.setAll(true) }
  clearAll() { this.setAll(false) }
  setAll(checked) {
    [...this.categoryTargets, ...this.productTargets].forEach(input => { input.checked = checked; input.indeterminate = false })
    this.sync()
  }
  sync() {
    this.categoryTargets.slice().reverse().forEach(input => {
      const children = Array.from(input.closest('[data-category-node]').querySelectorAll('input[type=checkbox]')).filter(child => child !== input)
      if (!children.length) return
      const any = children.some(child => child.checked || child.indeterminate)
      input.checked = any
      input.indeterminate = any && !children.every(child => child.checked && !child.indeterminate)
    })
    const count = this.productTargets.filter(input => input.checked).length
    this.countTarget.textContent = count
    this.countLabelTarget.textContent = count === 1 ? 'produto selecionado' : 'produtos selecionados'
    this.submitTarget.disabled = ![...this.categoryTargets, ...this.productTargets].some(input => input.checked)
  }
  search(event) {
    const query = event.target.value.trim().toLocaleLowerCase()
    this.element.querySelectorAll('.menu-import-product').forEach(row => {
      const categoryMatch = Array.from(this.ancestors(row)).some(node => node.dataset.searchName.includes(query))
      row.hidden = !!query && !row.dataset.searchName.includes(query) && !categoryMatch
    })
    this.element.querySelectorAll('.menu-import-category').forEach(node => {
      node.hidden = !!query && !node.dataset.searchName.includes(query) && !node.querySelector('.menu-import-product:not([hidden])')
      if (query && !node.hidden) node.open = true
    })
  }
  *ancestors(row) {
    let node = row.parentElement.closest('[data-category-node]')
    while (node) { yield node; node = node.parentElement.closest('[data-category-node]') }
  }
}

import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  connect() {
    this.key = `bocato-menu-section-${this.element.dataset.staffMenuKeyValue}`
    let choice = 'carta'
    try { choice = sessionStorage.getItem(this.key) || choice } catch (_) {}
    this.show(choice)
  }
  select(event) {
    const choice = event.currentTarget.dataset.menuSection
    this.show(choice)
    try { sessionStorage.setItem(this.key, choice) } catch (_) {}
  }
  show(choice) {
    if (!this.element.querySelector('[data-menu-section="scheduled"]')) choice = 'carta'
    this.element.querySelectorAll('[data-menu-section]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.menuSection === choice)))
    this.element.querySelectorAll('[data-menu-section-panel]').forEach(panel => { panel.hidden = panel.dataset.menuSectionPanel !== choice })
  }
}

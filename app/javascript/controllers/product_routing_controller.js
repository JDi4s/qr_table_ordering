import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  kind(event) {
    const prep = this.element.querySelector('[name="menu_item[preparation_key]"]')
    if (!prep || this.overridden) return
    prep.value = ['drink','coffee','dessert'].includes(event.target.value) ? 'counter' : 'kitchen'
  }
  override() { this.overridden = true }
}

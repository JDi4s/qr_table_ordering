import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  connect() { window.dispatchEvent(new CustomEvent('bocato:preparation', { detail: { sound: this.element.dataset.sound === '1' } })); this.element.remove() }
}

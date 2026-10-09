import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  static targets = ['toggle', 'limit']
  connect() { this.limitChanged = () => { this.toggleTarget.checked = Number(this.limitTarget.value) > 0 }; this.limitTarget.addEventListener('input', this.limitChanged) }
  disconnect() { this.limitTarget.removeEventListener('input', this.limitChanged) }
  sync() { if (this.toggleTarget.checked) { this.limitTarget.value = Math.max(1, Number(this.limitTarget.value)); } else { this.limitTarget.value = 0; } }
}

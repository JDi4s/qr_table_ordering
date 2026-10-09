import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  all() { this.set(true) }
  none() { this.set(false) }
  set(value) { this.element.querySelectorAll('input[name="product_ids[]"]').forEach(input => { input.checked = value }) }
}

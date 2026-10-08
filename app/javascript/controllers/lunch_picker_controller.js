import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["row"]
  filter(event) {
    const query = event.target.value.trim().toLocaleLowerCase()
    this.rowTargets.forEach(row => { row.hidden = !row.dataset.name.includes(query) })
  }
}

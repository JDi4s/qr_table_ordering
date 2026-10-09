import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["row"]
  filter(event) {
    const query = event.target.value.trim().toLocaleLowerCase()
    this.rowTargets.forEach(row => { row.dataset.searchExcluded = String(!row.dataset.name.includes(query)); row.hidden = row.dataset.searchExcluded === 'true' || row.dataset.groupExcluded === 'true' })
  }
}

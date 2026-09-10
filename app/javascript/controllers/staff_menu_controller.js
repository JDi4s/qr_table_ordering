import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "tab"]

  select(event) {
    const selected = event.currentTarget.dataset.menuStatus
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.menuStatus !== selected })
    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
    })
  }
}

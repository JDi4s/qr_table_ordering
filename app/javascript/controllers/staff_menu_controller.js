import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.storageKey = `bocato-menu-context-${this.keyValue}`
    this.loadHandler = () => this.restore()
    this.toggleHandler = (event) => {
      if (!this.restoring && event.target.matches(".staff-category-details")) this.remember()
    }
    document.addEventListener("turbo:load", this.loadHandler)
    this.element.addEventListener("toggle", this.toggleHandler, true)
    this.restore()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.loadHandler)
    this.element.removeEventListener("toggle", this.toggleHandler, true)
    cancelAnimationFrame(this.restoreFrame)
  }

  remember(event) {
    if (this.restoring) return
    const panel = this.element.querySelector("[data-menu-status]")
    if (!panel) return
    let status = panel.dataset.menuStatus
    const link = event?.target.closest?.("a[href]")
    if (link) {
      const destination = new URL(link.href, window.location.origin)
      if (destination.pathname === "/staff/menu") {
        status = destination.searchParams.get("menu_status") || "active"
      }
    }
    const state = {
      status,
      scrollY: window.scrollY,
      open: [...this.element.querySelectorAll(".staff-category-details[open]")]
        .map((details) => details.closest(".menu-category-card").id)
    }
    try { sessionStorage.setItem(this.storageKey, JSON.stringify(state)) } catch (_) {}
  }

  restore() {
    let state
    try { state = JSON.parse(sessionStorage.getItem(this.storageKey)) } catch (_) { return }
    const panel = this.element.querySelector("[data-menu-status]")
    if (!state || !panel || state.status !== panel.dataset.menuStatus || !Array.isArray(state.open)) return
    this.restoring = true
    this.element.querySelectorAll(".staff-category-details").forEach((details) => {
      details.open = state.open.includes(details.closest(".menu-category-card").id)
    })
    cancelAnimationFrame(this.restoreFrame)
    this.restoreFrame = requestAnimationFrame(() => {
      this.restoreFrame = requestAnimationFrame(() => {
        window.scrollTo({ top: Number(state.scrollY) || 0, behavior: "instant" })
        this.restoring = false
      })
    })
  }
}

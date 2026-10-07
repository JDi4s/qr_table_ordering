import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["trigger", "dot", "pendingLabel", "panel", "list"]
  static values = { url: String, ordersUrl: String, key: String }

  connect() {
    this.seen = new Set()
    try { this.seen = new Set(JSON.parse(sessionStorage.getItem(this.storageKey) || "[]")) } catch (_) {}
    this.subscription = consumer.subscriptions.create({ channel: "TableVisitsChannel" }, {
      connected: () => { this.element.dataset.tableActivationConnected = "true"; this.refresh(false) },
      received: (event) => {
        if (event.state === "waiting") this.notify(event.visit_id, event.table_number)
        this.refresh(false)
      }
    })
    this.visibility = () => { if (!document.hidden) this.refresh(true) }
    this.outside = (event) => {
      if (this.hasPanelTarget && !this.panelTarget.hidden && !event.target.closest('.staff-orders-heading')) this.close(false)
    }
    this.keyboard = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("visibilitychange", this.visibility)
    document.addEventListener("click", this.outside)
    document.addEventListener("keydown", this.keyboard)
    this.timer = setInterval(() => this.refresh(true), 10000)
    if (new URLSearchParams(window.location.search).get("activate") === "1") this.open()
    this.refresh(false)
  }

  disconnect() {
    clearInterval(this.timer)
    this.subscription?.unsubscribe()
    this.abort?.abort()
    document.removeEventListener("visibilitychange", this.visibility)
    document.removeEventListener("click", this.outside)
    document.removeEventListener("keydown", this.keyboard)
  }

  get storageKey() { return `bocato-activation-seen-${this.keyValue}` }

  remember(id) {
    this.seen.add(Number(id))
    try { sessionStorage.setItem(this.storageKey, JSON.stringify([...this.seen].slice(-100))) } catch (_) {}
  }

  notify(id, number) {
    if (this.seen.has(Number(id))) return
    this.remember(id)
    const sound = this.application.getControllerForElementAndIdentifier(this.element, "staff-orders")
    sound?.beep("activation")
    this.element.dispatchEvent(new CustomEvent("bocato:table-waiting", { detail: { visitId: id, tableNumber: number } }))
    if (!this.hasPanelTarget) {
      const popup = document.createElement("div")
      popup.className = "staff-popup table-activation-popup"
      const label = document.createElement("strong")
      label.textContent = number ? `Mesa ${number} aguarda ativação` : "Uma mesa aguarda ativação"
      const link = document.createElement("a")
      link.className = "button secondary"
      link.href = `${this.ordersUrlValue}?activate=1`
      link.textContent = "Ativar mesa"
      popup.append(label, link)
      document.getElementById("staff_notifications")?.append(popup)
      setTimeout(() => popup.remove(), 10000)
    }
  }

  async refresh(alertNew = false) {
    if (this.loading) { this.again = true; return }
    this.loading = true
    this.abort = new AbortController()
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" }, cache: "no-store", signal: this.abort.signal })
      if (!response.ok) return
      const data = await response.json()
      data.pending_ids.forEach((id) => alertNew && this.initialized ? this.notify(id) : this.remember(id))
      this.initialized = true
      const signature = JSON.stringify(data.states)
      if (this.hasListTarget && signature !== this.signature) this.listTarget.innerHTML = data.html
      this.signature = signature
      if (this.hasDotTarget) this.dotTarget.hidden = data.pending_ids.length === 0
      if (this.hasPendingLabelTarget) this.pendingLabelTarget.textContent = data.pending_ids.length ? ` · ${data.pending_ids.length} à espera` : ""
    } catch (_) {
      // The next poll or Cable reconnect reconciles missed events.
    } finally {
      this.loading = false
      if (this.again && !this.abort.signal.aborted) { this.again = false; this.refresh(true) }
    }
  }

  toggle() { this.panelTarget.hidden ? this.open() : this.close() }
  open() {
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.refresh(true)
  }
  close(focus = true) {
    if (!this.hasPanelTarget || this.panelTarget.hidden) return
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    if (focus) this.triggerTarget.focus()
  }
}

import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["notice", "heading", "message", "submit"]
  static values = { url: String, token: String, visit: Number, state: String, service: Boolean, reload: Boolean }

  connect() {
    this.state = this.stateValue
    this.update({ visit_id: this.visitValue, state: this.state, allowed: this.state === "open" && this.serviceValue })
    this.subscription = consumer.subscriptions.create({ channel: "TableVisitsChannel", table_token: this.tokenValue }, {
      connected: () => this.refresh(), received: () => this.refresh()
    })
    this.visibility = () => { if (!document.hidden) this.refresh() }
    document.addEventListener("visibilitychange", this.visibility)
    this.timer = setInterval(() => this.refresh(), 10000)
    this.element.addEventListener("submit", this.guard = (event) => {
      if (event.submitter?.matches('[data-table-access-target="submit"]') && !this.allowed) event.preventDefault()
    })
  }

  disconnect() {
    clearInterval(this.timer)
    this.dismissActivation()
    this.subscription?.unsubscribe()
    this.abort?.abort()
    document.removeEventListener("visibilitychange", this.visibility)
    this.element.removeEventListener("submit", this.guard)
  }

  async refresh() {
    if (this.loading) { this.again = true; return }
    this.loading = true
    this.abort = new AbortController()
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" }, cache: "no-store", signal: this.abort.signal })
      if (response.ok) this.update(await response.json())
      else this.update({ state: "closed", allowed: false })
    } catch (error) {
      if (error.name !== "AbortError") this.update({ state: this.state, allowed: false, offline: true })
    } finally {
      this.loading = false
      if (this.again && !this.abort.signal.aborted) { this.again = false; this.refresh() }
    }
  }

  update(data) {
    const previous = this.state
    const sameVisit = Number(data.visit_id) === this.visitValue
    this.state = data.offline ? this.state : (sameVisit ? data.state : "closed")
    this.allowed = Boolean(sameVisit && data.allowed)
    this.submitTargets.forEach((button) => { button.disabled = !this.allowed })
    if (previous === "waiting" && this.allowed) this.showActivation()
    if (!this.allowed) this.dismissActivation()
    if (this.hasNoticeTarget) {
      this.noticeTarget.hidden = this.allowed
      const closed = this.state === "closed"
      const paused = this.state === "open" && !this.allowed
      this.headingTarget.textContent = data.offline ? "A verificar a ligação" : (closed ? "Esta visita terminou" : (paused ? "Serviço temporariamente pausado" : "A tua mesa ainda não está ativa"))
      this.messageTarget.textContent = data.offline ? "Os pedidos voltam a ficar disponíveis quando a ligação for restabelecida." : (closed ? "Abre novamente o menu para iniciar uma nova visita." : (paused ? "Podes consultar o menu. Aguarda que o serviço seja retomado." : "Podes escolher os produtos. Aguarda que a equipa ative a mesa para enviares o pedido."))
    }
    if (this.reloadValue && previous !== "closed" && this.state === "closed" && !this.reloading) {
      this.reloading = true
      window.location.reload()
    }
  }

  showActivation() {
    this.dismissActivation()
    this.activationNotice = document.createElement("div")
    this.activationNotice.className = "customer-table-activated"
    this.activationNotice.setAttribute("role", "status")
    this.activationNotice.setAttribute("aria-live", "polite")
    this.activationNotice.innerHTML = '<span class="customer-table-activated-icon" aria-hidden="true">✓</span><div><strong>Mesa ativa</strong><span>A equipa ativou a tua mesa. Já podes enviar o pedido.</span></div><button type="button" aria-label="Fechar aviso de mesa ativa">×</button>'
    this.activationNotice.querySelector("button").addEventListener("click", () => this.dismissActivation())
    document.body.append(this.activationNotice)
    this.activationTimer = setTimeout(() => this.dismissActivation(), 6000)
  }

  dismissActivation() {
    clearTimeout(this.activationTimer)
    this.activationNotice?.remove()
    this.activationNotice = null
  }
}

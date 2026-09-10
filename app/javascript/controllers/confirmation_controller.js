import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "confirm", "cancel"]

  connect() {
    this.handleClick = this.handleClick.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("click", this.handleClick, true)
    document.addEventListener("submit", this.handleSubmit, true)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClick, true)
    document.removeEventListener("submit", this.handleSubmit, true)
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleClick(event) {
    const trigger = event.target.closest("[data-confirmation-message]")
    if (!trigger || trigger.disabled || trigger.closest("[data-confirmation-modal]")) return

    const form = trigger.form
    event.preventDefault()
    event.stopImmediatePropagation()
    this.ask(trigger.dataset.confirmationMessage, () => {
      if (form) this.submitForm(form, trigger)
      else trigger.click()
    })
  }

  handleSubmit(event) {
    const form = event.target
    if (form.dataset.confirmationBypass === "true") {
      delete form.dataset.confirmationBypass
      return
    }

    const trigger = event.submitter || form.querySelector("[data-confirmation-message]")
    if (!trigger) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.ask(trigger.dataset.confirmationMessage, () => this.submitForm(form, trigger))
  }

  submitForm(form, submitter) {
    form.dataset.confirmationBypass = "true"
    if (form.requestSubmit) form.requestSubmit(submitter)
    else form.submit()
  }

  ask(message, callback) {
    this.pending = callback
    this.messageTarget.textContent = message || "Confirmar esta ação?"
    this.element.hidden = false
    document.body.classList.add("confirmation-open")
    this.confirmTarget.focus()
  }

  confirm() {
    const callback = this.pending
    this.close()
    callback?.()
  }

  cancel() {
    this.close()
  }

  close() {
    this.pending = null
    this.element.hidden = true
    document.body.classList.remove("confirmation-open")
  }

  handleKeydown(event) {
    if (event.key === "Escape" && !this.element.hidden) this.cancel()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "username", "email", "areas", "active"]
  static values = { originalActive: Boolean }

  connect() {
    this.syncRequirements()
  }

  syncRequirements() {
    if (!this.hasRoleTarget) return

    const manager = this.roleTarget.value === "manager"

    if (this.hasUsernameTarget) {
      this.usernameTarget.required = !manager
      this.usernameTarget.setAttribute("aria-required", String(!manager))
    }

    if (this.hasEmailTarget) {
      this.emailTarget.required = manager
      this.emailTarget.setAttribute("aria-required", String(manager))
    }

    if (this.hasAreasTarget) {
      this.areasTarget.hidden = manager
    }
  }

  confirmDeactivate(event) {
    if (!this.hasActiveTarget || !this.originalActiveValue || this.activeTarget.checked) return

    const confirmed = window.confirm("Desativar este acesso? Esta pessoa deixará imediatamente de conseguir entrar.")
    if (!confirmed) event.preventDefault()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handler = (event) => {
      const stream = event.target
      const target = stream.getAttribute("target") || ""
      const orderStream = target === "staff_orders_live" || target.startsWith("order_")

      if (!orderStream) return

      event.preventDefault()
      this.scheduleReload()
    }

    document.addEventListener("turbo:before-stream-render", this.handler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handler)
  }

  scheduleReload() {
    if (this.reloadScheduled) return

    this.reloadScheduled = true
    window.setTimeout(() => window.location.reload(), 50)
  }
}

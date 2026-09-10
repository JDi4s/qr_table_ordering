import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("turbo:load", () => {
  const orderId = new URLSearchParams(window.location.search).get("open_order")
  if (!orderId) return

  const order = document.getElementById(`order-${orderId}`)
  if (!order) return

  window.setTimeout(() => {
    order.scrollIntoView({ behavior: "auto", block: "start" })
  }, 50)
})

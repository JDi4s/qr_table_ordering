// app/javascript/controllers/staff_orders_controller.js  (FULL FILE — create)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handler = this.onTurboStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handler)
  }

  onTurboStreamRender(event) {
    // Only beep when a new row is appended into the pending_orders list
    const stream = event.target
    if (stream.tagName !== "TURBO-STREAM") return
    if (stream.getAttribute("action") !== "append") return
    if (stream.getAttribute("target") !== "pending_orders") return

    const enabled = document.body.dataset.staffSoundEnabled === "1"
    if (!enabled) return

    this.beep()
  }

  beep() {
    // simple, reliable beep (no audio files needed)
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const o = ctx.createOscillator()
    const g = ctx.createGain()

    o.type = "sine"
    o.frequency.value = 880
    g.gain.value = 0.08

    o.connect(g)
    g.connect(ctx.destination)

    o.start()
    setTimeout(() => {
      o.stop()
      ctx.close()
    }, 180)
  }
}

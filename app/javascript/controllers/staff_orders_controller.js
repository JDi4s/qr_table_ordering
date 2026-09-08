import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handler = (event) => {
      const stream = event.target
      if (stream.getAttribute("action") === "append" && ["staff_orders_live", "service_calls"].includes(stream.getAttribute("target"))) this.beep()
    }
    document.addEventListener("turbo:before-stream-render", this.handler)
  }
  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handler)
    this.audio?.close()
  }
  async enableAudio() {
    const Audio = window.AudioContext || window.webkitAudioContext
    if (!Audio) return
    this.audio ||= new Audio()
    await this.audio.resume()
    this.beep(true)
  }
  beep(test = false) {
    if ((!test && this.element.dataset.staffSoundEnabled !== "1") || this.audio?.state !== "running") return
    const oscillator = this.audio.createOscillator()
    const gain = this.audio.createGain()
    oscillator.frequency.value = 880
    gain.gain.value = 0.08
    oscillator.connect(gain)
    gain.connect(this.audio.destination)
    oscillator.start()
    oscillator.stop(this.audio.currentTime + 0.18)
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
  }
}

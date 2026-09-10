import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "previous", "next", "dots"]

  connect() {
    this.updateControls = this.updateControls.bind(this)
    this.trackTarget.addEventListener("scroll", this.updateControls, { passive: true })
    window.addEventListener("resize", this.updateControls)
    this.resizeObserver = new ResizeObserver(this.updateControls)
    this.resizeObserver.observe(this.trackTarget)
    this.updateControls()
    this.timer = window.setInterval(() => this.advance(), 4500)
    this.trackTarget.addEventListener("pointerdown", () => this.pause(), { passive: true })
    this.trackTarget.addEventListener("pointerup", () => this.resume(), { passive: true })
  }

  disconnect() {
    this.pause()
    this.trackTarget.removeEventListener("scroll", this.updateControls)
    window.removeEventListener("resize", this.updateControls)
    this.resizeObserver?.disconnect()
  }

  toggle() {
    this.pause()
  }

  pause() {
    window.clearInterval(this.timer)
    this.timer = null
  }

  resume() {
    if (!this.timer) this.timer = window.setInterval(() => this.advance(), 4500)
  }

  previous() {
    this.pause()
    this.scrollBy(-1)
  }

  next() {
    this.pause()
    this.scrollBy(1)
  }

  scrollBy(direction) {
    const card = this.trackTarget.querySelector(".suggestion-card")
    if (!card) return

    const distance = card.getBoundingClientRect().width + 12
    this.trackTarget.scrollBy({ left: distance * direction, behavior: "smooth" })
  }

  advance() {
    const track = this.trackTarget
    const card = track.querySelector(".suggestion-card")
    if (!card) return

    const distance = card.getBoundingClientRect().width + 12
    const atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - distance
    track.scrollTo({ left: atEnd ? 0 : track.scrollLeft + distance, behavior: "smooth" })
  }

  updateControls() {
    const canScroll = this.trackTarget.scrollWidth > this.trackTarget.clientWidth + 4
    if (this.hasPreviousTarget) this.previousTarget.hidden = !canScroll || this.trackTarget.scrollLeft <= 4
    if (this.hasNextTarget) this.nextTarget.hidden = !canScroll || this.trackTarget.scrollLeft + this.trackTarget.clientWidth >= this.trackTarget.scrollWidth - 4
    if (this.hasDotsTarget) {
      this.dotsTarget.hidden = !canScroll
      const maximum = Math.max(0, this.trackTarget.scrollWidth - this.trackTarget.clientWidth)
      const progress = maximum > 4 ? Math.min(1, Math.max(0, this.trackTarget.scrollLeft / maximum)) : 0
      this.dotsTarget.style.setProperty('--suggestion-dot-left', `${progress * 67}%`)
    }
  }
}

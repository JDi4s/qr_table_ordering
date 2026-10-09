import { Controller } from '@hotwired/stimulus'
export default class extends Controller {
  connect() {
    this.refresh = () => {
      if (document.hidden || this.element.hasAttribute('busy')) return
      if (this.element.src) this.element.reload()
      else this.element.src = this.element.dataset.url
    }
    this.timer = setInterval(this.refresh, 15000)
    window.addEventListener('bocato:preparation', this.refresh)
    document.addEventListener('visibilitychange', this.refresh)
  }
  disconnect() { clearInterval(this.timer); window.removeEventListener('bocato:preparation', this.refresh); document.removeEventListener('visibilitychange', this.refresh) }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pushStatus", "pushButton", "soundStatus"]

  connect() {
    this.handler = (event) => {
      const stream = event.target
      if (stream.getAttribute("action") !== "append") return

      const target = stream.getAttribute("target")
      if (target === "staff_orders_live") this.beep("order")
      if (target === "service_calls") {
        this.beep("call")
        this.showCallPopup(stream)
      }
    }
    document.addEventListener("turbo:before-stream-render", this.handler)
    this.audioActivationHandler = () => {
      this.prepareAudio().then((ready) => {
        if (!ready) return
        this.setSoundStatus("Som pronto neste dispositivo.")
        this.removeAudioActivationListeners()
      }).catch(() => {})
    }
    document.addEventListener("pointerdown", this.audioActivationHandler, { passive: true })
    document.addEventListener("keydown", this.audioActivationHandler)
    this.registerServiceWorker()
  }
  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handler)
    this.removeAudioActivationListeners()
    this.audio?.close()
  }
  async enableAudio() {
    if (this.element.dataset.staffSoundEnabled !== "1") {
      this.setSoundStatus("Som desativado nas Preferências.", true)
      return
    }

    const ready = await this.prepareAudio()
    if (!ready || !(await this.beep("test"))) {
      this.setSoundStatus("Não foi possível ativar o som neste dispositivo.", true)
      return
    }
    this.removeAudioActivationListeners()
    this.setSoundStatus("Som ativo e testado neste dispositivo.")
  }
  async beep(kind = "order") {
    if (this.element.dataset.staffSoundEnabled !== "1") return false
    try {
      if (!(await this.prepareAudio())) return false
    } catch (_) {
      return false
    }

    const frequencies = kind === "call" ? [520, 700] : [880]
    const startedAt = this.audio.currentTime

    frequencies.forEach((frequency, index) => {
      const start = startedAt + (index * 0.18)
      const oscillator = this.audio.createOscillator()
      const gain = this.audio.createGain()
      oscillator.frequency.value = frequency
      oscillator.type = "sine"
      gain.gain.setValueAtTime(0.001, start)
      gain.gain.exponentialRampToValueAtTime(kind === "call" ? 0.22 : 0.18, start + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.001, start + 0.16)
      oscillator.connect(gain)
      gain.connect(this.audio.destination)
      oscillator.start(start)
      oscillator.stop(start + 0.17)
      oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
    })
    return true
  }

  async prepareAudio() {
    if (this.element.dataset.staffSoundEnabled !== "1") return false

    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    if (!AudioContextClass) return false

    this.audio ||= new AudioContextClass()
    if (this.audio.state !== "running") await this.audio.resume()
    return this.audio.state === "running"
  }

  removeAudioActivationListeners() {
    if (!this.audioActivationHandler) return
    document.removeEventListener("pointerdown", this.audioActivationHandler)
    document.removeEventListener("keydown", this.audioActivationHandler)
    this.audioActivationHandler = null
  }

  showCallPopup(stream) {
    const call = stream.templateContent?.querySelector?.(".call")
    const table = call?.querySelector("h3")?.textContent || "Nova chamada de cliente"
    const callId = call?.id
    const popup = document.createElement("div")
    popup.className = "staff-popup call-popup"
    const heading = document.createElement("strong")
    heading.textContent = table
    popup.append(heading)

    const claimForm = call?.querySelector("form")?.cloneNode(true)
    if (claimForm) {
      claimForm.querySelector("input[type='submit']")?.setAttribute("value", "Atender agora")
      claimForm.addEventListener("submit", () => popup.remove())
      popup.append(claimForm)
    }

    const viewButton = document.createElement("button")
    viewButton.type = "button"
    viewButton.className = "secondary"
    viewButton.textContent = "Ver chamada"
    viewButton.addEventListener("click", () => {
      document.getElementById(callId)?.scrollIntoView({ behavior: "smooth", block: "center" })
      popup.remove()
    })
    popup.append(viewButton)
    document.getElementById("staff_notifications")?.appendChild(popup)
  }

  async registerServiceWorker() {
    if (!("serviceWorker" in navigator)) return
    try {
      const registration = await navigator.serviceWorker.register("/staff-service-worker.js")
      const subscription = await registration.pushManager?.getSubscription()
      if (subscription) {
        const response = await this.saveSubscription(subscription)
        if (response.ok) this.markNotificationsActive()
      }
      return registration
    } catch (error) {
      console.warn("Não foi possível registar as notificações.", error)
    }
  }

  async enableNotifications() {
    try {
      await this.enableNotificationsNow()
    } catch (error) {
      console.error("Não foi possível ativar as notificações.", error)
      this.setPushStatus(`Falha ao ativar notificações (${error.message}).`, true)
    }
  }

  async enableNotificationsNow() {
    const publicKey = this.element.dataset.vapidPublicKey
    if (!publicKey) {
      this.setPushStatus("As notificações ainda não estão configuradas no servidor.", true)
      return
    }
    if (!("Notification" in window) || !("serviceWorker" in navigator)) {
      this.setPushStatus("Este dispositivo não suporta notificações web.", true)
      return
    }

    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      this.setPushStatus("As notificações foram bloqueadas neste dispositivo.", true)
      return
    }

    const registration = await navigator.serviceWorker.ready
    if (!registration.pushManager) {
      this.setPushStatus("Este dispositivo não suporta notificações push.", true)
      return
    }
    let subscription = await registration.pushManager.getSubscription()
    subscription ||= await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(publicKey)
    })

    const response = await this.saveSubscription(subscription)

    if (!response.ok) throw new Error(`servidor respondeu ${response.status}`)
    this.markNotificationsActive()
  }

  async saveSubscription(subscription) {
    const response = await fetch("/staff/push_subscription", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ subscription: subscription.toJSON() })
    })
    return response
  }

  setPushStatus(message, error = false) {
    if (!this.hasPushStatusTarget) return
    this.pushStatusTarget.textContent = message
    this.pushStatusTarget.classList.toggle("alert", error)
  }

  markNotificationsActive() {
    if (this.hasPushButtonTarget) this.pushButtonTarget.hidden = true
    this.setPushStatus("Notificações ativas neste dispositivo.")
  }

  setSoundStatus(message, error = false) {
    if (!this.hasSoundStatusTarget) return
    this.soundStatusTarget.textContent = message
    this.soundStatusTarget.classList.toggle("alert", error)
  }

  urlBase64ToUint8Array(value) {
    const padding = "=".repeat((4 - (value.length % 4)) % 4)
    const raw = window.atob((value + padding).replace(/-/g, "+").replace(/_/g, "/"))
    return Uint8Array.from([...raw].map((character) => character.charCodeAt(0)))
  }

}

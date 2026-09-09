import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pushStatus"]

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
    this.registerServiceWorker()
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
    this.beep("test", true)
  }
  beep(kind = "order", test = false) {
    if ((!test && this.element.dataset.staffSoundEnabled !== "1") || this.audio?.state !== "running") return
    const oscillator = this.audio.createOscillator()
    const gain = this.audio.createGain()
    oscillator.frequency.value = kind === "call" ? 520 : 880
    gain.gain.value = 0.08
    oscillator.connect(gain)
    gain.connect(this.audio.destination)
    oscillator.start()
    oscillator.stop(this.audio.currentTime + 0.18)
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect() }
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
      if (subscription) await this.saveSubscription(subscription)
      return registration
    } catch (error) {
      console.warn("Não foi possível registar as notificações.", error)
    }
  }

  async enableNotifications() {
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

    if (!response.ok) throw new Error("subscription failed")
    this.setPushStatus("Notificações ativas neste dispositivo.")
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

  urlBase64ToUint8Array(value) {
    const padding = "=".repeat((4 - (value.length % 4)) % 4)
    const raw = window.atob((value + padding).replace(/-/g, "+").replace(/_/g, "/"))
    return Uint8Array.from([...raw].map((character) => character.charCodeAt(0)))
  }

}

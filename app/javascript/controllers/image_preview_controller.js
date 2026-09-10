import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "stage", "image", "controls", "zoom", "hint"]

  connect() {
    this.pendingImage = null
    this.sourceData = null
    this.loadToken = 0
    this.cropReadyToken = 0
    this.offsetX = 0
    this.offsetY = 0
    this.baseScale = 1
    this.renderedScale = 1
    this.dragging = false
    this.boundPointerMove = (event) => this.pointerMove(event)
    this.boundPointerUp = () => this.pointerUp()
    window.addEventListener("pointermove", this.boundPointerMove)
    window.addEventListener("pointerup", this.boundPointerUp)
  }

  disconnect() {
    window.removeEventListener("pointermove", this.boundPointerMove)
    window.removeEventListener("pointerup", this.boundPointerUp)
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    const token = ++this.loadToken
    this.pendingImage = null
    this.sourceData = null
    this.stageTarget.hidden = true
    this.controlsTarget.hidden = true
    this.previewTarget.hidden = false
    this.previewTarget.textContent = "A carregar a imagem…"
    this.imageTarget.style.opacity = "0"

    if (!file.type.startsWith("image/")) {
      this.showError("Escolhe uma imagem JPG, PNG ou WebP.")
      return
    }

    const reader = new FileReader()
    reader.addEventListener("load", () => {
      if (token !== this.loadToken) return

      const source = reader.result
      const image = new Image()
      image.onload = () => {
        if (token !== this.loadToken) return

        this.pendingImage = image
        this.sourceData = source
        this.imageTarget.onload = () => this.showCrop(token)
        this.imageTarget.src = source
        if (this.imageTarget.complete && this.imageTarget.naturalWidth > 0) this.showCrop(token)
      }
      image.onerror = () => this.showError("Esta imagem não pôde ser pré-visualizada neste navegador. Escolhe JPG, PNG ou WebP.")
      image.src = source
    }, { once: true })
    reader.addEventListener("error", () => this.showError("Não foi possível ler esta imagem."), { once: true })
    reader.readAsDataURL(file)
  }

  showError(message) {
    this.pendingImage = null
    this.stageTarget.hidden = true
    this.controlsTarget.hidden = true
    this.previewTarget.hidden = false
    this.previewTarget.textContent = message
  }

  showCrop(token) {
    if (token !== this.loadToken || !this.pendingImage || this.cropReadyToken === token) return

    this.cropReadyToken = token
    this.stageTarget.hidden = false
    this.controlsTarget.hidden = false
    this.previewTarget.hidden = true
    this.zoomTarget.value = "1"
    window.requestAnimationFrame(() => {
      if (token !== this.loadToken) return
      this.resetPosition()
      this.renderCrop()
    })
  }

  pointerDown(event) {
    if (!this.pendingImage) return

    event.preventDefault()
    this.dragging = true
    this.lastPointerX = event.clientX
    this.lastPointerY = event.clientY
    this.stageTarget.setPointerCapture?.(event.pointerId)
  }

  pointerMove(event) {
    if (!this.dragging) return

    this.offsetX += event.clientX - this.lastPointerX
    this.offsetY += event.clientY - this.lastPointerY
    this.lastPointerX = event.clientX
    this.lastPointerY = event.clientY
    this.clampPosition()
    this.renderCrop()
  }

  pointerUp() {
    this.dragging = false
  }

  zoomChanged() {
    if (!this.pendingImage) return

    const stage = this.stageSize()
    const previousScale = this.renderedScale || this.scale()
    const nextScale = this.scale()
    const centerX = stage.width / 2
    const centerY = stage.height / 2
    const focusX = (centerX - this.offsetX) / previousScale
    const focusY = (centerY - this.offsetY) / previousScale
    this.offsetX = centerX - focusX * nextScale
    this.offsetY = centerY - focusY * nextScale
    this.clampPosition()
    this.renderCrop()
  }

  reset() {
    if (!this.pendingImage) return

    this.zoomTarget.value = "1"
    this.resetPosition()
    this.renderCrop()
  }

  prepare() {
    if (this.pendingImage) this.exportCrop()
  }

  stageSize() {
    return {
      width: this.stageTarget.clientWidth || 320,
      height: this.stageTarget.clientHeight || 320
    }
  }

  resetPosition() {
    const stage = this.stageSize()
    this.baseScale = Math.max(stage.width / this.pendingImage.naturalWidth, stage.height / this.pendingImage.naturalHeight)
    this.offsetX = (stage.width - this.pendingImage.naturalWidth * this.baseScale) / 2
    this.offsetY = (stage.height - this.pendingImage.naturalHeight * this.baseScale) / 2
  }

  scale() {
    return this.baseScale * Number.parseFloat(this.zoomTarget.value || "1")
  }

  clampPosition() {
    const stage = this.stageSize()
    const scale = this.scale()
    const width = this.pendingImage.naturalWidth * scale
    const height = this.pendingImage.naturalHeight * scale
    const minX = Math.min(0, stage.width - width)
    const minY = Math.min(0, stage.height - height)
    this.offsetX = Math.min(0, Math.max(minX, this.offsetX))
    this.offsetY = Math.min(0, Math.max(minY, this.offsetY))
  }

  renderCrop() {
    if (!this.pendingImage) return

    const scale = this.scale()
    this.imageTarget.style.width = `${this.pendingImage.naturalWidth * scale}px`
    this.imageTarget.style.height = `${this.pendingImage.naturalHeight * scale}px`
    this.imageTarget.style.transform = `translate3d(${this.offsetX}px, ${this.offsetY}px, 0)`
    this.imageTarget.style.opacity = "1"
    this.renderedScale = scale
    this.hintTarget.textContent = "Arrasta a imagem para a centrar e ajusta o zoom."
  }

  exportCrop() {
    const stage = this.stageSize()
    const scale = this.scale()
    const outputSize = 1200
    const sourceSize = Math.min(stage.width, stage.height) / scale
    const sourceX = Math.max(0, Math.min(this.pendingImage.naturalWidth - sourceSize, -this.offsetX / scale))
    const sourceY = Math.max(0, Math.min(this.pendingImage.naturalHeight - sourceSize, -this.offsetY / scale))
    const canvas = document.createElement("canvas")
    canvas.width = outputSize
    canvas.height = outputSize
    const context = canvas.getContext("2d")
    context.drawImage(this.pendingImage, sourceX, sourceY, sourceSize, sourceSize, 0, 0, outputSize, outputSize)

    const dataUrl = canvas.toDataURL("image/jpeg", 0.92)
    const [header, encoded] = dataUrl.split(",")
    const mime = header.match(/data:(.*);base64/)?.[1] || "image/jpeg"
    const binary = atob(encoded)
    const bytes = new Uint8Array(binary.length)
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index)
    const originalName = this.inputTarget.files[0]?.name || "produto.jpg"
    const name = originalName.replace(/\.[^.]+$/, "") + ".jpg"
    const croppedFile = new File([new Blob([bytes], { type: mime })], name, { type: mime, lastModified: Date.now() })
    const transfer = new DataTransfer()
    transfer.items.add(croppedFile)
    this.inputTarget.files = transfer.files
  }
}

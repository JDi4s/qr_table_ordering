import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "loadingImage", "entryImage", "headerImage", "empty"]

  connect() {
    this.objectUrl = null
  }

  disconnect() {
    this.revokeObjectUrl()
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      this.inputTarget.value = ""
      return
    }

    this.revokeObjectUrl()
    this.objectUrl = URL.createObjectURL(file)
    this.setImages(this.objectUrl)
  }

  setImages(source) {
    this.imageTargets().forEach((image) => {
      image.src = source
      image.hidden = false
    })
    this.emptyTargets.forEach((placeholder) => { placeholder.hidden = true })
  }

  imageTargets() {
    return [this.loadingImageTarget, this.entryImageTarget, this.headerImageTarget]
  }

  revokeObjectUrl() {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }
}

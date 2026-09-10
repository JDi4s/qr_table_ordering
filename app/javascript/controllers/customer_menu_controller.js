import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "product", "rootPanel", "categoryPanel", "subcategoryNav", "empty", "cartBar", "cartCount", "cartTotal", "toast"]

  connect() {
    this.activeRootId = this.rootPanelTargets.find((panel) => !panel.hidden)?.id || this.rootPanelTargets[0]?.id
    this.syncSubcategoryNavigation()
    this.syncCart()
  }

  selectRoot(event) {
    const rootId = event.currentTarget.dataset.rootId
    this.activeRootId = rootId

    this.rootPanelTargets.forEach((panel) => {
      panel.hidden = panel.id !== rootId
    })
    this.syncSubcategoryNavigation()
    this.element.querySelectorAll(".menu-root-tab").forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
    })

    const rootPanel = document.getElementById(rootId)
    const subcategoryNav = this.subcategoryNavTargets.find((nav) => nav.dataset.rootId === rootId)
    const firstCategory = subcategoryNav?.querySelector(".menu-subcategory-tab")
    if (firstCategory) this.showCategory(rootPanel, firstCategory.dataset.categoryId, firstCategory)
  }

  selectCategory(event) {
    const rootPanel = document.getElementById(event.currentTarget.dataset.rootId)
    this.showCategory(rootPanel, event.currentTarget.dataset.categoryId, event.currentTarget)
  }

  showCategory(rootPanel, categoryId, selectedTab) {
    if (!rootPanel) return

    rootPanel.querySelectorAll("[data-customer-menu-target='categoryPanel']").forEach((panel) => {
      panel.hidden = panel.id !== categoryId
    })
    selectedTab?.closest(".menu-subcategory-tabs")?.querySelectorAll(".menu-subcategory-tab").forEach((tab) => {
      const active = tab === selectedTab
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
    })
  }

  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    let visibleProducts = 0

    this.productTargets.forEach((product) => {
      const matches = !query || product.dataset.searchText.includes(query)
      product.hidden = !matches
      if (matches) visibleProducts += 1
    })

    this.categoryPanelTargets.forEach((section) => {
      const hasVisibleProduct = section.querySelector("[data-customer-menu-target='product']:not([hidden])")
      section.hidden = Boolean(query) && !hasVisibleProduct
    })

    if (query) {
      this.rootPanelTargets.forEach((panel) => {
        panel.hidden = !panel.querySelector("[data-customer-menu-target='product']:not([hidden])")
      })
    } else {
      this.rootPanelTargets.forEach((panel) => {
        panel.hidden = panel.id !== this.activeRootId
      })
    }

    this.syncSubcategoryNavigation(Boolean(query))

    this.emptyTarget.hidden = visibleProducts > 0 || !query
  }

  syncSubcategoryNavigation(searching = false) {
    this.subcategoryNavTargets.forEach((nav) => {
      nav.hidden = searching || nav.dataset.rootId !== this.activeRootId
    })
  }

  addProduct(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".customer-product-card")
    this.setQuantity(card, 1)
    this.showToast(`${this.productName(card)} adicionado ao pedido`)
  }

  toggleProduct(event) {
    if (event.type === "keydown" && !["Enter", " "].includes(event.key)) return
    if (event.target.closest("button, input, a")) return
    if (event.type === "keydown") event.preventDefault()
    const card = event.currentTarget.closest(".customer-product-card")
    const input = this.quantityInput(card)
    this.setQuantity(card, Math.min(99, this.currentQuantity(input) + 1))
    this.showToast(`${this.productName(card)} adicionado ao pedido`)
  }

  removeProduct(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".customer-product-card")
    const input = this.quantityInput(card)
    const next = Math.max(0, this.currentQuantity(input) - 1)
    this.setQuantity(card, next)
    this.showToast(next === 0 ? `${this.productName(card)} removido do pedido` : `${this.productName(card)} atualizado`)
  }

  increase(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".customer-product-card")
    const input = this.quantityInput(card)
    this.setQuantity(card, Math.min(99, this.currentQuantity(input) + 1))
    this.showToast(`${this.productName(card)} adicionado ao pedido`)
  }

  decrease(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".customer-product-card")
    const input = this.quantityInput(card)
    const next = Math.max(0, this.currentQuantity(input) - 1)
    this.setQuantity(card, next)
    this.showToast(next === 0 ? `${this.productName(card)} removido do pedido` : `${this.productName(card)} atualizado`)
  }

  setQuantity(card, quantity) {
    if (!card) return

    const nextQuantity = Math.max(0, Math.min(99, quantity))
    const input = this.quantityInput(card)
    const addButton = card.querySelector(".customer-add-button")
    const value = card.querySelector(".quantity-value")
    const removeButton = card.querySelector(".customer-remove-button")
    if (!input || !addButton || !value || !removeButton) return
    input.value = String(nextQuantity)
    value.textContent = String(nextQuantity)
    value.hidden = nextQuantity === 0
    addButton.hidden = nextQuantity > 0
    removeButton.hidden = nextQuantity === 0
    card.classList.toggle("is-added", nextQuantity > 0)
    card.setAttribute("aria-label", nextQuantity > 0 ? `Aumentar quantidade de ${this.productName(card)}` : `Adicionar ${this.productName(card)}`)
    this.syncCart()
  }

  syncCart() {
    let count = 0
    let totalCents = 0

    this.productTargets.forEach((card) => {
      const input = this.quantityInput(card)
      const quantity = this.currentQuantity(input)
      const addButton = card.querySelector(".customer-add-button")
      const value = card.querySelector(".quantity-value")
      const removeButton = card.querySelector(".customer-remove-button")
      if (!input || !addButton || !value || !removeButton) return
      value.hidden = quantity === 0
      addButton.hidden = quantity > 0
      removeButton.hidden = quantity === 0
      value.textContent = String(quantity)
      card.classList.toggle("is-added", quantity > 0)
      card.setAttribute("aria-label", quantity > 0 ? `Aumentar quantidade de ${this.productName(card)}` : `Adicionar ${this.productName(card)}`)
      count += quantity
      totalCents += quantity * this.priceCents(card)
    })

    this.cartBarTarget.hidden = count === 0
    this.cartCountTarget.textContent = `${count} ${count === 1 ? 'artigo' : 'artigos'}`
    this.cartTotalTarget.textContent = `${(totalCents / 100).toFixed(2).replace('.', ',')} €`
  }

  quantityInput(card) {
    return card.querySelector(".customer-quantity-input")
  }

  currentQuantity(input) {
    return Math.max(0, Number.parseInt(input?.value || "0", 10) || 0)
  }

  priceCents(card) {
    const cents = Number.parseInt(card.dataset.priceCents || "", 10)
    if (Number.isFinite(cents)) return cents

    const price = Number.parseFloat(String(card.dataset.price || "0").replace(',', '.'))
    return Number.isFinite(price) ? Math.round(price * 100) : 0
  }

  productName(card) {
    return card.querySelector(".customer-product-content > strong")?.textContent?.trim() || "Produto"
  }

  showToast(message) {
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => { this.toastTarget.hidden = true }, 1800)
  }
}

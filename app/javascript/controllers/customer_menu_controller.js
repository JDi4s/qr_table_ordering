import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["search", "product", "rootPanel", "categoryPanel", "subcategoryNav", "empty", "cartBar", "cartCount", "cartTotal", "toast"]

  connect() {
    this.activeRootId = this.rootPanelTargets.find((panel) => !panel.hidden)?.id || this.rootPanelTargets[0]?.id
    this.preserveLiveState = (event) => {
      if (event.target.getAttribute('target') !== this.element.id) return
      const replacement = event.target.querySelector('template')?.content.querySelector('#customer_menu')
      if (replacement) {
        const state = this.liveState()
        replacement.dataset.liveState = JSON.stringify(state)
        replacement.querySelectorAll('[data-lunch-menu-target=input]').forEach(input => { if (state.combos?.[input.name]) input.setAttribute('value', state.combos[input.name]) })
      }
    }
    document.addEventListener('turbo:before-stream-render', this.preserveLiveState)
    if (this.element.dataset.liveState) {
      this.restoreLiveState(JSON.parse(this.element.dataset.liveState))
      delete this.element.dataset.liveState
    }
    this.syncSubcategoryNavigation(Boolean(this.searchTarget.value.trim()))
    this.syncCart()
    this.scheduleLunchRefresh()
    this.onVisible = () => { if (!document.hidden && this.lunchDeadline && Date.now() >= this.lunchDeadline) this.refreshLunch() }
    document.addEventListener("visibilitychange", this.onVisible)
  }

  disconnect() {
    document.removeEventListener('turbo:before-stream-render', this.preserveLiveState)
    clearTimeout(this.lunchTimer)
    document.removeEventListener("visibilitychange", this.onVisible)
    clearTimeout(this.toastTimer)
  }

  liveState() {
    const quantities = {}
    this.productTargets.forEach(card => {
      const input = this.quantityInput(card)
      if (input && this.currentQuantity(input) > 0) quantities[input.id] = input.value
    })
    return {
      combos: Object.fromEntries(Array.from(this.element.querySelectorAll('[data-lunch-menu-target=input]')).map(input => [input.name,input.value])),
      quantities, root: this.activeRootId, search: this.searchTarget.value,
      categories: Array.from(this.element.querySelectorAll('.menu-subcategory-tab.is-active')).map(tab => tab.dataset.categoryId),
      focus: this.element.contains(document.activeElement) ? document.activeElement.id || (document.activeElement === this.searchTarget ? 'search' : null) : null
    }
  }

  restoreLiveState(state) {
    this.element.querySelectorAll('[data-lunch-menu-target=input]').forEach(input => { if (state.combos?.[input.name]) input.value = state.combos[input.name] })
    const remaining = new Set(Object.keys(state.quantities || {}))
    this.productTargets.forEach(card => {
      const input = this.quantityInput(card)
      if (!input) return
      if (state.quantities?.[input.id]) input.value = state.quantities[input.id]
      remaining.delete(input.id)
    })
    if (this.rootPanelTargets.some(panel => panel.id === state.root)) {
      this.activeRootId = state.root
      this.rootPanelTargets.forEach(panel => { panel.hidden = panel.id !== state.root })
      this.element.querySelectorAll('.menu-root-tab').forEach(tab => {
        const active = tab.dataset.rootId === state.root
        tab.classList.toggle('is-active', active)
        tab.setAttribute('aria-selected', String(active))
      })
    }
    this.element.querySelectorAll('.menu-subcategory-tab').forEach(tab => {
      if (state.categories?.includes(tab.dataset.categoryId)) this.showCategory(document.getElementById(tab.dataset.rootId), tab.dataset.categoryId, tab)
    })
    this.searchTarget.value = state.search || ''
    if (state.search) this.filter()
    if (state.focus === 'search') this.searchTarget.focus({ preventScroll: true })
    else if (state.focus) document.getElementById(state.focus)?.focus({ preventScroll: true })
    if (remaining.size) this.showToast('O menu foi atualizado. Um produto selecionado deixou de estar disponível e foi retirado do pedido.')
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
    value.hidden = false
    addButton.hidden = false
    removeButton.hidden = false
    addButton.disabled = nextQuantity >= 99
    removeButton.disabled = nextQuantity === 0
    card.classList.toggle("is-added", nextQuantity > 0)
    card.setAttribute("aria-label", nextQuantity > 0 ? `Aumentar quantidade de ${this.productName(card)}` : `Adicionar ${this.productName(card)}`)
    this.syncCart()
  }

  syncCart(event) {
    if (event?.detail?.removed) this.showToast('O menu completo mudou. Revê as tuas escolhas antes de continuar.')
    let count = 0
    let totalCents = 0

    this.productTargets.forEach((card) => {
      const input = this.quantityInput(card)
      const quantity = this.currentQuantity(input)
      const addButton = card.querySelector(".customer-add-button")
      const value = card.querySelector(".quantity-value")
      const removeButton = card.querySelector(".customer-remove-button")
      if (!input || !addButton || !value || !removeButton) return
      value.hidden = false
      addButton.hidden = false
      removeButton.hidden = false
      addButton.disabled = quantity >= 99
      removeButton.disabled = quantity === 0
      value.textContent = String(quantity)
      card.classList.toggle("is-added", quantity > 0)
      card.setAttribute("aria-label", quantity > 0 ? `Aumentar quantidade de ${this.productName(card)}` : `Adicionar ${this.productName(card)}`)
      count += quantity
      totalCents += quantity * this.priceCents(card)
    })

    try {
      const combos = Array.from(this.element.querySelectorAll('[data-lunch-menu-target=input]')).flatMap(input => JSON.parse(input.value || '[]'))
      combos.forEach(combo => { count += Number(combo.quantity) || 0; totalCents += (Number(combo.quantity) || 0) * (Number(combo.priceCents) || 0) })
    } catch { /* Empty lunch selection while reconnecting. */ }
    this.cartBarTarget.hidden = count === 0
    this.cartCountTarget.textContent = `${count} ${count === 1 ? 'artigo' : 'artigos'}`
    this.cartTotalTarget.textContent = `${(totalCents / 100).toFixed(2).replace('.', ',')} €`
  }

  scheduleLunchRefresh() {
    this.lunchDeadline = Date.parse(this.element.dataset.lunchTransition)
    if (Number.isFinite(this.lunchDeadline)) this.lunchTimer = setTimeout(() => this.refreshLunch(), Math.min(2147483647, Math.max(0, this.lunchDeadline - Date.now() + 1000)))
  }

  async refreshLunch() {
    const url = this.element.closest('[data-menu-snapshot-url]')?.dataset.menuSnapshotUrl
    if (!url || !this.element.isConnected || this.refreshingLunch) return
    this.refreshingLunch = true
    try {
      const response = await fetch(url, { headers: { Accept: 'text/vnd.turbo-stream.html' }, cache: 'no-store' })
      if (!response.ok) throw new Error('Menu unavailable')
      Turbo.renderStreamMessage(await response.text())
    } catch {
      this.lunchTimer = setTimeout(() => this.refreshLunch(), 30000)
    } finally { this.refreshingLunch = false }
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

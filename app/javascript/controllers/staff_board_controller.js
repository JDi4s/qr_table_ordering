import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "order", "calls", "ordersSection", "pendingCount", "acceptedCount", "callsCount", "allCount", "allCallsCount", "allOrdersCount"]

  connect() {
    let savedFilter
    try { savedFilter = localStorage.getItem(this.storageKey) } catch (_) {}
    const selectedTab = this.tabTargets.find((tab) => tab.dataset.boardFilter === savedFilter) || this.tabTargets[0]
    this.currentFilter = selectedTab.dataset.boardFilter
    this.mutationObserver = new MutationObserver(() => this.updateCounts())
    this.mutationObserver.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: ["data-board-status", "data-call-status"] })
    this.select({ currentTarget: selectedTab })
  }

  get storageKey() {
    return `mesa:staff-board-filter:${this.element.dataset.establishmentId}:${this.element.dataset.userId}`
  }

  disconnect() {
    this.mutationObserver?.disconnect()
  }

  select(event) {
    const filter = event.currentTarget.dataset.boardFilter
    this.currentFilter = filter
    try { localStorage.setItem(this.storageKey, filter) } catch (_) {}
    const callsVisible = filter === "calls" || filter === "all"

    this.callsTarget.hidden = !callsVisible
    this.ordersSectionTarget.hidden = filter === "calls"

    this.orderTargets.forEach((order) => {
      this.updateOrderVisibility(order)
    })

    this.tabTargets.forEach((tab) => {
      const active = tab === event.currentTarget
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
    })
    this.updateCounts()
  }

  orderTargetConnected(order) {
    this.updateOrderVisibility(order)
  }

  updateOrderVisibility(order) {
    const status = order.dataset.boardStatus
    const visible = this.currentFilter === "all" || (this.currentFilter === "pending" && status === "pending") || (this.currentFilter === "accepted" && status === "accepted")
    order.hidden = !visible
  }

  updateCounts() {
    const orders = [...this.element.querySelectorAll("#staff_orders_live [data-board-status]")]
    const callElements = [...this.element.querySelectorAll("#service_calls .call")]
    const calls = callElements.length
    const pendingCalls = callElements.filter((call) => call.dataset.callStatus === "pending").length
    const pending = orders.filter((order) => order.dataset.boardStatus === "pending").length
    const accepted = orders.filter((order) => order.dataset.boardStatus === "accepted").length

    this.orderTargets.forEach((order) => this.updateOrderVisibility(order))

    this.setCount(this.pendingCountTargets, pending)
    this.setCount(this.acceptedCountTargets, accepted)
    this.setCount(this.callsCountTargets, pendingCalls)
    this.setCount(this.allCountTargets, orders.length + calls)
    this.setCount(this.allCallsCountTargets, calls)
    this.setCount(this.allOrdersCountTargets, orders.length)
    this.tabTargets.forEach((tab) => {
      const needsAttention = (tab.dataset.boardFilter === "pending" && pending > 0) || (tab.dataset.boardFilter === "calls" && pendingCalls > 0)
      tab.classList.toggle("has-attention", needsAttention)
    })
  }

  setCount(targets, value) {
    targets.forEach((target) => {
      const nextValue = String(value)
      if (target.textContent !== nextValue) target.textContent = nextValue
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "search", "option", "count"]

  connect() {
    this.filter()
  }

  filter() {
    const categorySelected = Boolean(this.categoryTarget?.value)
    const categoryName = categorySelected ? this.categoryTarget.selectedOptions[0].textContent.trim().toLocaleLowerCase() : ""
    const query = this.searchTarget?.value.trim().toLocaleLowerCase() || ""

    this.optionTargets.forEach((option) => {
      const text = option.dataset.searchText || option.textContent.toLocaleLowerCase()
      const relevant = categorySelected && this.related(categoryName, text)
      const matchesSearch = !query || text.includes(query)
      const selected = option.querySelector("input").checked
      option.hidden = !(matchesSearch && (relevant || selected))
    })
    this.updateCount()
  }

  updateCount() {
    const selected = this.optionTargets.filter((option) => option.querySelector("input").checked).length
    this.countTarget.textContent = `${selected} ${selected === 1 ? "selecionada" : "selecionadas"}`
  }

  related(category, product) {
    if (category.includes("cafetaria") || category.includes("café")) return /nata|croissant|queque|bolo|tarte|café|chá/.test(product)
    if (category.includes("pastelaria") || category.includes("padaria")) return /café|chá|água|sumo/.test(product)
    if (category.includes("cerveja")) return /amendoim|batata|sandes|tosta|petisco/.test(product)
    if (category.includes("vinho")) return /amendoim|batata|sandes|tosta|petisco|presunto/.test(product)
    if (category.includes("sandes")) return /café|água|sumo|cerveja/.test(product)
    return true
  }
}

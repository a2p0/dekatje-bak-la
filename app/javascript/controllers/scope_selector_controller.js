import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "input"]

  connect() {
    const defaultOption = this.optionTargets.find(o => o.dataset.value === "full")
      || this.optionTargets[0]
    if (defaultOption) this.selectOption(defaultOption)
  }

  select(event) {
    this.selectOption(event.currentTarget)
  }

  submit() {
    this.formTarget.requestSubmit()
  }

  selectOption(card) {
    this.optionTargets.forEach(o => o.dataset.selected = "false")
    card.dataset.selected = "true"
    if (this.hasInputTarget) this.inputTarget.value = card.dataset.value
  }
}

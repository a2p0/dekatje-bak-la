import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  show(event) {
    const index = event.currentTarget.dataset.index

    this.tabTargets.forEach(tab => {
      if (tab.dataset.index === index) {
        tab.classList.add("border-indigo-500", "text-indigo-600", "dark:text-indigo-400")
        tab.classList.remove("border-transparent", "text-slate-500", "dark:text-slate-400")
      } else {
        tab.classList.remove("border-indigo-500", "text-indigo-600", "dark:text-indigo-400")
        tab.classList.add("border-transparent", "text-slate-500", "dark:text-slate-400")
      }
    })

    this.panelTargets.forEach(panel => {
      if (panel.dataset.index === index) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}

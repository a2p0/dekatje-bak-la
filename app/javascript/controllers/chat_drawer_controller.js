import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.classList.remove("translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "false")
    this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
      btn.setAttribute("aria-expanded", "true")
    })
    const input = this.drawerTarget.querySelector("[data-tutor-chat-target='input']")
    if (input) setTimeout(() => input.focus(), 50)
  }

  close() {
    this.drawerTarget.classList.add("translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "true")
    this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
      btn.setAttribute("aria-expanded", "false")
    })
  }
}

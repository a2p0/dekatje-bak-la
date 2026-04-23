import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  connect() {
    this._drawerOpenHandler = () => this.open()
    window.addEventListener("tutor:drawer-open", this._drawerOpenHandler)
  }

  disconnect() {
    window.removeEventListener("tutor:drawer-open", this._drawerOpenHandler)
  }

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

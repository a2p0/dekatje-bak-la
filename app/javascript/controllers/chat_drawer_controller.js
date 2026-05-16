import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  connect() {
    this._drawerOpenHandler = () => this.open()
    window.addEventListener("tutor:drawer-open", this._drawerOpenHandler)

    this._overlayHandler = (e) => {
      if (e.detail?.name && e.detail.name !== "tibo") this.close()
    }
    window.addEventListener("overlay:open", this._overlayHandler)
  }

  disconnect() {
    window.removeEventListener("tutor:drawer-open", this._drawerOpenHandler)
    window.removeEventListener("overlay:open", this._overlayHandler)
  }

  open() {
    this.drawerTarget.classList.remove("translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "false")
    this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
      btn.setAttribute("aria-expanded", "true")
    })

    window.dispatchEvent(new CustomEvent("overlay:open", { detail: { name: "tibo" } }))

    const input = this.drawerTarget.querySelector("[data-tutor-chat-target='input']")
    if (input) setTimeout(() => input.focus(), 50)
  }

  close() {
    const wasOpen = this.drawerTarget.classList.contains("translate-x-0")
    this.drawerTarget.classList.add("translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "true")
    this.element.querySelectorAll("[data-chat-drawer-toggle]").forEach(btn => {
      btn.setAttribute("aria-expanded", "false")
    })

    if (wasOpen) {
      window.dispatchEvent(new CustomEvent("overlay:close", { detail: { name: "tibo" } }))
    }

    document.dispatchEvent(new CustomEvent("chat-drawer:closed"))
  }
}

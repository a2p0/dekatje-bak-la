import { Controller } from "@hotwired/stimulus"

// Reusable focus trap for modals, drawers, and sidebars.
// Usage: add data-controller="focus-trap" to the container.
// Traps Tab/Shift+Tab inside the container.
// Dispatches "focus-trap:close" on Escape key.
export default class extends Controller {
  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.dispatch("close")
      return
    }

    if (event.key !== "Tab") return

    const focusable = this.element.querySelectorAll(
      'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )

    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey) {
      if (document.activeElement === first) {
        event.preventDefault()
        last.focus()
      }
    } else {
      if (document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }
  }
}

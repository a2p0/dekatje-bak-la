import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "toggle"]

  connect() {
    this.previouslyFocused = null
  }

  open() {
    this.previouslyFocused = document.activeElement
    this.drawerTarget.classList.remove("-translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    this.updateToggles(true)

    // Auto-focus first focusable element in the drawer
    const firstFocusable = this.drawerTarget.querySelector(
      'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )
    if (firstFocusable) firstFocusable.focus()
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    this.updateToggles(false)

    // Restore focus to the element that opened the drawer
    if (this.previouslyFocused && typeof this.previouslyFocused.focus === "function") {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  updateToggles(isOpen) {
    this.toggleTargets.forEach(el => {
      el.setAttribute("aria-expanded", String(isOpen))
    })
  }
}

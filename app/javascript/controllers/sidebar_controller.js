import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.style.transform = "translateX(0)"
    this.backdropTarget.classList.remove("hidden")
    this.backdropTarget.style.display = "block"
  }

  close() {
    this.drawerTarget.style.transform = "translateX(-100%)"
    this.backdropTarget.classList.add("hidden")
    this.backdropTarget.style.display = "none"
  }
}

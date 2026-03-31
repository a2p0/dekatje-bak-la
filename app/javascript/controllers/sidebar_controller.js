import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
  }
}

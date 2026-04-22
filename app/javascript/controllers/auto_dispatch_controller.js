import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { event: String }

  connect() {
    if (this.eventValue) {
      window.dispatchEvent(new CustomEvent(this.eventValue))
    }
  }
}

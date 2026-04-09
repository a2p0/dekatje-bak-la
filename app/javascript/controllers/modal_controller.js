import { Controller } from "@hotwired/stimulus"

// Minimal modal controller: hides the modal element when close is called.
// Used by ModalComponent's close button, backdrop click, and Escape key
// (via focus_trap_controller dispatching focus-trap:close).
export default class extends Controller {
  close() {
    this.element.classList.add("hidden")
  }
}

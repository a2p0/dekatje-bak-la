import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  redirect(event) {
    event.preventDefault()
    const code = this.element.querySelector("[name='access_code']").value.trim()
    if (code) {
      window.location.href = "/" + encodeURIComponent(code)
    }
  }
}

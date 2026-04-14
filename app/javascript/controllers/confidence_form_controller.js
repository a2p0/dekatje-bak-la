import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values  = { url: String }

  async submit(event) {
    const level = event.currentTarget.value
    if (!level) return

    this.buttonTargets.forEach(btn => {
      btn.disabled = true
      btn.classList.add("opacity-50", "cursor-not-allowed")
    })

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.#csrfToken(),
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ level: parseInt(level, 10) })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        this.#reenableButtons()
      }
    } catch {
      this.#reenableButtons()
    }
  }

  #reenableButtons() {
    this.buttonTargets.forEach(btn => {
      btn.disabled = false
      btn.classList.remove("opacity-50", "cursor-not-allowed")
    })
  }

  #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "model", "apiKey", "testButton"]
  static values = { models: Object }

  connect() {
    this.element.dataset.settingsConnected = "true"
  }

  providerChanged() {
    const provider = this.providerTarget.value
    const models = this.modelsValue[provider] || []
    const select = this.modelTarget

    select.innerHTML = ""
    models.forEach((m, i) => {
      const option = document.createElement("option")
      option.value = m.id
      option.textContent = `${m.cost} ${m.label}${m.note ? ` — ${m.note}` : ""}`
      if (i === 0) option.selected = true
      select.appendChild(option)
    })
  }

  toggleApiKey() {
    const input = this.apiKeyTarget
    input.type = input.type === "password" ? "text" : "password"
  }

  async testKey() {
    const provider = this.providerTarget.value
    const model = this.modelTarget.value
    const apiKey = this.apiKeyTarget.value

    if (!apiKey) {
      document.getElementById("test_key_result").innerHTML =
        '<p style="color: #f59e0b; font-size: 13px;">Entrez une clé API d\'abord.</p>'
      return
    }

    this.testButtonTarget.disabled = true
    this.testButtonTarget.textContent = "Test en cours..."

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(
      window.location.pathname.replace("/settings", "/settings/test_key"),
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token
        },
        body: `provider=${encodeURIComponent(provider)}&api_key=${encodeURIComponent(apiKey)}&model=${encodeURIComponent(model)}`
      }
    )

    const html = await response.text()
    Turbo.renderStreamMessage(html)

    this.testButtonTarget.disabled = false
    this.testButtonTarget.textContent = "Tester la clé"
  }
}

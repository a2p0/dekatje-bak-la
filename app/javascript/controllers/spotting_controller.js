import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["taskType", "source"]
  static values = { verifyUrl: String, skipUrl: String }

  verify() {
    const taskType = this.taskTypeTargets.find(r => r.checked)?.value
    if (!taskType) {
      alert("Sélectionne un type de tâche")
      return
    }

    const sources = this.sourceTargets.filter(c => c.checked).map(c => c.value)

    const form = new FormData()
    form.append("task_type", taskType)
    sources.forEach(s => form.append("sources[]", s))

    fetch(this.verifyUrlValue, {
      method: "POST",
      body: form,
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
  }

  skip() {
    fetch(this.skipUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
  }
}

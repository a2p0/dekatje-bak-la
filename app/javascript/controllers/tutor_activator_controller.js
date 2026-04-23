import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    subjectId:        Number,
    questionId:       Number,
    conversationsUrl: String
  }

  activate() {
    this.#openDrawer()

    fetch(this.conversationsUrlValue, {
      method:  "POST",
      headers: {
        "Accept":       "text/vnd.turbo-stream.html",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: new URLSearchParams({
        subject_id:  this.subjectIdValue,
        question_id: this.questionIdValue
      })
    })
      .then(r => r.text())
      .then(html => window.Turbo?.renderStreamMessage(html))
      .then(() => new Promise(resolve => setTimeout(resolve, 50)))
      .then(() => this.#openDrawer())
      .catch(() => {})
  }

  #openDrawer() {
    const rootEl    = document.querySelector("[data-controller~='chat-drawer']")
    const drawerCtrl = rootEl
      ? this.application.getControllerForElementAndIdentifier(rootEl, "chat-drawer")
      : null
    drawerCtrl?.open()
  }
}

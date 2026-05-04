import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "streamingPlaceholder", "chips"]
  static values  = {
    conversationId: String,
    messagesUrl:    String,
    questionId:     String
  }

  connect() {
    this.consumer     = null
    this.subscription = null
    this.isStreaming  = false

    if (this.conversationIdValue) {
      this.#subscribe(this.conversationIdValue)
      this.element.setAttribute("data-chat-connected", "true")
    }

    this.#scrollToBottom()
    this.#syncValidatingState()
  }

  disconnect() {
    this.#unsubscribe()
    this.element.removeAttribute("data-chat-connected")
  }

  async send(event) {
    if (event?.type === "keydown" && event.key !== "Enter") return
    if (this.isStreaming) return

    const content = this.inputTarget.value.trim()
    if (!content) return

    this.#hideError()
    this.#appendOptimisticMessage(content)
    this.inputTarget.value = ""
    this.#setStreaming(true)
    if (this.hasChipsTarget) this.chipsTarget.innerHTML = ""

    try {
      const body = { content }
      if (this.questionIdValue) body.question_id = this.questionIdValue

      const response = await fetch(this.messagesUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.#csrfToken(),
          "Accept":       "application/json"
        },
        body: JSON.stringify(body)
      })

      if (!response.ok) {
        const data = await response.json().catch(() => ({}))
        this.#showError(data.error || "Erreur lors de l'envoi du message.")
        this.#setStreaming(false)
      }
    } catch {
      this.#showError("Erreur de connexion. Vérifiez votre connexion internet.")
      this.#setStreaming(false)
    }
  }

  handleChipClick(event) {
    const button = event.target.closest("[data-chip-action]")
    if (!button) return

    const action = button.dataset.chipAction

    if (action === "send") {
      const text = button.dataset.chipText
      if (!text || this.isStreaming) return
      this.inputTarget.value = text
      this.send()
    } else if (action === "confidence") {
      const level = parseInt(button.dataset.chipLevel, 10)
      const url   = button.dataset.confidenceUrl
      if (!level || !url || this.isStreaming) return
      const container = button.closest("turbo-frame") || button.parentElement
      this.#submitConfidence(level, url, container)
    }
    // navigate: handled natively by <a href>
  }

  async #submitConfidence(level, url, chipsContainer) {
    const buttons = chipsContainer.querySelectorAll("[data-chip-action='confidence']")
    buttons.forEach(b => { b.disabled = true; b.classList.add("opacity-50", "cursor-not-allowed") })

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.#csrfToken(),
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ level })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        buttons.forEach(b => { b.disabled = false; b.classList.remove("opacity-50", "cursor-not-allowed") })
      }
    } catch {
      buttons.forEach(b => { b.disabled = false; b.classList.remove("opacity-50", "cursor-not-allowed") })
    }
  }

  #syncValidatingState() {
    if (!this.hasChipsTarget) return
    const isValidating = !!this.chipsTarget.querySelector("[data-tutor-chat-validating]")
    this.inputTarget.disabled      = isValidating
    this.sendButtonTarget.disabled = isValidating
    this.inputTarget.placeholder   = isValidating ? "Réponds via les chips ci-dessus…" : "Écris à Tibo…"
  }

  #handleReceived(data) {
    switch (data.type) {
      case "token":
        this.#onToken(data.token)
        break
      case "done":
        this.#onDone(data)
        break
      case "data_hints":
        this.#onDataHints(data.html)
        break
      case "error":
        this.#onError(data.error)
        break
    }
  }

  #onToken(token) {
    this.streamingPlaceholderTarget.classList.remove("hidden")
    this.streamingPlaceholderTarget.textContent += token
    this.#scrollToBottom()
  }

  #onDone(data) {
    const message = data.message
    this.streamingPlaceholderTarget.textContent = ""
    this.streamingPlaceholderTarget.classList.add("hidden")
    if (message && message.content) {
      const div = document.createElement("div")
      div.classList.add(
        "self-start",
        "bg-rad-paper", "border", "border-rad-rule",
        "text-rad-text",
        "px-3", "py-2",
        "rounded-2xl", "rounded-tl-sm",
        "max-w-[86%]", "text-sm", "leading-relaxed", "break-words"
      )
      div.dataset.messageId   = message.id
      div.dataset.messageRole = "assistant"
      div.textContent = message.content
      this.messagesTarget.appendChild(div)
    }
    if (data.chips_html !== undefined && this.hasChipsTarget) {
      this.chipsTarget.innerHTML = data.chips_html
      this.#syncValidatingState()
    }
    this.#setStreaming(false)
    this.#scrollToBottom()
  }

  #onDataHints(html) {
    if (html) {
      this.messagesTarget.insertAdjacentHTML("beforeend", html)
      this.#scrollToBottom()
    }
  }

  #onError(message) {
    this.streamingPlaceholderTarget.textContent = ""
    this.streamingPlaceholderTarget.classList.add("hidden")
    this.#showError(message)
    this.#setStreaming(false)
  }

  #appendOptimisticMessage(content) {
    const div = document.createElement("div")
    div.classList.add(
      "self-end",
      "bg-rad-red", "text-rad-cream",
      "px-3", "py-2",
      "rounded-2xl", "rounded-tr-sm",
      "max-w-[82%]", "text-sm", "leading-relaxed", "break-words"
    )
    div.dataset.messageRole = "user"
    div.dataset.optimistic  = "true"
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.#scrollToBottom()
  }

  #setStreaming(value) {
    this.isStreaming = value
    this.inputTarget.disabled      = value
    this.sendButtonTarget.disabled = value
    if (value) {
      this.sendButtonTarget.classList.add("opacity-50")
    } else {
      this.sendButtonTarget.classList.remove("opacity-50")
    }
  }

  #subscribe(conversationId) {
    this.#unsubscribe()
    this.consumer = createConsumer()
    const controller = this

    this.subscription = this.consumer.subscriptions.create(
      { channel: "ConversationChannel", conversation_id: conversationId },
      {
        received(data) {
          controller.#handleReceived(data)
        }
      }
    )
  }

  #unsubscribe() {
    this.subscription?.unsubscribe()
    this.subscription = null
    this.consumer?.disconnect()
    this.consumer = null
  }

  #showError(message) {
    let errorEl = this.element.querySelector("[data-tutor-chat-error]")
    if (!errorEl) {
      errorEl = document.createElement("div")
      errorEl.dataset.tutorChatError = "true"
      errorEl.setAttribute("role", "alert")
      errorEl.classList.add(
        "mx-4", "mb-2", "px-3", "py-2",
        "bg-rad-red/10",
        "border", "border-rad-red/40",
        "text-rad-red",
        "rounded-lg", "text-xs"
      )
      this.inputTarget.closest(".px-4")?.before(errorEl)
    }
    errorEl.textContent = message
    errorEl.classList.remove("hidden")
  }

  #hideError() {
    const errorEl = this.element.querySelector("[data-tutor-chat-error]")
    if (errorEl) errorEl.classList.add("hidden")
  }

  #scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}

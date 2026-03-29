// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "messages", "streaming", "error", "input", "sendButton"]
  static values = {
    createUrl: String,
    messageUrl: String,
    questionId: Number,
    hasApiKey: Boolean,
    settingsUrl: String,
    conversationId: Number
  }

  connect() {
    this.consumer = null
    this.subscription = null
    this.isStreaming = false

    if (this.conversationIdValue) {
      this.subscribeToConversation(this.conversationIdValue)
    }
  }

  disconnect() {
    this.unsubscribe()
  }

  open() {
    if (!this.hasApiKeyValue) {
      if (confirm("Vous devez configurer votre cle IA pour utiliser le tutorat. Aller aux reglages ?")) {
        window.location.href = this.settingsUrlValue
      }
      return
    }

    this.drawerTarget.style.transform = "translateX(0)"
    this.backdropTarget.style.display = "block"

    if (!this.conversationIdValue) {
      this.createConversation()
    }

    this.scrollToBottom()
    this.inputTarget.focus()
  }

  close() {
    this.drawerTarget.style.transform = "translateX(100%)"
    this.backdropTarget.style.display = "none"
  }

  async createConversation() {
    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ question_id: this.questionIdValue })
      })

      if (!response.ok) {
        const data = await response.json()
        this.showError(data.error || "Erreur lors de la creation de la conversation.")
        return
      }

      const data = await response.json()
      this.conversationIdValue = data.conversation_id
      this.subscribeToConversation(data.conversation_id)
    } catch (error) {
      this.showError("Erreur de connexion. Verifiez votre connexion internet.")
    }
  }

  async send() {
    if (this.isStreaming) return

    const content = this.inputTarget.value.trim()
    if (!content) return

    this.inputTarget.value = ""
    this.hideError()
    this.appendUserMessage(content)
    this.setStreaming(true)

    const messageUrl = `/${this.accessCode()}/conversations/${this.conversationIdValue}/message`

    try {
      const response = await fetch(messageUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ content: content })
      })

      if (!response.ok) {
        const data = await response.json()
        this.showError(data.error || "Erreur lors de l'envoi du message.")
        this.setStreaming(false)
      }
    } catch (error) {
      this.showError("Erreur de connexion. Verifiez votre connexion internet.")
      this.setStreaming(false)
    }
  }

  subscribeToConversation(conversationId) {
    this.unsubscribe()

    this.consumer = createConsumer()
    const controller = this

    this.subscription = this.consumer.subscriptions.create(
      { channel: "TutorChannel", conversation_id: conversationId },
      {
        received(data) {
          if (data.token) {
            controller.onToken(data.token)
          } else if (data.done) {
            controller.onDone()
          } else if (data.error) {
            controller.onError(data.error)
          }
        }
      }
    )
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }
  }

  onToken(token) {
    this.streamingTarget.style.display = "block"
    this.streamingTarget.textContent += token
    this.scrollToBottom()
  }

  onDone() {
    const content = this.streamingTarget.textContent
    if (content) {
      this.appendAssistantMessage(content)
    }
    this.streamingTarget.textContent = ""
    this.streamingTarget.style.display = "none"
    this.setStreaming(false)
  }

  onError(message) {
    this.streamingTarget.textContent = ""
    this.streamingTarget.style.display = "none"
    this.showError(message)
    this.setStreaming(false)
  }

  appendUserMessage(content) {
    const div = document.createElement("div")
    div.style.cssText = "align-self: flex-end; background: #7c3aed; color: white; padding: 8px 12px; border-radius: 12px 12px 2px 12px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;"
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  appendAssistantMessage(content) {
    const div = document.createElement("div")
    div.style.cssText = "align-self: flex-start; background: #1e293b; color: #e2e8f0; padding: 8px 12px; border-radius: 12px 12px 12px 2px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;"
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  setStreaming(value) {
    this.isStreaming = value
    this.inputTarget.disabled = value
    this.sendButtonTarget.disabled = value
    this.sendButtonTarget.style.opacity = value ? "0.5" : "1"
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.style.display = "block"
  }

  hideError() {
    this.errorTarget.textContent = ""
    this.errorTarget.style.display = "none"
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  accessCode() {
    return window.location.pathname.split("/")[1]
  }
}

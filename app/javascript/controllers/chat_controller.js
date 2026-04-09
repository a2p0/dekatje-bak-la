// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "messages", "streaming", "error", "input", "sendButton", "toggle"]
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
    this.previouslyFocused = null
    this.element.dataset.chatConnected = "true"

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

    this.previouslyFocused = document.activeElement
    this.drawerTarget.classList.remove("translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    this.updateToggles(true)

    if (!this.conversationIdValue) {
      this.createConversation()
    }

    this.scrollToBottom()
    this.inputTarget.focus()
  }

  close() {
    this.drawerTarget.classList.add("translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    this.updateToggles(false)

    if (this.previouslyFocused && typeof this.previouslyFocused.focus === "function") {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  updateToggles(isOpen) {
    this.toggleTargets.forEach(el => {
      el.setAttribute("aria-expanded", String(isOpen))
    })
  }

  openWithMessage(event) {
    const message = event.params.message || event.currentTarget.dataset.chatMessageParam
    this.open()
    // Wait for drawer to open and conversation to be ready
    setTimeout(() => {
      if (this.hasInputTarget) {
        this.inputTarget.value = message
        this.send()
      }
    }, 500)
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
    this.streamingTarget.classList.remove("hidden")
    this.streamingTarget.textContent += token
    this.scrollToBottom()
  }

  onDone() {
    const content = this.streamingTarget.textContent
    if (content) {
      this.appendAssistantMessage(content)
    }
    this.streamingTarget.textContent = ""
    this.streamingTarget.classList.add("hidden")
    this.setStreaming(false)
  }

  onError(message) {
    this.streamingTarget.textContent = ""
    this.streamingTarget.classList.add("hidden")
    this.showError(message)
    this.setStreaming(false)
  }

  appendUserMessage(content) {
    const div = document.createElement("div")
    div.classList.add(
      "self-end", "bg-indigo-500", "text-white",
      "px-3", "py-2", "rounded-xl", "rounded-br-sm",
      "max-w-[85%]", "text-sm", "leading-relaxed", "break-words"
    )
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  appendAssistantMessage(content) {
    const div = document.createElement("div")
    div.classList.add(
      "self-start", "bg-slate-100", "dark:bg-slate-800",
      "text-slate-800", "dark:text-slate-200",
      "px-3", "py-2", "rounded-xl", "rounded-bl-sm",
      "max-w-[85%]", "text-sm", "leading-relaxed", "break-words"
    )
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  setStreaming(value) {
    this.isStreaming = value
    this.inputTarget.disabled = value
    this.sendButtonTarget.disabled = value
    if (value) {
      this.sendButtonTarget.classList.add("opacity-50")
    } else {
      this.sendButtonTarget.classList.remove("opacity-50")
    }
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
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

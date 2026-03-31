import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.applyTheme()
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.mediaQuery.addEventListener("change", this.handleSystemChange)
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.handleSystemChange)
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    if (isDark) {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("theme", "light")
    } else {
      document.documentElement.classList.add("dark")
      localStorage.setItem("theme", "dark")
    }
  }

  applyTheme() {
    const stored = localStorage.getItem("theme")
    if (stored === "light") {
      document.documentElement.classList.remove("dark")
    } else if (stored === "dark") {
      document.documentElement.classList.add("dark")
    } else {
      // No override — follow system preference, default to dark
      if (window.matchMedia("(prefers-color-scheme: light)").matches) {
        document.documentElement.classList.remove("dark")
      } else {
        document.documentElement.classList.add("dark")
      }
    }
  }

  handleSystemChange = () => {
    if (!localStorage.getItem("theme")) {
      this.applyTheme()
    }
  }
}

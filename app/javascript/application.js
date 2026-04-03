// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@rails/actioncable"

// Custom Turbo confirm dialog — avoids browser showing the page origin (IP/localhost)
Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    const dialog = document.createElement("dialog")
    dialog.className = "rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-6 max-w-sm shadow-xl backdrop:bg-black/50"
    dialog.innerHTML = `
      <p class="text-sm text-slate-800 dark:text-slate-200 mb-4">${message}</p>
      <div class="flex justify-end gap-2">
        <button value="cancel" class="px-4 py-2 text-sm font-semibold rounded-lg border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer">Annuler</button>
        <button value="confirm" class="px-4 py-2 text-sm font-semibold rounded-lg bg-indigo-500 text-white hover:bg-indigo-600 cursor-pointer">Confirmer</button>
      </div>
    `
    document.body.appendChild(dialog)
    dialog.showModal()

    dialog.addEventListener("click", (event) => {
      if (event.target.value === "confirm") {
        resolve(true)
        dialog.close()
        dialog.remove()
      } else if (event.target.value === "cancel" || event.target === dialog) {
        resolve(false)
        dialog.close()
        dialog.remove()
      }
    })

    dialog.addEventListener("close", () => {
      resolve(false)
      dialog.remove()
    })
  })
})

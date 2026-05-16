# Phase 1 — UI Contracts: Desktop Question Layout

**Feature** : 064-desktop-question-layout
**Date** : 2026-05-11

Ces contrats définissent les attentes DOM et événements entre les composants HTML/Stimulus de la feature. Toute modification doit préserver ces contrats sous peine de régression.

## C1 — Coordination overlays (Parties ↔ Tibo)

### Contrat événementiel

Les controllers `sidebar` et `chat_drawer` communiquent via deux événements `CustomEvent` dispatché sur `window` :

| Événement | Émetteur | Récepteur | `detail` payload |
|---|---|---|---|
| `overlay:open` | celui qui s'ouvre | les autres | `{name: "sidebar"}` OU `{name: "tibo"}` |
| `overlay:close` | celui qui se ferme | (informatif) | `{name: "sidebar"}` OU `{name: "tibo"}` |

### Comportement attendu

- À la réception de `overlay:open` avec `name !== ownName`, fermer l'overlay courant.
- L'émission de `overlay:open` est synchrone, dans la méthode `open()` du controller.
- L'émission de `overlay:close` est synchrone, dans la méthode `close()`.

### Implémentation candidate (sidebar_controller.js)

```javascript
open() {
  this.previouslyFocused = document.activeElement
  this.drawerTarget.classList.remove("-translate-x-full")
  this.drawerTarget.classList.add("translate-x-0")
  this.backdropTarget.classList.remove("hidden")
  this.updateToggles(true)

  window.dispatchEvent(new CustomEvent("overlay:open", { detail: { name: "sidebar" } }))

  const firstFocusable = this.drawerTarget.querySelector('a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])')
  if (firstFocusable) firstFocusable.focus()
}

connect() {
  this.previouslyFocused = null
  this._overlayHandler = (e) => {
    if (e.detail?.name && e.detail.name !== "sidebar") this.close()
  }
  window.addEventListener("overlay:open", this._overlayHandler)
}

disconnect() {
  window.removeEventListener("overlay:open", this._overlayHandler)
}
```

Et symétriquement dans `chat_drawer_controller.js`.

## C2 — Structure DOM `_desktop_nav.html.erb`

```html
<nav class="hidden lg:flex ..." aria-label="Navigation élève">
  <!-- Stripes martiniquaises 5px -->
  <div class="flex h-1">...</div>

  <!-- Bar principale -->
  <div class="flex items-center justify-between px-8 h-13">
    <!-- Logo + tabs -->
    <div class="flex items-center gap-7">
      <span class="font-serif italic ...">DekatjeBakLa</span>
      <div class="flex gap-1">
        <a href="..." class="...">Mes sujets</a>
        <a href="..." class="...">Progression</a>
        <a href="..." class="...">Réglages</a>
      </div>
    </div>

    <!-- Right cluster -->
    <div class="flex items-center gap-3">
      <button data-action="click->sidebar#open" data-sidebar-target="toggle">Parties</button>
      <button data-action="click->tutor-activator#activate" data-chat-drawer-toggle="true">Tibo</button>
      <div class="avatar">L</div>
    </div>
  </div>
</nav>
```

**Contraintes** :
- `data-action="click->sidebar#open"` doit cibler le sidebar_controller monté sur `questions/show`. Bonus : le partial est rendu dans le `<main>` du layout (extérieur à l'élément Stimulus). Solution : utiliser un outlet ou délégation via `data-action="click@window->sidebar#open"`. À résoudre en implémentation. **Recommandation TDD** : commencer par un test feature qui clique sur "Parties", observer où Stimulus accroche.
- Avatar = initiale du `current_student.first_name` (helper).

## C3 — Structure DOM `_dt_viewer.html.erb`

```html
<aside class="hidden lg:flex lg:flex-col lg:w-1/2 border-l border-rad-rule" aria-label="Document technique">
  <% if @subject.dt_file.attached? && @question.dt_references.present? %>
    <!-- Bandeau références -->
    <div class="px-4 py-2 border-b border-rad-rule flex flex-wrap gap-2 bg-rad-paper">
      <% (@question.dt_references | @question.dr_references).each do |ref| %>
        <span class="...">DT/DR badge</span>
      <% end %>
    </div>

    <!-- Bandeau "Donnée utile" (correction seulement) -->
    <% if local_assigns[:show_data_hint] && primary_data_hint(@question) %>
      <%= render "data_hint_banner", hint: primary_data_hint(@question) %>
    <% end %>

    <!-- Iframe PDF -->
    <iframe src="<%= rails_blob_url(@subject.dt_file) %>"
            class="flex-1 w-full border-0"
            title="Document Technique <%= @subject.title %>"
            loading="lazy"></iframe>
  <% else %>
    <div class="flex-1 flex items-center justify-center text-rad-muted text-sm">
      Aucun document technique pour cette question
    </div>
  <% end %>
</aside>
```

## C4 — Structure DOM drawer Tibo desktop (60/40)

Le drawer existant à `_drawer.html.erb` doit être adapté pour exposer un second pane à `lg:`.

```html
<div id="tutor-chat-drawer"
     class="fixed top-0 right-0 bottom-0 w-full lg:w-[60vw] lg:max-w-[900px] bg-rad-bg border-l border-rad-rule z-50 translate-x-full transition-transform duration-200 ease-in-out
            lg:flex">

  <!-- Pane chat (existing content) -->
  <div class="flex-1 flex flex-col lg:basis-3/5">
    <!-- header, messages, chips, input — existing markup unchanged -->
  </div>

  <!-- Pane contexte (desktop only) -->
  <aside class="hidden lg:flex lg:flex-col lg:basis-2/5 border-l border-rad-rule bg-rad-paper">
    <%= render "context_panel", question: question, part: question.part, subject: question.part.subject %>
  </aside>
</div>
```

**Contraintes** :
- Mobile : seul le pane chat est visible (`hidden lg:flex` sur le pane contexte).
- Desktop : le drawer prend 60vw min(900px), le chat occupe 60% (`basis-3/5`), le contexte 40% (`basis-2/5`).

## C5 — Données pour `_context_panel.html.erb`

Locals attendus :
- `question` : `Question` (utilise `.label`, `.number`)
- `part` : `Part` (utilise `.title`, `.objective_text`, `.section_type`, `.number`)
- `subject` : `Subject` (utilise `.title`, `.presentation_text` éventuellement)

Output minimal :
- Rappel question (numéro + label tronqué)
- Bloc partie (numéro + titre + objectif)
- Lien "Voir la question complète" qui ferme le drawer et focus la question (Stimulus existant)

## C6 — Sidebar comme popover desktop

`_sidebar.html.erb` est rendu inchangé dans `show.html.erb`. La bascule de comportement est dans `show.html.erb` :

```erb
<aside id="sidebar-drawer"
       data-sidebar-target="drawer"
       data-controller="focus-trap"
       aria-label="Navigation du sujet"
       class="w-[260px] bg-rad-paper border-r border-rad-rule flex-shrink-0 overflow-y-auto
              fixed top-0 left-0 bottom-0 z-[var(--z-sidebar)] -translate-x-full transition-transform duration-200
              lg:fixed lg:translate-x-full">  <!-- ⚠️ CHANGED from lg:relative lg:translate-x-0 -->
  <%= render "student/questions/sidebar", ... %>
</aside>
```

Et le bouton `≡` mobile et "Parties" desktop appellent tous deux `sidebar#open`.

## C7 — Specs feature attendues

| Spec file | User Story | Driver | Window size |
|---|---|---|---|
| `student_desktop_reading_spec.rb` | US1 | `:headless_chrome` | 1400×900 (default) |
| `student_desktop_correction_spec.rb` | US2 | `:headless_chrome` | 1400×900 |
| `student_desktop_tutor_spec.rb` | US3 | `:headless_chrome` | 1400×900 |
| `student_desktop_navigation_spec.rb` | US4 | `:headless_chrome` | 1400×900 |
| `student_question_navigation_spec.rb` (existing) | Régression mobile | `:headless_chrome` resize 390×800 dans `before(:each)` | 390×800 ou 1400×900 selon scénario |

**Scenarios par spec** :
- US1 : visite question avec DT → assert présence DT viewer iframe + bandeau "DT1" + carte question dans colonne gauche.
- US2 : marquer répondu, visite correction → assert carte verte (réponse), carte verte (calcul), carte jaune (data hints) + bandeau "Donnée utile" dans DT viewer.
- US3 : clic bouton Tibo navbar → assert drawer ouvert avec 2 panes visibles (chat + contexte), question label visible dans le contexte.
- US4 : clic bouton Parties navbar → assert sidebar visible avec liste parties/questions ; clic question → navigation OK + sidebar fermée.

## C8 — Préservation des contrats existants

- `tutor-activator` continue à émettre `tutor:drawer-open` — `chat_drawer_controller` continue d'écouter.
- `focus-trap` continue à émettre `focus-trap:close` — `sidebar_controller` continue d'écouter pour fermer.
- `data-chat-drawer-toggle="true"` continue à recevoir `aria-expanded` toggling.

# Design — Chips contextuelles dans le drawer Tibo

**Date** : 2026-05-04  
**Branche cible** : 059-tutor-chips (à créer depuis main)  
**Contexte** : Feature issue du design Radical (mockup `tmp/Dekatje-handoff(1)`), qui corrige également les 3 scenarios `pending:` dans `student_tutor_full_flow_spec.rb` (lignes 157/182/199).

---

## Objectif

Remplacer les chips statiques du mockup Radical par des chips dynamiques dans le drawer de Tibo. Les chips sont calculées côté serveur en fonction de la phase courante du tuteur (`TutorState#current_phase`) et du compteur d'indices (`hints_used`). Elles s'insèrent dans le fil des messages (inline, après le dernier message de Tibo) et se mettent à jour à chaque fin de tour.

---

## Mapping phase → chips

| Phase | Chips affichées |
|---|---|
| `idle` / pas de conversation | Aucune chip |
| `greeting` / `enonce` | "Reformule la question" (teal), "Définis un terme" (red) |
| `spotting_type` / `spotting_data` | "Donne un exemple" (yellow), "Reformule la question" (teal) |
| `guiding` (hints_used < 5) | "Un indice" (yellow), "Reformule" (teal), "Définis" (red) |
| `guiding` (hints_used = 5) | "Reformule" (teal), "Définis" (red), "Un indice" (grisé, disabled) |
| `validating` | 5 chips confidence empilées (😰 Pas du tout sûr → 💪 Très sûr) — input désactivé |
| `feedback` / `ended` | "Explique la correction" (teal), "Question suivante →" (navigate) |

---

## Architecture

### 1. Frame Turbo `tutor-chips`

Dans `_drawer.html.erb`, entre la zone messages et l'input bar :

```erb
<turbo-frame id="tutor-chips" class="shrink-0">
  <%= render "student/conversations/chips", conversation: conversation, question: question, access_code: access_code %>
</turbo-frame>
```

Vide si pas de conversation (`conversation.nil?`). Pré-rempli au chargement initial depuis `TutorState` courant.

### 2. Presenter `Tutor::ChipsPresenter`

`app/services/tutor/chips_presenter.rb` — calcule la liste de chip descriptors à partir de `phase` et `hints_used` :

```ruby
Tutor::ChipsPresenter.call(
  phase:      tutor_state.current_phase,
  hints_used: tutor_state.question_states[question_id]&.hints_used.to_i,
  conversation: conversation,
  question:   question,
  access_code: access_code
)
# => Array<Hash> : { label:, action: (:send | :confidence | :navigate), ... }
```

### 3. Partial `_chips.html.erb`

`app/views/student/conversations/_chips.html.erb` — itère sur les descriptors et rend les bons éléments :

- **`action: :send`** → `<button data-chip-action="send" data-chip-text="...">` pill shape, left border coloré
- **`action: :confidence`** → `<button data-chip-action="confidence" data-chip-level="N">` stacked, left border coloré
- **`action: :navigate`** → `<a href="...">` pill shape, left border coloré
- **`disabled: true`** → opacity-40, cursor-not-allowed, pointer-events-none

Design visuel : fond `rad-paper`, border `rad-rule`, `border-left: 3px solid <color>`, pill (`rounded-full`) pour les chips normales, rectangle arrondi (`rounded-lg`) pour les chips confidence.

### 4. Cycle de vie : vider au début, remplir à la fin

**Début du stream** — dans `tutor_chat_controller.js`, méthode `send()` après `#setStreaming(true)` :

```js
const chipsFrame = document.getElementById("tutor-chips")
if (chipsFrame) chipsFrame.innerHTML = ""
```

**Fin du stream** — `BroadcastMessage` ajoute `chips_html` au payload `done` :

```ruby
ActionCable.server.broadcast("conversation_#{@conversation.id}", {
  type: "done",
  message: { ... },
  chips_html: render_chips_html   # via ApplicationController.renderer
})
```

Dans `tutor_chat_controller.js`, `#onDone` :

```js
const chipsFrame = document.getElementById("tutor-chips")
if (chipsFrame && data.chips_html) chipsFrame.innerHTML = data.chips_html
```

### 5. Trois comportements au clic

Gérés par `tutor_chat_controller.js` (méthode `handleChipClick`) :

| `data-chip-action` | Comportement |
|---|---|
| `send` | Prend `data-chip-text`, l'injecte comme contenu du message, appelle `send()` directement (pas de pré-remplissage input) |
| `confidence` | PATCH `confidence_student_conversation_path` avec `data-chip-level`. Réutilise la logique de `confidence_form_controller.js` (inline dans tutor-chat ou délégation) |
| `navigate` | Lien `<a href>` classique, pas de JS nécessaire |

### 6. Phase `validating` : input désactivé

Quand `phase == "validating"` :
- L'input reste dans le DOM mais est `disabled`
- Le placeholder de l'input change en "Réponds via les chips ci-dessus…"
- Les chips confidence sont rendues dans le frame `tutor-chips`
- Après le PATCH confidence → le serveur répond avec un Turbo Stream qui met à jour le frame `tutor-chips` avec les chips de la phase `feedback`

### 7. Rendu HTML dans BroadcastMessage

`BroadcastMessage` utilise `ApplicationController.renderer` pour rendre le partial :

```ruby
renderer = ApplicationController.renderer.new(
  http_host: Rails.application.routes.default_url_options[:host]
)
chips_html = renderer.render(
  partial: "student/conversations/chips",
  locals: { conversation: @conversation, question: @question, access_code: @access_code }
)
```

`BroadcastMessage` reçoit `question` et `access_code` en paramètre supplémentaire (breaking change interne — callers à mettre à jour).

---

## Fichiers touchés

| Fichier | Changement |
|---|---|
| `app/views/student/conversations/_drawer.html.erb` | Ajout du frame `tutor-chips` entre messages et input |
| `app/views/student/conversations/_chips.html.erb` | Nouveau partial |
| `app/services/tutor/chips_presenter.rb` | Nouveau service |
| `app/services/tutor/broadcast_message.rb` | Ajoute `chips_html` au payload, reçoit `question` + `access_code` |
| `app/services/tutor/process_message.rb` | Passe `question` + `access_code` à `BroadcastMessage` |
| `app/javascript/controllers/tutor_chat_controller.js` | Vide chips au début, injecte chips à `#onDone`, gère `handleChipClick` |
| `spec/features/student_tutor_full_flow_spec.rb` | Supprimer les 3 `pending:` (lignes 157/182/199), les scenarios passent |

---

## Tests

- Specs Capybara feature couvrant chaque phase (au moins `guiding`, `validating`, `feedback`)
- Spec unitaire `Tutor::ChipsPresenter` : vérifie le mapping phase → chips, le disabled à MAX_HINTS
- Les 3 scenarios `pending:` dans `student_tutor_full_flow_spec.rb` doivent passer sans modification (sauf suppression du `pending:`)

---

## Non-scope

- Animation ou transition CSS des chips
- Persistance de l'état "chip cliquée" (les chips disparaissent au prochain send)
- Chips sur mobile (le drawer est déjà responsive, pas de traitement spécifique)

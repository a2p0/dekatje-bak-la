# Tutor Drawer — Radical Reskin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrer le drawer tutorat (`_drawer.html.erb`, `_message.html.erb`, `_confidence_form.html.erb`) des tokens slate/indigo vers le design system Radical, sans toucher à aucune logique Stimulus.

**Architecture:** Reskin visuel pur — seules les classes CSS et la structure HTML des 3 partials sont modifiées. Le pattern madras diagonal est ajouté comme classe utilitaire CSS dans `application.css`. Les data-attributes Stimulus restent intacts.

**Tech Stack:** Rails 8.1 ERB, Tailwind CSS 4 (tokens `rad-*` existants), RSpec + Capybara (specs feature existantes).

---

## Fichiers touchés

| Fichier | Action |
|---|---|
| `app/assets/tailwind/application.css` | Modifier — ajouter `.pattern-madras-diagonal` (light + dark) |
| `app/views/student/conversations/_drawer.html.erb` | Modifier — reskin complet |
| `app/views/student/conversations/_message.html.erb` | Modifier — reskin bulles |
| `app/views/student/conversations/_confidence_form.html.erb` | Modifier — reskin form |
| `app/javascript/controllers/tutor_chat_controller.js` | Modifier — classes CSS hardcodées dans les bulles dynamiques |
| `spec/features/student_tutor_chat_spec.rb` | Modifier si nécessaire — vérifier sélecteurs |

---

## Task 1 : Classe CSS `.pattern-madras-diagonal`

**Fichiers :**
- Modifier : `app/assets/tailwind/application.css`

La classe existante `.pattern-madras` utilise des croisillons droits (0°/90°). Le design Radical du drawer prescrit des diagonales à 45° avec des couleurs rouge/teal très transparentes, différentes en light et dark.

- [ ] **Ouvrir** `app/assets/tailwind/application.css` et ajouter après `.pattern-madras` (ligne ~75) :

```css
/* Diagonal madras pattern for tutor drawer — light and dark variants */
.pattern-madras-diagonal {
  background-image:
    repeating-linear-gradient(45deg,  rgba(212,69,46,0.06)  0 1px, transparent 1px 22px),
    repeating-linear-gradient(-45deg, rgba(212,69,46,0.06)  0 1px, transparent 1px 22px),
    repeating-linear-gradient(45deg,  rgba(18,117,102,0.05) 0 1px, transparent 1px 7px),
    repeating-linear-gradient(-45deg, rgba(18,117,102,0.05) 0 1px, transparent 1px 7px);
}

.dark .pattern-madras-diagonal {
  background-image:
    repeating-linear-gradient(45deg,  rgba(255,255,255,0.04)  0 1px, transparent 1px 22px),
    repeating-linear-gradient(-45deg, rgba(255,255,255,0.04)  0 1px, transparent 1px 22px),
    repeating-linear-gradient(45deg,  rgba(255,255,255,0.025) 0 1px, transparent 1px 7px),
    repeating-linear-gradient(-45deg, rgba(255,255,255,0.025) 0 1px, transparent 1px 7px);
}
```

- [ ] **Commit :**

```bash
git add app/assets/tailwind/application.css
git commit -m "style(css): add pattern-madras-diagonal utility for tutor drawer"
```

---

## Task 2 : Reskin `_message.html.erb`

**Fichiers :**
- Modifier : `app/views/student/conversations/_message.html.erb`

C'est le plus petit fichier — bien commencer par lui pour valider les tokens avant d'attaquer le drawer.

- [ ] **Remplacer** le contenu complet de `_message.html.erb` par :

```erb
<% role = message.role.to_s %>

<% if role == "user" %>
  <div class="self-end bg-rad-red text-rad-cream px-3 py-2 rounded-2xl rounded-tr-sm max-w-[82%] text-sm leading-relaxed break-words"
       data-message-id="<%= message.id %>"
       data-message-role="user">
    <%= message.content %>
  </div>

<% elsif role == "assistant" %>
  <div class="flex gap-2.5 items-start max-w-[86%]"
       data-message-id="<%= message.id %>"
       data-message-role="assistant">
    <div class="w-7 h-7 rounded-full bg-rad-red flex-shrink-0 flex items-center justify-center">
      <span class="font-serif italic text-[13px] text-rad-cream">T</span>
    </div>
    <div class="bg-rad-paper border border-rad-rule px-3 py-2 rounded-2xl rounded-tl-sm text-sm leading-relaxed text-rad-text break-words">
      <%= message.content %>
    </div>
  </div>

<% elsif role == "system" %>
  <div class="self-center text-xs italic text-rad-muted text-center max-w-[85%]"
       data-message-id="<%= message.id %>"
       data-message-role="system">
    <%= message.content %>
  </div>
<% end %>
```

- [ ] **Commit :**

```bash
git add app/views/student/conversations/_message.html.erb
git commit -m "style(tutor): Radical message bubbles — red/cream user, paper/rule assistant"
```

---

## Task 3 : Reskin `_confidence_form.html.erb`

**Fichiers :**
- Modifier : `app/views/student/conversations/_confidence_form.html.erb`

- [ ] **Remplacer** le contenu complet de `_confidence_form.html.erb` par :

```erb
<%= turbo_frame_tag "confidence-form-#{question_id}" do %>
  <div class="self-start mt-2 bg-rad-paper border border-rad-rule rounded-2xl p-4 max-w-[90%]"
       data-controller="confidence-form"
       data-confidence-form-url-value="<%= confidence_student_conversation_path(access_code: access_code, id: conversation.id) %>">
    <p class="text-xs font-semibold text-rad-muted mb-3">
      À quel point étais-tu sûr(e) de ta réponse ?
    </p>
    <div class="flex gap-2 flex-wrap">
      <% confidence_labels = {
        1 => "Très peu sûr",
        2 => "Peu sûr",
        3 => "Moyennement sûr",
        4 => "Assez sûr",
        5 => "Très sûr"
      } %>
      <% (1..5).each do |level| %>
        <button type="button"
                value="<%= level %>"
                data-confidence-form-target="button"
                data-action="click->confidence-form#submit"
                title="<%= confidence_labels[level] %>"
                class="w-9 h-9 rounded-full border border-rad-rule text-sm font-semibold text-rad-muted bg-rad-paper hover:bg-rad-raise hover:border-rad-teal hover:text-rad-teal transition-colors cursor-pointer">
          <%= level %>
        </button>
      <% end %>
    </div>
    <p class="text-[10px] text-rad-muted mt-2">
      1 = <%= confidence_labels[1] %> &nbsp;·&nbsp; 5 = <%= confidence_labels[5] %>
    </p>
  </div>
<% end %>
```

- [ ] **Commit :**

```bash
git add app/views/student/conversations/_confidence_form.html.erb
git commit -m "style(tutor): Radical confidence form — rad-paper, teal hover"
```

---

## Task 4 : Reskin `_drawer.html.erb`

**Fichiers :**
- Modifier : `app/views/student/conversations/_drawer.html.erb`

C'est le fichier principal. La structure change significativement dans le header (stripes + avatar + chip) et l'input bar.

- [ ] **Remplacer** le contenu complet de `_drawer.html.erb` par :

```erb
<%#
  Locals:
    conversation (Conversation | nil)
    question     (Question)
    access_code  (String)
%>

<div data-chat-drawer-target="backdrop"
     data-action="click->chat-drawer#close"
     class="hidden fixed inset-0 bg-black/50 z-40">
</div>

<div id="tutor-chat-drawer"
     data-chat-drawer-target="drawer"
     data-controller="<%= conversation ? 'tutor-chat' : '' %>"
     <% if conversation %>
       data-tutor-chat-conversation-id-value="<%= conversation.id %>"
       data-tutor-chat-messages-url-value="<%= messages_student_conversation_path(access_code: access_code, id: conversation.id) %>"
       data-tutor-chat-question-id-value="<%= question.id %>"
     <% end %>
     role="dialog"
     aria-modal="true"
     aria-label="Tutorat IA"
     aria-hidden="true"
     class="fixed top-0 right-0 bottom-0 w-full lg:w-[420px] bg-rad-bg border-l border-rad-rule z-50 translate-x-full transition-transform duration-200 ease-in-out flex flex-col">

  <%# Header — "espace Tibo" %>
  <div class="bg-[#e8e0cc] dark:bg-rad-raise shrink-0">
    <%# Stripes martiniquaises 4px %>
    <div class="flex h-1">
      <div class="flex-1 bg-rad-red"></div>
      <div class="flex-1 bg-rad-yellow"></div>
      <div class="flex-1 bg-rad-teal"></div>
      <div class="flex-1 bg-rad-ink"></div>
    </div>

    <div class="px-4 py-3 flex items-center gap-3">
      <%# Bouton fermeture %>
      <button type="button"
              data-action="click->chat-drawer#close"
              aria-label="Fermer le tutorat"
              class="text-rad-text opacity-70 text-[22px] leading-none bg-transparent border-none cursor-pointer flex-shrink-0 p-0">
        ‹
      </button>

      <%# Avatar Tibo %>
      <div class="relative flex-shrink-0">
        <div class="w-10 h-10 rounded-full bg-rad-red flex items-center justify-center">
          <span class="font-serif italic text-[19px] text-rad-cream leading-none">T</span>
        </div>
        <span class="absolute bottom-[1px] right-[1px] w-2.5 h-2.5 rounded-full bg-rad-teal border-2 border-[#e8e0cc] dark:border-rad-raise"></span>
      </div>

      <%# Titre + sous-titre %>
      <div class="flex-1 min-w-0">
        <div class="font-serif italic text-[17px] text-rad-text leading-none">Tibo, ton tuteur</div>
        <div class="text-[11px] text-rad-muted mt-[3px]">Sur la Q<%= question.number %> · ne donne pas la réponse</div>
      </div>

      <%# Chip question %>
      <span class="flex-shrink-0 text-[11px] font-bold px-2 py-1 rounded-lg bg-black/[.07] dark:bg-white/10 text-rad-muted">
        Q<%= question.number %> ↗
      </span>
    </div>
  </div>

  <%# Zone messages %>
  <div id="tutor-chat-messages"
       data-tutor-chat-target="messages"
       class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 bg-rad-bg pattern-madras-diagonal">
    <% if conversation&.messages&.any? %>
      <% conversation.messages.order(:created_at).each do |msg| %>
        <%= render "student/conversations/message", message: msg %>
      <% end %>
    <% else %>
      <div class="text-rad-muted text-sm text-center mt-10">
        Posez votre question pour commencer le tutorat.
      </div>
    <% end %>
  </div>

  <%# Streaming placeholder — target unique (le controller écrit textContent dessus directement) %>
  <%# Pas d'avatar T ici : le controller JS fait classList.remove("hidden") sur ce div %>
  <div data-tutor-chat-target="streamingPlaceholder"
       aria-live="polite"
       class="hidden self-start bg-rad-paper border border-rad-rule text-rad-text px-3 py-2 rounded-2xl rounded-tl-sm max-w-[85%] text-sm leading-relaxed mx-4 mb-3 break-words">
  </div>

  <%# Input bar %>
  <div class="px-4 py-3 border-t border-rad-rule shrink-0 bg-[#e8e0cc] dark:bg-rad-raise">
    <div class="flex items-center gap-2 px-4 py-[6px] rounded-full bg-rad-paper border border-rad-rule">
      <label for="tutor-chat-input" class="sr-only">Écrivez votre question au tuteur</label>
      <input data-tutor-chat-target="input"
             data-action="keydown.enter->tutor-chat#send"
             type="text"
             id="tutor-chat-input"
             aria-label="Écrivez votre question au tuteur"
             placeholder="Écris à Tibo…"
             <% unless conversation %>disabled<% end %>
             class="flex-1 border-none outline-none bg-transparent text-sm text-rad-text placeholder:text-rad-muted py-2 disabled:opacity-50"
             autocomplete="off">
      <button type="button"
              data-tutor-chat-target="sendButton"
              data-action="click->tutor-chat#send"
              aria-label="Envoyer"
              <% unless conversation %>disabled<% end %>
              class="w-10 h-10 rounded-full bg-rad-red text-rad-cream border-0 flex items-center justify-center text-[16px] cursor-pointer flex-shrink-0 disabled:opacity-50 disabled:cursor-not-allowed">
        ↑
      </button>
    </div>
  </div>
</div>
```

- [ ] **Commit :**

```bash
git add app/views/student/conversations/_drawer.html.erb
git commit -m "style(tutor): Radical drawer — Tibo header, madras bg, red/cream input"
```

---

## Task 5 : Correction classes JS hardcodées dans `tutor_chat_controller.js`

**Fichiers :**
- Modifier : `app/javascript/controllers/tutor_chat_controller.js`

Le controller crée dynamiquement des bulles (bulle user optimiste + bulle assistant finale) avec des classes CSS hardcodées slate/indigo. Ces divs ne passent pas par les partials ERB — il faut les corriger ici pour que le streaming et les messages optimistes s'affichent en Radical.

- [ ] **Modifier `#appendOptimisticMessage`** — remplacer les classes indigo par Radical :

Avant (lignes ~129-133) :
```js
div.classList.add(
  "self-end",
  "bg-gradient-to-br", "from-indigo-500", "to-violet-500",
  "text-white", "px-3", "py-2",
  "rounded-2xl", "rounded-br-sm",
  "max-w-[85%]", "text-sm", "leading-relaxed", "break-words"
)
```

Après :
```js
div.classList.add(
  "self-end",
  "bg-rad-red", "text-rad-cream",
  "px-3", "py-2",
  "rounded-2xl", "rounded-tr-sm",
  "max-w-[82%]", "text-sm", "leading-relaxed", "break-words"
)
```

- [ ] **Modifier `#onDone`** — remplacer les classes slate par Radical :

Avant (lignes ~95-101) :
```js
div.classList.add(
  "self-start",
  "bg-slate-100", "dark:bg-slate-800",
  "text-slate-800", "dark:text-slate-200",
  "px-3", "py-2",
  "rounded-2xl", "rounded-bl-sm",
  "max-w-[85%]", "text-sm", "leading-relaxed", "break-words"
)
```

Après :
```js
div.classList.add(
  "self-start",
  "bg-rad-paper", "border", "border-rad-rule",
  "text-rad-text",
  "px-3", "py-2",
  "rounded-2xl", "rounded-tl-sm",
  "max-w-[86%]", "text-sm", "leading-relaxed", "break-words"
)
```

- [ ] **Commit :**

```bash
git add app/javascript/controllers/tutor_chat_controller.js
git commit -m "style(tutor): Radical tokens in dynamic JS message bubbles"
```

---

## Task 7 : Mise à jour spec feature

**Fichiers :**
- Modifier : `spec/features/student_tutor_chat_spec.rb`

Le bouton fermeture passe de `✕` à `‹` mais garde `aria-label="Fermer le tutorat"` — la spec utilise ce sélecteur, elle reste valide. Vérification que rien ne casse.

- [ ] **Lancer les specs tutor chat** :

```bash
bundle exec rspec spec/features/student_tutor_chat_spec.rb --format documentation
```

Résultat attendu : toutes les specs passent (les sélecteurs `aria-label` sont inchangés).

- [ ] **Si une spec échoue** : lire le message d'erreur et corriger le sélecteur dans le fichier de spec correspondant (probablement un sélecteur de classe CSS slate/indigo hardcodé).

- [ ] **Lancer la suite complète** :

```bash
bundle exec rspec spec/features/ --format progress
```

Résultat attendu : 0 failure.

- [ ] **Commit si des specs ont été modifiées** :

```bash
git add spec/features/student_tutor_chat_spec.rb
git commit -m "test(tutor): update drawer spec selectors for Radical reskin"
```

---

## Task 8 : Vérification visuelle + PR

- [ ] **Lancer le serveur** :

```bash
bin/dev
```

- [ ] **Ouvrir** un sujet avec tutorat activé (student connecté avec `api_key` renseignée). Vérifier :
  - [ ] Header : stripes 4px, avatar T rouge, dot teal, titre serif, chip Q{number}
  - [ ] Zone messages : fond `rad-bg` + diagonales madras visibles (subtiles)
  - [ ] Bulle user : rouge uni `rad-red`, radius `rounded-tr-sm`
  - [ ] Bulle Tibo : blanche avec border, avatar T 28px à gauche, radius `rounded-tl-sm`
  - [ ] Input bar : fond beige chaud, champ pill blanc, bouton rond rouge ↑
  - [ ] Dark mode : passer en dark et vérifier que les tokens dark sont corrects (header `rad-raise`, madras blanc transparent)
  - [ ] Fermeture ‹ : ferme bien le drawer

- [ ] **Créer la branche et la PR** :

```bash
git checkout -b 056-tutor-drawer-radical
git push -u origin 056-tutor-drawer-radical
gh pr create \
  --title "style(tutor): Radical drawer — Tibo header, madras bg, Radical tokens" \
  --body "$(cat <<'EOF'
## Summary

- Reskin complet du drawer tutorat vers le design system Radical
- Header « espace Tibo » : stripes martiniquaises, avatar T rouge, dot teal online, chip numéro question
- Zone messages : fond \`rad-bg\` + pattern madras diagonal (diagonales 45°, croisé rouge/teal très transparents)
- Bulles : user \`rad-red/cream\`, Tibo \`rad-paper/rule\` avec avatar T 28px
- Input bar : fond beige chaud \`#e8e0cc\` / \`rad-raise\` dark, champ pill, bouton send rond ↑
- Confidence form : \`rad-paper/rule\`, hover \`rad-teal\`
- Aucun changement de logique Stimulus, routes ou modèles

## Test plan

- [ ] Specs feature tutor passent (`bundle exec rspec spec/features/student_tutor_chat_spec.rb`)
- [ ] Suite complète spec/features/ : 0 failure
- [ ] Vérification visuelle drawer light + dark mode
- [ ] Fermeture ‹ fonctionnelle
EOF
)"
```

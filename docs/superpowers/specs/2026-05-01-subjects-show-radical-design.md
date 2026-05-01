# subjects/show — Radical design

**Date :** 2026-05-01
**Scope :** Reskin des 7 vues ERB de `student/subjects/` + 1 nouveau Stimulus controller + 2 nouveaux partials partagés
**Branche cible :** 054-subjects-show-radical → main via PR
**Dépendance :** PR #75 (design tokens Radical) mergée sur main ✅

---

## Contexte

PR 2 de la série de 5 redesign Radical. Couvre `subjects#show` et ses 6 états conditionnels. La PR tokens est en place — les classes `bg-rad-bg`, `text-rad-text`, `font-serif`, `font-mono`, `pattern-madras`, `scroll-hide` sont disponibles.

Aucun controller Rails modifié. Aucune migration. Reskin pur + 1 Stimulus controller.

---

## Fichiers touchés

| Action | Fichier |
|---|---|
| Modifier | `app/views/student/subjects/show.html.erb` |
| Modifier | `app/views/student/subjects/_scope_selection.html.erb` |
| Modifier | `app/views/student/subjects/_part_row.html.erb` |
| Modifier | `app/views/student/subjects/_specific_presentation.html.erb` |
| Modifier | `app/views/student/subjects/_unanswered_questions.html.erb` |
| Modifier | `app/views/student/subjects/_completion.html.erb` |
| Modifier | `app/views/student/tutor/_tutor_banner.html.erb` |
| Créer | `app/views/student/subjects/_stripes.html.erb` |
| Créer | `app/views/student/subjects/_subject_header.html.erb` |
| Créer | `app/javascript/controllers/scope_selector_controller.js` |
| Modifier | `spec/features/student/subject_workflow_spec.rb` |

---

## Partials partagés (nouveaux)

### `_stripes.html.erb`

Bande 4 couleurs en tête de chaque écran (hauteur 6px) :

```erb
<div class="flex h-1.5" aria-hidden="true">
  <div class="flex-1 bg-rad-red"></div>
  <div class="flex-1 bg-rad-yellow"></div>
  <div class="flex-1 bg-rad-teal"></div>
  <div class="flex-1 bg-rad-ink"></div>
</div>
```

### `_subject_header.html.erb`

Locals : `back_path` (String), `suptitle` (String, ex: "BAC STI2D · SIN"), `title` (String, nom du sujet).

Header compact mobile-first :

```erb
<div class="px-5 py-3.5 flex items-center justify-between">
  <%= link_to back_path, class: "text-rad-text text-2xl leading-none no-underline" do %>‹<% end %>
  <div class="text-center flex-1 px-2">
    <% if suptitle.present? %>
      <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold"><%= suptitle %></div>
    <% end %>
    <span class="font-serif text-sm italic text-rad-text leading-none"><%= title %></span>
  </div>
  <button class="text-rad-text text-lg bg-transparent border-0 cursor-pointer">≡</button>
</div>
```

> Le bouton ≡ est décoratif à ce stade (ouverture du menu sidebar existant si applicable). Sur les vues subjects/show il n'y a pas de sidebar — le bouton peut être un simple `<span>` ou omis. À décider à l'implémentation.

---

## État 1 — Sélection de scope (`_scope_selection.html.erb`)

### Locals attendus (inchangés)
`subject`, `session_record`, `access_code`

### Stimulus controller : `scope-selector`

Fichier : `app/javascript/controllers/scope_selector_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "submit", "input"]
  static values  = { selected: String }

  connect() {
    // Sélectionner "full" par défaut
    this.select({ currentTarget: this.optionTargets.find(o => o.dataset.value === "full") || this.optionTargets[0] })
  }

  select(event) {
    const card = event.currentTarget
    this.selectedValue = card.dataset.value
    this.optionTargets.forEach(o => {
      const on = o === card
      o.dataset.selected = on ? "true" : "false"
    })
    this.inputTarget.value = this.selectedValue
  }
}
```

### Markup ERB

```erb
<div data-controller="scope-selector">
  <%= render "student/subjects/stripes" %>
  <%= render "student/subjects/subject_header",
        back_path: student_root_path(access_code: access_code),
        suptitle: "#{subject.exam_type&.upcase} · #{subject.specialty&.upcase}",
        title: subject.title %>

  <div class="px-5 pb-5">
    <p class="font-serif text-xl text-rad-text mb-1">
      Quel périmètre veux-tu réviser<span class="text-rad-red">?</span>
    </p>
    <p class="text-sm text-rad-muted leading-relaxed">
      Ce sujet comporte une partie commune (TC) et une partie spécifique <%= subject.specialty&.upcase %>.
    </p>
  </div>

  <div class="px-4 flex flex-col gap-2.5">
    <%# Option : TC + Spécifique (full) %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="full"
            data-action="click->scope-selector#select"
            data-selected="true"
            class="text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border-2 border-rad-red relative overflow-hidden transition-all
                   data-[selected=false]:border data-[selected=false]:border-rad-rule">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-red data-[selected=false]:hidden" data-scope-selector-target="accent"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">TC + Spécifique <%= subject.specialty&.upcase %></span>
          <span class="text-xs text-rad-muted">Toutes les parties · 20 pts · 4h</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-red leading-none block">20</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>

    <%# Option : Tronc commun seul %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="common_only"
            data-action="click->scope-selector#select"
            data-selected="false"
            class="text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border border-rad-rule relative overflow-hidden transition-all
                   data-[selected=true]:border-2 data-[selected=true]:border-rad-teal">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-teal hidden data-[selected=true]:block"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">Tronc commun seul</span>
          <span class="text-xs text-rad-muted">Parties communes · 12 pts · 2h30</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-teal leading-none block">12</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>

    <%# Option : Spécifique seul %>
    <button type="button"
            data-scope-selector-target="option"
            data-value="specific_only"
            data-action="click->scope-selector#select"
            data-selected="false"
            class="text-left w-full px-[18px] py-4 rounded-[18px] bg-rad-paper border border-rad-rule relative overflow-hidden transition-all
                   data-[selected=true]:border-2 data-[selected=true]:border-rad-yellow">
      <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-yellow hidden data-[selected=true]:block"></span>
      <div class="flex items-center justify-between gap-2.5">
        <div>
          <span class="font-serif text-base block mb-1">Spécifique <%= subject.specialty&.upcase %> seul</span>
          <span class="text-xs text-rad-muted">Partie spécifique · 8 pts · 1h30</span>
        </div>
        <div class="text-right flex-shrink-0">
          <span class="font-serif text-2xl text-rad-yellow leading-none block">8</span>
          <span class="text-[10px] text-rad-muted uppercase tracking-wider">pts</span>
        </div>
      </div>
    </button>
  </div>

  <%# Form hidden — soumis par le bouton Commencer %>
  <%= form_with url: student_subject_scope_selection_path(access_code: access_code, subject_id: subject.id),
                method: :patch,
                data: { scope_selector_target: "form" } do |f| %>
    <%= f.hidden_field :part_filter, value: "full", data: { scope_selector_target: "input" } %>
  <% end %>

  <%# StickyBar %>
  <div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule">
    <button type="button"
            data-action="click->scope-selector#submit"
            class="w-full py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13.5px] font-bold border-0 cursor-pointer">
      Commencer →
    </button>
  </div>
</div>
```

> Note : le bouton "Commencer" doit déclencher la soumission du form caché. Ajouter la méthode `submit()` au controller :
> ```javascript
> submit() { this.formTarget.requestSubmit() }
> ```

---

## État 2 — Liste des parties (`show.html.erb` bloc else + `_part_row.html.erb`)

### `show.html.erb` — bloc else (restructuration)

Le `show.html.erb` existant conserve sa structure conditionnelle (`if requires_scope_selection` / `elsif show_completion` / etc.). Seuls les styles et le contenu du bloc `else` (liste des parties) changent.

**Suppression dans le bloc else :**
- Le bloc "Mise en situation" (`@subject.common_presentation`) — migrera sur l'écran question en PR3
- Le breadcrumb dans ce bloc (remplacé par `_subject_header`)

**Ajouts dans le bloc else :**

1. `_stripes` + `_subject_header` en tête
2. Barre de progression globale :
```erb
<%
  all_questions = @parts.flat_map { |p| p.questions.kept.to_a }
  total_q = all_questions.size
  answered_q = all_questions.count { |q| @session_record.answered?(q.id) }
%>
<div class="px-5 pb-4">
  <div class="flex justify-between mb-1.5">
    <span class="text-[11px] font-bold tracking-[0.1em] uppercase text-rad-muted">Progression</span>
    <span class="text-[11px] font-semibold text-rad-muted"><%= answered_q %> / <%= total_q %></span>
  </div>
  <div class="h-[5px] rounded-full bg-rad-rule overflow-hidden">
    <div class="h-full bg-rad-teal rounded-full transition-all" style="width: <%= total_q > 0 ? (answered_q * 100 / total_q) : 0 %>%"></div>
  </div>
</div>
```

3. Bannière Tibo (remplace `_tutor_banner.html.erb`) — voir section dédiée ci-dessous

4. Section communes + spécifiques avec `_part_row`

5. `StickyBar` "Continuer la partie X →" :
```erb
<%
  active_part = @parts.find { |p| !@session_record.part_completed?(p.id) }
%>
<% if active_part %>
  <div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule flex gap-2.5">
    <%= link_to student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: @first_question.id),
        class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
      Continuer la partie <%= active_part.number %> →
    <% end %>
  </div>
<% end %>
```

### `_tutor_banner.html.erb` — version Radical

Locals inchangés : `tutor_status`, `access_code`.

```erb
<div class="mx-4 mb-4 px-3.5 py-3 rounded-[14px] bg-rad-raise border border-rad-rule flex items-center gap-2.5">
  <div class="w-8 h-8 rounded-full bg-rad-red flex items-center justify-center flex-shrink-0">
    <span class="font-serif italic text-rad-cream text-sm">T</span>
  </div>
  <div class="flex-1 min-w-0">
    <% if tutor_status == :active %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo actif</div>
      <div class="text-[11.5px] text-rad-muted flex items-center gap-1.5">
        <span class="w-1.5 h-1.5 rounded-full bg-rad-teal inline-block"></span>
        Ton tuteur IA t'accompagne sur ce sujet
      </div>
    <% elsif tutor_status == :available %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo disponible</div>
      <div class="text-[11.5px] text-rad-muted">Ton tuteur IA t'accompagne sur ce sujet</div>
    <% else %>
      <div class="text-[13px] font-semibold text-rad-text">Tibo indisponible</div>
      <div class="text-[11.5px] text-rad-muted">
        <%= link_to "Paramétrer →", student_settings_path(access_code: access_code),
            class: "text-rad-teal no-underline" %>
      </div>
    <% end %>
  </div>
  <% if tutor_status == :available %>
    <%= link_to student_settings_path(access_code: access_code),
        class: "flex-shrink-0 text-xs font-bold px-3 py-1.5 rounded-full bg-rad-ink text-rad-cream no-underline" do %>
      Activer
    <% end %>
  <% end %>
</div>
```

### `_part_row.html.erb` — version Radical

Locals inchangés : `part`, `session_record`.

```erb
<%
  is_done   = session_record.part_completed?(part.id)
  total_q   = part.questions.kept.size
  answered  = part.questions.kept.count { |q| session_record.answered?(q.id) }
  is_active = !is_done && answered > 0
  pct       = total_q > 0 ? (answered * 100 / total_q) : 0
  section_color = part.section_type == "specific" ? "bg-rad-yellow" : "bg-rad-teal"
  accent_color  = is_done ? "bg-rad-green" : is_active ? "bg-rad-red" : section_color
  border_class  = is_active ? "border-2 border-rad-red" : "border border-rad-rule"
%>
<div class="relative overflow-hidden rounded-[16px] bg-rad-paper <%= border_class %> px-4 py-3.5 mb-2">
  <span class="absolute left-0 top-0 bottom-0 w-1 <%= accent_color %>"></span>
  <div class="flex items-center gap-2.5">
    <div class="w-[38px] h-[38px] rounded-[10px] flex-shrink-0 flex items-center justify-center
                <%= is_done ? 'bg-rad-green' : is_active ? 'bg-rad-red' : 'bg-rad-raise' %>">
      <% if is_done %>
        <span class="text-rad-cream text-base">✓</span>
      <% else %>
        <span class="font-serif text-[15px] <%= is_active ? 'text-rad-cream' : 'text-rad-muted' %>">
          <%= part.number %>
        </span>
      <% end %>
    </div>
    <div class="flex-1 min-w-0">
      <div class="text-[13.5px] font-semibold text-rad-text mb-0.5"><%= part.title %></div>
      <div class="text-[11.5px] text-rad-muted">
        <%= answered %>/<%= total_q %> questions · <%= part.questions.kept.sum(:points) %> pts
      </div>
    </div>
    <% if is_active %>
      <span class="flex-shrink-0 text-[10.5px] font-bold px-2 py-1 rounded-full bg-rad-red text-rad-cream">
        En cours
      </span>
    <% end %>
  </div>
  <% if is_active && pct > 0 %>
    <div class="mt-2.5 h-[3px] rounded-full bg-rad-rule overflow-hidden">
      <div class="h-full bg-rad-red rounded-full" style="width: <%= pct %>%"></div>
    </div>
  <% end %>
</div>
```

---

## État 3 — Présentation spécifique (`_specific_presentation.html.erb`)

Locals : `subject`, `first_question`, `session_record`, `access_code`.

```erb
<%= render "student/subjects/stripes" %>
<%= render "student/subjects/subject_header",
      back_path: student_subject_path(access_code: access_code, id: subject.id),
      suptitle: "Partie spécifique · #{subject.specialty&.upcase}",
      title: subject.title %>

<%# Hero card teal avec pattern madras %>
<div class="mx-4 mt-3 rounded-[20px] overflow-hidden relative bg-rad-teal px-6 py-7">
  <div class="pattern-madras absolute inset-0 opacity-15 pointer-events-none"></div>
  <div class="relative">
    <div class="text-[10.5px] font-bold tracking-[0.18em] uppercase text-white/70 mb-2.5">
      Parties spécifiques · <%= subject.specialty&.upcase %>
    </div>
    <span class="font-serif text-2xl text-rad-cream leading-snug block">
      <%= subject.specialty_label %>
    </span>
    <div class="mt-4 flex gap-5">
      <% [
        [subject.specific_points.to_s,    "barème"],
        [subject.specific_questions.to_s, "questions"],
        ["1h30",                           "estimé"]
      ].each do |val, lbl| %>
        <div class="text-center">
          <div class="font-serif text-[22px] text-rad-cream leading-none"><%= val %></div>
          <div class="text-[10px] text-white/65 uppercase tracking-[0.1em] mt-0.5"><%= lbl %></div>
        </div>
      <% end %>
    </div>
  </div>
</div>

<%# Objectif — barre jaune %>
<% if subject.specific_presentation.present? %>
  <div class="mx-4 mt-3.5 rounded-[16px] bg-rad-paper border border-rad-rule px-[18px] py-4 relative overflow-hidden">
    <span class="absolute left-0 top-0 bottom-0 w-1 bg-rad-yellow"></span>
    <div class="text-[10.5px] tracking-[0.14em] uppercase text-rad-muted font-bold mb-2">Contexte spécifique</div>
    <p class="text-sm leading-relaxed text-rad-muted"><%= subject.specific_presentation %></p>
  </div>
<% end %>

<%# Tuiles DT de la partie spécifique %>
<% specific_dts = subject.technical_documents.where(doc_type: "DT").order(:number) %>
<% if specific_dts.any? %>
  <div class="mx-4 mt-3 flex gap-2">
    <% specific_dts.each do |dt| %>
      <div class="flex-1 px-3 py-2.5 rounded-[12px] bg-rad-paper border border-dashed border-rad-rule text-center">
        <span class="font-serif text-sm text-rad-yellow block">DT<%= dt.number %></span>
        <span class="text-[10.5px] text-rad-muted">PDF</span>
      </div>
    <% end %>
  </div>
<% end %>

<%# StickyBar %>
<div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule mt-6 flex gap-2.5">
  <%= link_to student_subject_path(access_code: access_code, id: subject.id),
      class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold text-center no-underline" do %>
    ← Parties
  <% end %>
  <% if first_question %>
    <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: first_question.id, mark_specific_seen: true),
        class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
      Commencer →
    <% end %>
  <% end %>
</div>
```

> `subject.specialty_label`, `subject.specific_points`, `subject.specific_questions` : ces méthodes peuvent ne pas exister. À l'implémentation, utiliser les helpers existants ou les calculs inline déjà présents dans les autres vues.

---

## État 4 — Questions sautées (`_unanswered_questions.html.erb`)

Locals inchangés : `unanswered_questions`, `subject`, `session_record`, `access_code`.

```erb
<%= render "student/subjects/stripes" %>
<%= render "student/subjects/subject_header",
      back_path: student_subject_path(access_code: access_code, id: subject.id),
      suptitle: subject.exam_type&.upcase,
      title: subject.title %>

<%# Bannière alerte jaune %>
<div class="mx-4 mt-2 px-[18px] py-4 rounded-[16px] bg-rad-paper border-2 border-rad-yellow relative overflow-hidden">
  <span class="absolute left-0 top-0 bottom-0 w-[5px] bg-rad-yellow"></span>
  <div class="flex items-start gap-2.5">
    <div class="w-[34px] h-[34px] rounded-full bg-rad-yellow flex items-center justify-center flex-shrink-0">
      <span class="font-serif text-base text-rad-ink font-bold">!</span>
    </div>
    <div>
      <div class="text-[14px] font-bold text-rad-text mb-1">Toutes les parties sont terminées</div>
      <p class="text-[13px] text-rad-muted leading-relaxed m-0">
        Il reste <strong class="text-rad-text"><%= unanswered_questions.size %> question<%= unanswered_questions.size > 1 ? "s" : "" %></strong>
        (<%= unanswered_questions.sum(:points) %> pts). Veux-tu les traiter avant de valider ?
      </p>
    </div>
  </div>
</div>

<%# Liste questions sautées %>
<div class="px-4 mt-5">
  <div class="text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold mb-2.5">Questions sautées</div>
  <div class="flex flex-col gap-2">
    <% unanswered_questions.each do |question| %>
      <div class="px-[18px] py-3.5 rounded-[16px] bg-rad-paper border border-rad-rule flex items-start gap-3">
        <div class="w-11 h-11 rounded-[12px] bg-rad-yellow flex items-center justify-center flex-shrink-0">
          <span class="font-serif text-sm text-rad-ink"><%= question.number %></span>
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-[11px] text-rad-muted mb-0.5">Partie <%= question.part.number %></div>
          <p class="font-serif text-[14px] leading-snug text-rad-text m-0 mb-2"><%= truncate(question.label, length: 120) %></p>
          <span class="text-[11px] font-bold px-2 py-1 rounded-[6px] bg-rad-raise border border-rad-rule text-rad-muted">
            <%= question.points %> pts
          </span>
        </div>
        <%= link_to "Répondre",
            student_question_path(access_code: access_code, subject_id: subject.id, id: question.id, from: "review"),
            class: "flex-shrink-0 px-3 py-2 rounded-full border border-rad-text bg-transparent text-rad-text text-xs font-bold no-underline" %>
      </div>
    <% end %>
  </div>
</div>

<%# StickyBar %>
<div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule mt-4 flex gap-2.5">
  <%= button_to "Ignorer et terminer",
      student_subject_completion_path(access_code: access_code, subject_id: subject.id),
      method: :post,
      class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold cursor-pointer" %>
  <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: unanswered_questions.first.id, from: "review"),
      class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-red text-rad-cream text-[13px] font-bold text-center no-underline" do %>
    Répondre aux <%= unanswered_questions.size %> questions →
  <% end %>
</div>
```

---

## État 5 — Complétion (`_completion.html.erb`)

Local inchangé : `access_code`.

```erb
<%= render "student/subjects/stripes" %>

<%# ConfettiComponent conservé %>
<%= render(ConfettiComponent.new) %>

<div class="flex flex-col min-h-[calc(100vh-6px)]">
  <div class="flex-1 flex flex-col items-center px-6 pt-8 text-center">
    <%# Cercle vert concentrique %>
    <div class="relative w-24 h-24 mb-6">
      <div class="absolute inset-0 rounded-full bg-rad-green opacity-15"></div>
      <div class="absolute inset-2 rounded-full bg-rad-green opacity-20"></div>
      <div class="absolute inset-0 flex items-center justify-center">
        <span class="font-serif text-[44px] text-rad-green leading-none">✓</span>
      </div>
    </div>

    <span class="font-serif text-[30px] leading-snug block mb-2.5">
      Sujet terminé<span class="text-rad-green">.</span>
    </span>
    <p class="text-[15px] text-rad-muted leading-relaxed mb-8 max-w-[280px]">
      Tu as répondu à toutes les questions.
    </p>

    <%# Stats segmentées — calculées depuis @subject et @session_record via helper ou locals %>
    <%# Note : _completion reçoit uniquement `access_code`. Les stats sont decoratives pour l'instant. %>
    <%# À l'implémentation : si les variables @subject et @session_record sont accessibles depuis le partial, les utiliser. %>
    <div class="flex rounded-[18px] overflow-hidden border border-rad-rule bg-rad-paper w-full">
      <% [["15", "Questions"], ["20", "Points"], ["3", "Parties"]].each_with_index do |(val, lbl), i| %>
        <div class="flex-1 py-[18px] px-3 text-center <%= i < 2 ? 'border-r border-rad-rule' : '' %>">
          <span class="font-serif text-[28px] text-rad-green leading-none block mb-1"><%= val %></span>
          <span class="text-[11px] text-rad-muted uppercase tracking-[0.1em] font-semibold"><%= lbl %></span>
        </div>
      <% end %>
    </div>
  </div>

  <%# Boutons de sortie %>
  <div class="px-4 pb-8 pt-6 flex flex-col gap-2.5">
    <%= link_to student_subject_path(access_code: access_code, id: params[:id] || session[:last_subject_id]),
        class: "w-full py-3.5 rounded-[14px] bg-rad-green text-rad-cream text-[14px] font-bold text-center no-underline block" do %>
      Voir les corrections →
    <% end %>
    <%= link_to student_root_path(access_code: access_code),
        class: "w-full py-3.5 rounded-[14px] border-[1.5px] border-rad-rule bg-transparent text-rad-text text-[13px] font-bold text-center no-underline block" do %>
      Retour aux sujets
    <% end %>
  </div>
</div>
```

> **Note implémentation** : `_completion.html.erb` ne reçoit actuellement que `access_code`. Les stats (15 questions, 20 pts, 3 parties) sont hardcodées dans le design. Options à l'implémentation : (a) passer `@subject` et `@session_record` en locals supplémentaires depuis `show.html.erb`, (b) garder des valeurs statiques decoratives pour le MVP. Option (a) recommandée si trivial, sinon (b) acceptable.

> **"Voir les corrections"** : lien vers `student_subject_path` avec le sujet courant. Le partial ne reçoit pas `subject_id` actuellement — à ajouter en local ou récupérer depuis params.

---

## État 6 — Mode relecture (dans `show.html.erb`)

Le bloc `@relecture_mode` dans `show.html.erb` remplace la bannière emerald actuelle par :

```erb
<% if @relecture_mode %>
  <%# Badge relecture %>
  <div class="mx-5 mb-4 flex items-center gap-2">
    <span class="text-[10.5px] font-bold tracking-[0.14em] uppercase px-2.5 py-1 rounded-full
                 bg-rad-teal/10 text-rad-teal border border-rad-teal/30">
      Mode relecture
    </span>
    <span class="text-xs text-rad-muted">Sujet complété</span>
  </div>

  <%# Résumé compact vert %>
  <div class="mx-4 mb-4 px-[18px] py-3.5 rounded-[16px] bg-rad-paper border border-rad-rule flex items-center gap-3.5">
    <div class="w-11 h-11 rounded-[12px] bg-rad-green flex items-center justify-center flex-shrink-0">
      <span class="text-rad-cream text-xl">✓</span>
    </div>
    <div class="flex-1">
      <div class="text-[13px] font-bold text-rad-text mb-0.5">
        <%= @session_record.answered_count %> / <%= @parts.flat_map { |p| p.questions.kept.to_a }.size %> questions répondues
      </div>
      <div class="text-xs text-rad-muted">Toutes les parties terminées</div>
    </div>
  </div>
<% end %>
```

La liste des parties en mode relecture utilise le même `_part_row` (toutes `is_done = true` → toutes vertes), avec un chevron `›` ajouté côté droit. Le `StickyBar` en relecture :

```erb
<div class="sticky bottom-0 px-4 pb-8 pt-3 bg-rad-bg border-t border-rad-rule flex gap-2.5">
  <%= link_to student_root_path(access_code: params[:access_code]),
      class: "flex-1 py-3.5 rounded-[14px] border-[1.5px] border-rad-text bg-transparent text-rad-text text-[13px] font-bold text-center no-underline" do %>
    Retour aux sujets
  <% end %>
  <%= link_to student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: @first_question.id),
      class: "flex-[1.5] py-3.5 rounded-[14px] bg-rad-raise text-rad-text text-[13px] font-bold text-center no-underline" do %>
    Reprendre la lecture →
  <% end %>
</div>
```

---

## Stimulus controller `scope-selector` — spec complète

Fichier : `app/javascript/controllers/scope_selector_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "form", "input"]

  connect() {
    const defaultOption = this.optionTargets.find(o => o.dataset.value === "full")
      || this.optionTargets[0]
    if (defaultOption) this.selectOption(defaultOption)
  }

  select(event) {
    this.selectOption(event.currentTarget)
  }

  submit() {
    this.formTarget.requestSubmit()
  }

  selectOption(card) {
    this.optionTargets.forEach(o => o.dataset.selected = "false")
    card.dataset.selected = "true"
    if (this.hasInputTarget) this.inputTarget.value = card.dataset.value
  }
}
```

---

## Tests — `spec/features/student/subject_workflow_spec.rb`

Le fichier existant couvre déjà certains flux. Ajouter/mettre à jour les exemples suivants :

```ruby
# Vérifier que les stripes sont présents sur tous les états
it "affiche les stripes Radical en tête de chaque écran subjects#show" do
  # login élève, naviguer vers un sujet
  # expect(page).to have_css(".bg-rad-red") # bande rouge
end

# État 1 — scope selector
it "sélectionne une option de scope et soumet le form" do
  # login élève sur sujet avec TC + spécifique
  # expect(page).to have_css("[data-controller='scope-selector']")
  # find("[data-value='common_only']").click
  # expect(find("[data-value='common_only']")["data-selected"]).to eq("true")
  # click_button "Commencer →"
  # expect(page).to have_current_path(...)
end

# État 2 — barre de progression globale
it "affiche la barre de progression globale" do
  # expect(page).to have_css(".bg-rad-teal") # barre progression
end

# État 5 — complétion
it "affiche l'écran complétion avec le cercle vert" do
  # marquer toutes questions répondues
  # expect(page).to have_text("Sujet terminé")
  # expect(page).to have_css(".bg-rad-green")
end
```

> Les specs existantes qui passent doivent continuer à passer. Ne pas modifier le comportement fonctionnel — uniquement les sélecteurs CSS si nécessaire.

---

## Points d'attention implémentation

1. **`_completion.html.erb` — locals manquants** : le partial ne reçoit que `access_code`. Pour les stats et le lien "Voir les corrections", passer `subject: @subject` et `session_record: @session_record` depuis `show.html.erb`.

2. **`_specific_presentation.html.erb` — méthodes manquantes** : `subject.specific_points`, `subject.specific_questions`, `subject.specialty_label` peuvent ne pas exister. Utiliser les helpers existants ou les calculs inline de `show.html.erb`.

3. **Breadcrumb desktop** : sur desktop (`md:block`), le breadcrumb existant dans `show.html.erb` peut être conservé avec `hidden md:block` pour le confort desktop, tandis que `_subject_header` est affiché en `md:hidden`. À décider à l'implémentation selon le rendu.

4. **Bouton ≡ dans `_subject_header`** : sur `subjects#show`, il n'y a pas de sidebar. Le bouton peut être omis ou rendu inactif sur ces vues. Le laisser décoratif est acceptable pour cette PR.

5. **Scope selector — accentuation via data attributes** : Tailwind 4 avec `data-[selected=true]:border-2` fonctionne nativement en variant data. Vérifier la compilation au build.

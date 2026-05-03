# PR5 — Radical reskin : écrans élèves restants

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin des 3 écrans élève encore en slate/indigo vers le design Radical (rad tokens, stripes, typo Fraunces).

**Architecture:** Reskin token-by-token sur 3 vues ERB. Aucun changement fonctionnel, aucune migration. Les composants ViewComponent existants (CardComponent, BadgeComponent, ProgressBarComponent) sont étendus avec des variantes rad plutôt que remplacés. Le layout `student.html.erb` est reskinné en même temps que les vues pour la cohérence globale.

**Tech Stack:** Ruby on Rails 8.1, Tailwind CSS 4, ViewComponent, Hotwire/Turbo

---

## Contexte préalable — état des composants

- **CardComponent** : variants `:default` et `:glow` — hardcodés slate/indigo. On ajoute `:rad` dans cette PR.
- **BadgeComponent** : COLORS map slate/indigo/emerald/amber — on ajoute `:rad_teal`, `:rad_red`, `:rad_yellow`, `:rad_muted`. Alternative : inline classes dans la vue, à éviter pour cohérence.
- **ProgressBarComponent** : COLORS map indigo/emerald/gradient — on ajoute `:rad_teal`.
- **Layout `student.html.erb`** : body en `bg-slate-50`, NavBar indigo — à reskinné.

---

## Fichiers touchés

| Fichier | Action |
|---|---|
| `app/components/card_component.rb` | Modifier — ajouter variant `:rad` |
| `app/components/badge_component.rb` | Modifier — ajouter couleurs rad |
| `app/components/progress_bar_component.rb` | Modifier — ajouter couleur `:rad_teal` |
| `app/views/layouts/student.html.erb` | Modifier — body rad-bg, navbar rad |
| `app/views/student/sessions/new.html.erb` | Modifier — reskin complet |
| `app/views/student/subjects/index.html.erb` | Modifier — reskin complet |
| `app/views/student/settings/show.html.erb` | Modifier — reskin complet + suppression spécialité |

---

## Task 1 : Branche + composants rad

**Files:**
- Modify: `app/components/card_component.rb`
- Modify: `app/components/badge_component.rb`
- Modify: `app/components/progress_bar_component.rb`

- [ ] **Step 1 : Créer la branche**

```bash
git checkout -b 057-student-remaining-screens-radical
```

- [ ] **Step 2 : Ajouter variant `:rad` à CardComponent**

Remplacer le contenu de `app/components/card_component.rb` :

```ruby
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer

  def initialize(variant: :default)
    @variant = variant.to_sym
  end

  def card_classes
    base = "rounded-2xl overflow-hidden"

    case @variant
    when :rad
      "#{base} bg-rad-paper border border-rad-rule"
    when :glow
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-indigo-500/15 dark:shadow-[0_0_15px_rgba(99,102,241,0.05)] transition-shadow hover:shadow-md dark:hover:shadow-[0_0_25px_rgba(99,102,241,0.15)]"
    else
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-slate-700 dark:shadow-none"
    end
  end
end
```

- [ ] **Step 3 : Mettre à jour le footer partial de CardComponent**

Dans `app/components/card_component.html.erb`, le footer a encore `border-slate-200 dark:border-slate-700/50`. Remplacer uniquement la ligne footer :

```erb
<div class="<%= card_classes %>">
  <% if header? %>
    <div class="px-5 py-4">
      <%= header %>
    </div>
  <% end %>

  <% if body? %>
    <div class="px-5 py-4">
      <%= body %>
    </div>
  <% end %>

  <% if footer? %>
    <div class="border-t border-rad-rule px-5 py-4">
      <%= footer %>
    </div>
  <% end %>
</div>
```

Note : ce changement touche le footer pour *tous* les variants. Il est neutre pour les vues existantes car `border-rad-rule` utilise la CSS variable qui existe déjà sur toutes les pages student.

- [ ] **Step 4 : Ajouter couleurs rad à BadgeComponent**

Remplacer le contenu de `app/components/badge_component.rb` :

```ruby
class BadgeComponent < ViewComponent::Base
  COLORS = {
    indigo:    "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-400",
    emerald:   "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
    amber:     "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-400",
    blue:      "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
    slate:     "bg-slate-200 text-slate-700 dark:bg-slate-500/15 dark:text-slate-400",
    rose:      "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
    rad_teal:  "bg-rad-teal/10 text-rad-teal border border-rad-teal/20",
    rad_red:   "bg-rad-red/10 text-rad-red border border-rad-red/20",
    rad_yellow:"bg-rad-yellow/15 text-rad-ink border border-rad-yellow/30",
    rad_muted: "bg-rad-rule/40 text-rad-muted border border-rad-rule",
  }.freeze

  def initialize(color:, label:)
    @color = color.to_sym
    @label = label
  end

  def call
    css = class_names(
      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
      COLORS[@color]
    )

    content_tag(:span, @label, class: css)
  end
end
```

- [ ] **Step 5 : Ajouter `:rad_teal` à ProgressBarComponent**

Remplacer le contenu de `app/components/progress_bar_component.rb` :

```ruby
class ProgressBarComponent < ViewComponent::Base
  COLORS = {
    indigo:   "bg-indigo-500",
    emerald:  "bg-emerald-500",
    gradient: "bg-gradient-to-r from-indigo-500 to-violet-500",
    rad_teal: "bg-rad-teal",
  }.freeze

  def initialize(current:, total:, color: :indigo, show_text: false)
    @current = current
    @total = total
    @color = color.to_sym
    @show_text = show_text
  end

  def percentage
    return 0 if @total.zero?
    (@current * 100.0 / @total).round
  end

  def bar_color
    COLORS[@color] || COLORS[:indigo]
  end

  def call
    content_tag(:div, class: "flex items-center gap-2") do
      bar = content_tag(:div, role: "progressbar",
                        aria: { valuenow: @current, valuemin: 0, valuemax: @total },
                        class: "flex-1 h-1 bg-rad-rule rounded-full overflow-hidden") do
        content_tag(:div, "", class: "h-full #{bar_color} rounded-full transition-all",
                    style: "width: #{percentage}%")
      end

      if @show_text
        text = content_tag(:span, "#{@current}/#{@total}",
                           class: "text-xs text-rad-muted whitespace-nowrap")
        bar + text
      else
        bar
      end
    end
  end
end
```

Note : le track de la barre passe de `bg-slate-200 dark:bg-slate-700` à `bg-rad-rule` — neutre visuellement (même couleur beige/teal selon le thème). Le texte `show_text` est simplifié (plus de pourcentage).

- [ ] **Step 6 : Vérifier que les specs components passent**

```bash
bundle exec rspec spec/components/ --format documentation
```

Expected : tous verts (les composants n'ont pas de tests cassés car on ajoute des variantes, pas on ne modifie pas les existantes).

- [ ] **Step 7 : Commit**

```bash
git add app/components/card_component.rb app/components/card_component.html.erb app/components/badge_component.rb app/components/progress_bar_component.rb
git commit -m "feat(components): add rad variants to Card, Badge, ProgressBar components"
```

---

## Task 2 : Reskin layout student

**Files:**
- Modify: `app/views/layouts/student.html.erb`

Le layout actuel a une NavBar indigo/slate et un `body bg-slate-50`. Les 3 écrans reskinées utilisent leur propre fond `bg-rad-bg` — le layout doit être neutre.

- [ ] **Step 1 : Reskinné le layout**

Remplacer le contenu de `app/views/layouts/student.html.erb` :

```erb
<!DOCTYPE html>
<html lang="fr" class="dark">
  <head>
    <title><%= content_for(:title) || "DekatjeBakLa" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="DekatjeBakLa">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>

    <script>
      (function() {
        var stored = localStorage.getItem('theme');
        if (stored === 'light') {
          document.documentElement.classList.remove('dark');
        } else if (!stored && window.matchMedia('(prefers-color-scheme: light)').matches) {
          document.documentElement.classList.remove('dark');
        }
      })();
    </script>
  </head>

  <body class="bg-rad-bg text-rad-text min-h-screen" data-controller="theme">
    <a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:p-4 focus:bg-rad-red focus:text-rad-cream focus:rounded-lg focus:m-2">Aller au contenu</a>

    <div aria-live="polite" role="status">
      <% if notice.present? %>
        <div class="max-w-4xl mx-auto mt-4 px-4">
          <%= render(FlashComponent.new(type: :notice, message: notice)) %>
        </div>
      <% end %>
      <% if alert.present? %>
        <div class="max-w-4xl mx-auto mt-4 px-4">
          <%= render(FlashComponent.new(type: :alert, message: alert)) %>
        </div>
      <% end %>
    </div>

    <main id="main-content">
      <%= yield %>
    </main>
  </body>
</html>
```

Note : la NavBarComponent (avec le lien Réglages et Déconnexion) est **supprimée** du layout — ces actions sont maintenant intégrées dans chaque vue via le header 3 zones (icône `≡` → réglages, `‹` → retour). La déconnexion reste dans les réglages.

- [ ] **Step 2 : Vérifier que la déconnexion est toujours accessible**

Ouvrir `app/views/student/settings/show.html.erb` et confirmer qu'un lien de déconnexion y est présent. S'il ne l'est pas (l'écran sera reskinné en Task 4), noter qu'il faudra l'y ajouter.

- [ ] **Step 3 : Commit**

```bash
git add app/views/layouts/student.html.erb
git commit -m "style(student): reskin layout — rad-bg body, drop NavBar (nav in-view)"
```

---

## Task 3 : Reskin login (`sessions/new`)

**Files:**
- Modify: `app/views/student/sessions/new.html.erb`

- [ ] **Step 1 : Remplacer la vue**

```erb
<div class="bg-rad-bg min-h-screen flex flex-col">
  <%# Stripes %>
  <div class="flex h-1.5" aria-hidden="true">
    <div class="flex-1 bg-rad-red"></div>
    <div class="flex-1 bg-rad-yellow"></div>
    <div class="flex-1 bg-rad-teal"></div>
    <div class="flex-1 bg-rad-ink"></div>
  </div>

  <div class="flex-1 flex items-center justify-center px-4 py-10">
    <div class="w-full max-w-sm">
      <%# Logo %>
      <div class="text-center mb-8">
        <div class="inline-flex items-center gap-2.5">
          <div class="flex gap-1.5">
            <div class="w-2.5 h-2.5 rounded-full bg-rad-red"></div>
            <div class="w-2.5 h-2.5 rounded-full bg-rad-yellow"></div>
            <div class="w-2.5 h-2.5 rounded-full bg-rad-teal"></div>
          </div>
          <span class="font-serif italic text-lg text-rad-text leading-none">DekatjeBakLa</span>
        </div>
      </div>

      <%# Card %>
      <div class="bg-rad-paper border border-rad-rule rounded-2xl overflow-hidden">
        <%# Card stripes %>
        <div class="flex h-1" aria-hidden="true">
          <div class="flex-1 bg-rad-red"></div>
          <div class="flex-1 bg-rad-yellow"></div>
          <div class="flex-1 bg-rad-teal"></div>
          <div class="flex-1 bg-rad-ink"></div>
        </div>

        <div class="p-6">
          <div class="text-center mb-6">
            <h1 class="font-serif italic text-lg text-rad-text mb-1"><%= @classroom.name %></h1>
            <p class="text-sm text-rad-muted">Connecte-toi pour accéder aux sujets</p>
          </div>

          <%= form_with(url: student_session_path(access_code: params[:access_code]), data: { turbo: false }) do %>
            <div class="space-y-4">
              <div>
                <label for="username" class="block text-[11px] font-bold text-rad-muted mb-1.5 uppercase tracking-wider">Identifiant</label>
                <%= text_field_tag :username, nil,
                    id: "username",
                    autocomplete: "username",
                    class: "w-full px-4 py-3 bg-rad-paper border border-rad-rule rounded-xl text-sm text-rad-text placeholder-rad-muted/60 focus:outline-none focus:ring-2 focus:ring-rad-teal" %>
              </div>
              <div>
                <label for="password" class="block text-[11px] font-bold text-rad-muted mb-1.5 uppercase tracking-wider">Mot de passe</label>
                <%= password_field_tag :password, nil,
                    id: "password",
                    autocomplete: "current-password",
                    class: "w-full px-4 py-3 bg-rad-paper border border-rad-rule rounded-xl text-sm text-rad-text placeholder-rad-muted/60 focus:outline-none focus:ring-2 focus:ring-rad-teal" %>
              </div>
              <div class="pt-1">
                <button type="submit" class="w-full bg-rad-red text-rad-cream font-bold text-sm py-3 rounded-[14px] cursor-pointer hover:opacity-90 transition-opacity">
                  Se connecter
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="text-center mt-6">
        <%= link_to "← Retour", root_path, class: "text-sm text-rad-muted hover:text-rad-teal transition-colors" %>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 2 : Vérifier que les specs login passent**

```bash
bundle exec rspec spec/features/student_login_and_subjects_spec.rb --format documentation
```

Expected : tous verts. Les specs cherchent `have_content(@classroom.name)`, `have_field("Identifiant")`, `have_field("Mot de passe")`, `have_button("Se connecter")` — tout est conservé.

- [ ] **Step 3 : Commit**

```bash
git add app/views/student/sessions/new.html.erb
git commit -m "style(student): reskin login page — rad tokens, serif logo, stripes"
```

---

## Task 4 : Reskin liste des sujets (`subjects/index`)

**Files:**
- Modify: `app/views/student/subjects/index.html.erb`

- [ ] **Step 1 : Remplacer la vue**

```erb
<div class="bg-rad-bg min-h-screen text-rad-text">
  <%# Stripes %>
  <div class="flex h-1.5" aria-hidden="true">
    <div class="flex-1 bg-rad-red"></div>
    <div class="flex-1 bg-rad-yellow"></div>
    <div class="flex-1 bg-rad-teal"></div>
    <div class="flex-1 bg-rad-ink"></div>
  </div>

  <%# Header 3 zones %>
  <div class="px-5 py-3.5 flex items-center justify-between">
    <%= link_to root_path, class: "text-rad-text text-2xl leading-none no-underline" do %>‹<% end %>
    <div class="text-center flex-1 px-2">
      <span class="font-serif italic text-sm text-rad-text leading-none">Mes sujets</span>
    </div>
    <%= link_to student_settings_path(access_code: params[:access_code]), class: "text-rad-text text-lg leading-none" do %>≡<% end %>
  </div>

  <div class="max-w-5xl mx-auto px-4 py-6">
    <div class="mb-6">
      <h1 class="font-serif text-2xl sm:text-3xl text-rad-text">
        Salut <span class="text-rad-red"><%= current_student.first_name %></span>
      </h1>
      <p class="text-sm text-rad-muted mt-1">
        <%= @classroom.name %> &middot; <%= pluralize(@subjects.size, "sujet") %>
      </p>
    </div>

    <% if @subjects.empty? %>
      <div class="bg-rad-paper border border-rad-rule rounded-2xl p-8 text-center">
        <p class="text-rad-muted">Aucun sujet n'a encore été assigné à votre classe.</p>
      </div>
    <% else %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <% @subjects.each do |subject| %>
          <%
            session_record = current_student.student_sessions.find_by(subject: subject)
            total = subject.total_questions_count
            answered = session_record ? session_record.answered_count : 0
            matches_specialty = current_student.specialty.present? && subject.specialty == current_student.specialty
            tc_only = @tc_only_subject_ids.include?(subject.id)
          %>
          <div data-subject-id="<%= subject.id %>">
            <%= render(CardComponent.new(variant: :rad)) do |card|
              card.with_body do %>
                <div class="flex flex-wrap gap-1.5 mb-3">
                  <%= render(BadgeComponent.new(
                    color: matches_specialty ? :rad_teal : :rad_red,
                    label: subject.specialty&.upcase || "—"
                  )) %>
                  <% if matches_specialty %>
                    <%= render(BadgeComponent.new(color: :rad_teal, label: "Ma spé")) %>
                  <% end %>
                  <% if tc_only %>
                    <%= render(BadgeComponent.new(color: :rad_yellow, label: "partie commune uniquement")) %>
                  <% end %>
                  <%= render(BadgeComponent.new(color: :rad_muted, label: subject.year.to_s)) %>
                  <% if subject.region.present? %>
                    <%= render(BadgeComponent.new(color: :rad_muted, label: subject.region)) %>
                  <% end %>
                </div>
                <h3 class="text-base font-semibold text-rad-text mb-1">
                  <%= subject.title %>
                </h3>
                <p class="text-sm text-rad-muted mb-4">
                  <%= subject.exam&.upcase %> <%= subject.year %>
                </p>
                <%= render(ProgressBarComponent.new(current: answered, total: total, color: :rad_teal, show_text: true)) %>
              <% end %>
              <% card.with_footer do %>
                <%= link_to(
                  session_record ? "Continuer →" : "Commencer →",
                  student_subject_path(access_code: params[:access_code], id: subject.id),
                  class: "inline-flex items-center px-4 py-1.5 bg-rad-red text-rad-cream text-sm font-bold rounded-full hover:opacity-90 transition-opacity"
                ) %>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 2 : Vérifier que les specs subjects passent**

```bash
bundle exec rspec spec/features/student_login_and_subjects_spec.rb --format documentation
```

Expected : tous verts. Les specs cherchent `have_content`, `have_link("Commencer")`, `have_link("Continuer")` — tout est conservé.

- [ ] **Step 3 : Commit**

```bash
git add app/views/student/subjects/index.html.erb
git commit -m "style(student): reskin subjects index — rad tokens, serif header, rad badges"
```

---

## Task 5 : Reskin réglages (`settings/show`)

**Files:**
- Modify: `app/views/student/settings/show.html.erb`

Changements fonctionnels par rapport au code actuel :
- **Suppression** du champ spécialité (section "Profil" avec `f.select :specialty`)
- **Ajout** d'une card profil read-only en haut
- **Remplacement** des radio_button mode par un toggle 2 boutons (les inputs hidden subsistent pour la soumission)
- **Conservation** du toggle `use_personal_key`
- **Conservation** du lien de déconnexion (déplacé dans le footer de la vue)

- [ ] **Step 1 : Remplacer la vue**

```erb
<div class="bg-rad-bg min-h-screen text-rad-text">
  <%# Stripes %>
  <div class="flex h-1.5" aria-hidden="true">
    <div class="flex-1 bg-rad-red"></div>
    <div class="flex-1 bg-rad-yellow"></div>
    <div class="flex-1 bg-rad-teal"></div>
    <div class="flex-1 bg-rad-ink"></div>
  </div>

  <%# Header 3 zones %>
  <div class="px-5 py-3.5 flex items-center justify-between">
    <%= link_to student_root_path(access_code: params[:access_code]), class: "text-rad-text text-2xl leading-none no-underline" do %>‹<% end %>
    <div class="text-center flex-1 px-2">
      <span class="font-serif italic text-sm text-rad-text leading-none">Réglages</span>
    </div>
    <div class="w-6"></div>
  </div>

  <%# Card profil %>
  <div class="mx-4 mb-6 p-4 bg-rad-paper border border-rad-rule rounded-2xl flex items-center gap-3">
    <div class="w-11 h-11 rounded-full bg-rad-red flex items-center justify-center flex-shrink-0">
      <span class="font-serif italic text-lg text-rad-cream leading-none"><%= current_student.first_name[0].upcase %></span>
    </div>
    <div>
      <div class="text-sm font-bold text-rad-text"><%= current_student.first_name %> <%= current_student.last_name %></div>
      <div class="text-xs text-rad-muted"><%= current_student.username %> · <%= current_student.classroom.name %></div>
    </div>
  </div>

  <%= form_with model: current_student, url: student_settings_path(access_code: params[:access_code]),
                method: :patch, data: { controller: "settings", settings_models_value: @models_json } do |f| %>

    <%# ── Mode par défaut ── %>
    <div class="text-[10.5px] uppercase tracking-[0.16em] text-rad-muted font-bold px-5 mb-2">Mode par défaut</div>
    <div class="bg-rad-paper border-t border-b border-rad-rule mb-6">
      <div class="px-5 py-4">
        <div class="text-sm font-semibold text-rad-text mb-1">À l'ouverture d'un sujet</div>
        <div class="text-xs text-rad-muted mb-3">Tu pourras toujours changer sur chaque sujet.</div>

        <%# Toggle 2 boutons — les radio inputs restent pour la soumission %>
        <div class="flex rounded-xl overflow-hidden border border-rad-rule"
             data-controller="mode-toggle">
          <label class="flex-1 cursor-pointer">
            <%= f.radio_button :default_mode, "revision", class: "sr-only peer/revision" %>
            <div class="peer-checked/revision:bg-rad-ink peer-checked/revision:text-rad-cream bg-rad-raise text-rad-muted text-center py-3 transition-colors">
              <div class="text-sm font-bold">Autonome</div>
              <div class="text-xs opacity-75">Sans IA · toi seul</div>
            </div>
          </label>
          <label class="flex-1 cursor-pointer border-l border-rad-rule">
            <%= f.radio_button :default_mode, "tutored", class: "sr-only peer/tutored" %>
            <div class="peer-checked/tutored:bg-rad-red peer-checked/tutored:text-rad-cream bg-rad-raise text-rad-muted text-center py-3 transition-colors">
              <div class="text-sm font-bold">Tuteur IA</div>
              <div class="text-xs opacity-75">Tibo t'accompagne</div>
            </div>
          </label>
        </div>
      </div>
    </div>

    <%# ── Tuteur IA · Clé API ── %>
    <div class="text-[10.5px] uppercase tracking-[0.16em] text-rad-muted font-bold px-5 mb-2">Tuteur IA · Clé API</div>
    <div class="bg-rad-paper border-t border-b border-rad-rule mb-6">

      <%# Provider %>
      <div class="px-5 py-[13px] border-b border-rad-rule flex items-center justify-between gap-3">
        <div>
          <div class="text-sm font-semibold text-rad-text">Fournisseur</div>
        </div>
        <%= f.select :api_provider,
            Student.api_providers.keys.map { |k| [k.capitalize, k] },
            {},
            class: "bg-rad-raise border border-rad-rule rounded-lg px-3 py-2 text-sm text-rad-text focus:outline-none focus:ring-2 focus:ring-rad-teal",
            data: { action: "change->settings#providerChanged", settings_target: "provider" } %>
      </div>

      <%# Modèle %>
      <div class="px-5 py-[13px] border-b border-rad-rule flex items-center justify-between gap-3">
        <div class="text-sm font-semibold text-rad-text">Modèle</div>
        <select name="student[api_model]"
                data-settings-target="model"
                class="bg-rad-raise border border-rad-rule rounded-lg px-3 py-2 text-sm text-rad-text focus:outline-none focus:ring-2 focus:ring-rad-teal">
          <% models = Student::AVAILABLE_MODELS[current_student.api_provider] || [] %>
          <% models.each do |m| %>
            <option value="<%= m[:id] %>" <%= "selected" if current_student.api_model == m[:id] || (current_student.api_model.blank? && m == models.first) %>>
              <%= m[:cost] %> <%= m[:label] %><%= " — #{m[:note]}" if m[:note] %>
            </option>
          <% end %>
        </select>
      </div>

      <%# Clé API %>
      <div class="px-5 py-[13px] border-b border-rad-rule">
        <div class="text-sm font-semibold text-rad-text mb-1">Clé API</div>
        <div class="text-xs text-rad-muted mb-3">Stockée chiffrée · jamais transmise à d'autres élèves.</div>
        <div class="flex gap-2 mb-3">
          <%= f.password_field :api_key,
              value: current_student.api_key,
              placeholder: "sk-…",
              class: "flex-1 px-3 py-2.5 bg-rad-raise border border-rad-rule rounded-xl text-sm text-rad-text font-mono focus:outline-none focus:ring-2 focus:ring-rad-teal",
              data: { settings_target: "apiKey" } %>
          <button type="button"
                  data-action="click->settings#toggleApiKey"
                  aria-label="Afficher / masquer la clé API"
                  class="px-3 py-2.5 bg-rad-raise border border-rad-rule rounded-xl text-rad-muted hover:text-rad-text transition-colors cursor-pointer">
            👁
          </button>
        </div>

        <div class="flex items-center gap-3">
          <%= render(ButtonComponent.new(variant: :ghost, size: :sm,
                data: { action: "click->settings#testKey", settings_target: "testButton" },
                type: "button")) { "Tester la clé" } %>

          <%= turbo_frame_tag "test_key_result" do %>
            <p id="test_key_result" class="text-sm"></p>
          <% end %>
        </div>
      </div>

      <%# Toggle clé personnelle %>
      <% if current_student.classroom.tutor_free_mode_enabled? || current_student.api_key.present? %>
        <div class="px-5 py-[13px]">
          <label class="flex items-start gap-3 cursor-pointer">
            <%= f.check_box :use_personal_key, class: "mt-0.5 accent-rad-teal w-4 h-4 shrink-0" %>
            <div>
              <span class="text-sm font-medium text-rad-text">Utiliser ma clé personnelle (modèle premium)</span>
              <p class="text-xs text-rad-muted mt-0.5">
                <% if current_student.classroom.tutor_free_mode_enabled? %>
                  Si décoché, la clé de votre enseignant sera utilisée (modèle gratuit OpenRouter).
                <% else %>
                  Utilisez votre propre clé API pour accéder au tutorat IA.
                <% end %>
              </p>
            </div>
          </label>
        </div>
      <% end %>
    </div>

    <%# Save %>
    <div class="px-4 mb-6">
      <button type="submit" class="w-full bg-rad-red text-rad-cream font-bold py-[14px] rounded-[14px] hover:opacity-90 transition-opacity cursor-pointer">
        Enregistrer les réglages
      </button>
    </div>
  <% end %>

  <%# Déconnexion %>
  <div class="px-4 pb-10 text-center">
    <%= link_to "Déconnexion", student_session_path(access_code: params[:access_code]),
        data: { turbo_method: :delete },
        class: "text-sm text-rad-muted hover:text-rad-red transition-colors" %>
  </div>
</div>
```

- [ ] **Step 2 : Vérifier que les specs settings passent**

```bash
bundle exec rspec spec/features/student_api_key_configuration_spec.rb --format documentation
```

Expected : tous verts. Les specs cherchent les champs par label et les boutons par texte — conservés.

- [ ] **Step 3 : Commit**

```bash
git add app/views/student/settings/show.html.erb
git commit -m "style(student): reskin settings — rad tokens, profile card, mode toggle, drop specialty"
```

---

## Task 6 : Run specs complet + vérification manuelle

**Files:** aucun fichier modifié dans cette tâche

- [ ] **Step 1 : Run toutes les specs features student**

```bash
bundle exec rspec spec/features/ --format documentation
```

Expected : tous verts. Si un spec échoue sur un sélecteur CSS ou un texte manquant, corriger dans la vue correspondante et re-run.

- [ ] **Step 2 : Run specs components**

```bash
bundle exec rspec spec/components/ --format documentation
```

Expected : tous verts.

- [ ] **Step 3 : Vérification manuelle dark mode**

Démarrer le serveur (`bin/dev`) et vérifier manuellement en dark mode (toggle dans le navigateur ou forcer `class="dark"` sur `<html>`) :
- Login : fond `#0f2f33`, card `#143b40`, inputs `#143b40`
- Liste sujets : fond `#0f2f33`, cards `#143b40`, badges couleurs rad dark
- Réglages : fond `#0f2f33`, sections `#143b40`, selects `#1a4a50`

- [ ] **Step 4 : Invoquer superpowers:verification-before-completion**

---

## Task 7 : PR

- [ ] **Step 1 : Push et ouvrir la PR**

```bash
git push -u origin 057-student-remaining-screens-radical
gh pr create \
  --title "style(student): PR5 Radical reskin — login, subjects/index, settings" \
  --body "$(cat <<'EOF'
## Summary
- Reskin login, liste des sujets et réglages vers le design Radical (rad tokens, stripes, typographie Fraunces)
- Extend Card/Badge/ProgressBar components with rad variants
- Drop NavBarComponent from student layout (nav intégrée dans chaque vue)
- Remove specialty field from settings (managed by teacher)
- Preserve all functional behavior: login flow, subject listing, API key config, use_personal_key toggle

## Test plan
- [ ] `bundle exec rspec spec/features/student_login_and_subjects_spec.rb`
- [ ] `bundle exec rspec spec/features/student_api_key_configuration_spec.rb`
- [ ] `bundle exec rspec spec/components/`
- [ ] Vérification manuelle light + dark mode sur les 3 écrans

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

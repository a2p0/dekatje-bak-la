# Design System B2a — Atoms Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refondre `CardComponent`, `BadgeComponent`, `ButtonComponent` pour exposer une API de variantes sémantiques branchée sur les tokens B1, avec aliases legacy pixel-perfect garantissant zéro régression sur les 79 sites d'appel existants.

**Architecture:** Pour chaque composant, on rajoute des variantes sémantiques nouvelles (consommant les tokens `--color-*` livrés en B1) **à côté** des variantes existantes renommées en "aliases legacy" qui rendent strictement les mêmes classes Tailwind qu'avant. Un bugfix dédié corrige le footer Card (issue audit P1 #6) : le footer hérite désormais des tokens de la variant courante via une méthode `footer_classes` au lieu d'un `border-rad-rule` figé. Une issue GitHub trace la dette pour suppression en B4/B5.

**Tech Stack:** Ruby 3.3 / Rails 8.1.3, ViewComponent, Tailwind CSS v4 (tokens sémantiques B1), RSpec + Capybara `render_inline`, ImageMagick (validation visuelle).

**Spec source:** `docs/superpowers/specs/2026-05-25-design-system-b2a-atoms-refactor-design.md`

> ⚠️ **Token mapping correction 2026-05-26** (post-Task 3 code review)
>
> Le plan ci-dessous référence par endroits des tokens qui n'existent pas dans la couche sémantique B1 (`app/assets/tailwind/application.css`) :
>
> - `accent-warning`, `accent-success`, `accent-danger` (n'existent pas — utiliser **`warning`**, **`success`**, **`danger`**)
> - `on-accent` sans suffixe (n'existe pas — utiliser **`on-accent-primary`** / **`on-accent-secondary`** / **`on-success`** / etc. selon le bg)
> - `surface-elevated` (n'existe pas — utiliser **`surface-raised`**)
> - `text-text-primary`, `text-primary`, `text-muted`, `border-text-primary` (n'existent pas — utiliser **`text-on-surface`** / **`text-on-surface-muted`** / **`border-on-surface`**)
> - `surface-inverse`, `on-inverse` (n'existent pas — utiliser **`bg-on-surface text-surface`** = inversion sémantique)
>
> **Tokens B1 réels** disponibles dans `application.css` : `surface`, `surface-raised`, `surface-sunken`, `on-surface`, `on-surface-muted`, `rule`, `rule-strong`, `accent-primary`, `on-accent-primary`, `accent-secondary`, `on-accent-secondary`, `success`/`warning`/`danger`/`info` + leurs `on-*`.
>
> Les snippets de code dans Tasks 4-6 ci-dessous doivent être **adaptés mentalement** avec ces substitutions avant exécution. Le spec a été patché pour refléter le mapping correct ; il fait foi en cas de conflit avec le plan.

---

## File Structure

### Created
- `spec/components/card_component_spec.rb` (augmenté — existe déjà, on ajoute des examples)
- `spec/components/badge_component_spec.rb` (augmenté)
- `spec/components/button_component_spec.rb` (augmenté)

### Modified
- `app/components/card_component.rb` — refonte API (`variant`, `accent`), aliases legacy, helper `footer_classes`
- `app/components/card_component.html.erb` — footer utilise `footer_classes` au lieu de `border-rad-rule` figé
- `app/components/badge_component.rb` — refonte API (8 variantes sémantiques) + 10 aliases legacy
- `app/components/button_component.rb` — refonte API (5 variantes sémantiques) + 2 aliases legacy + états `disabled`, `loading`, focus ring

### Out of scope (no change)
- 79 sites d'appel dans `app/views/**` — restent intacts. SC-2 garantit leur rendu identique grâce aux aliases legacy.

---

## Task 0: Setup (branche + worktree)

**Files:** none (git only)

- [ ] **Step 1: Créer la worktree isolée**

```bash
git worktree add -b 066-design-system-b2a-atoms-refactor .claude/worktrees/066-b2a-atoms main
cd .claude/worktrees/066-b2a-atoms
```

Expected: branche `066-design-system-b2a-atoms-refactor` créée, working tree isolé.

- [ ] **Step 2: Vérifier que la baseline B1 est intacte**

```bash
git log --oneline -3
```

Expected: dernier commit = `c6c5fb3 chore(gitignore): exclude .design-bundles/` ou plus récent (post-B1).

- [ ] **Step 3: Vérifier les ports/process libres pour les screenshots SC-2**

```bash
lsof -i :3000 || echo "port 3000 libre"
```

Expected: port libre OU process Rails déjà tourné (à ré-utiliser).

---

## Task 1: Issue GitHub de suivi des aliases DEPRECATED

**Files:** none (gh CLI only)

L'issue doit exister AVANT le code car les commentaires `# DEPRECATED — see #N` y feront référence.

- [ ] **Step 1: Créer l'issue via gh CLI**

```bash
gh issue create \
  --title "B2 — supprimer les alias legacy des atomes refondus (Button/Badge/Card)" \
  --body "$(cat <<'EOF'
## Contexte

Suivi de la feature B2a (PR à venir) qui refond les atomes Button/Badge/Card avec une API sémantique tout en conservant les anciennes variantes en aliases legacy pour zéro régression.

## Aliases à supprimer

### ButtonComponent
- `variant: :gradient` (alias de l'ancien :primary indigo)
- `variant: :success` (rendu emerald)
- constante `PRIMARY_CLASSES`

### BadgeComponent
- `color: :indigo`
- `color: :emerald`
- `color: :amber`
- `color: :blue`
- `color: :slate`
- `color: :rose`
- `color: :rad_teal`
- `color: :rad_red`
- `color: :rad_yellow`
- `color: :rad_muted`

### CardComponent
- `variant: :rad`
- `variant: :glow`
- toute branche `case @variant when :default` legacy

## Closing

À fermer après B5 (reskin teacher) quand le dernier site d'appel aura été migré ou supprimé.

## Références
- Spec: `docs/superpowers/specs/2026-05-25-design-system-b2a-atoms-refactor-design.md`
- B1 livré: PR #102
EOF
)" \
  --label "design-system,tech-debt"
```

Expected: URL d'une nouvelle issue retournée par gh. **Noter le numéro d'issue** — on l'utilisera dans tous les commentaires `# DEPRECATED — see #N`.

- [ ] **Step 2: Stocker le numéro d'issue pour les tâches suivantes**

```bash
echo "ISSUE_NUMBER=<paste_number_here>" > /tmp/b2a_issue_number.env
cat /tmp/b2a_issue_number.env
```

Expected: contenu type `ISSUE_NUMBER=110` affiché. Ce fichier sera lu dans les commits suivants (cf. `source /tmp/b2a_issue_number.env` au besoin).

---

## Task 2: Capturer la baseline visuelle pré-B2a (SC-2)

**Files:** `tmp/screenshots/b2a-before/` (gitignored)

Capturer les 5 écrans baseline B1 + 2 écrans Card-footer (teacher/classrooms/index, student/subjects/index) en light + dark, en utilisant la même méthode que B1 (cf. mémoire `feature-065-design-tokens-b1-merged.md`).

- [ ] **Step 1: Démarrer Rails en mode dev**

```bash
bin/rails db:seed RAILS_ENV=development  # idempotent
bin/dev &
sleep 5
curl -s http://localhost:3000/up | head -1
```

Expected: `<!DOCTYPE html>` ou similaire — Rails up sur :3000.

- [ ] **Step 2: Capturer les screenshots baseline**

```bash
mkdir -p tmp/screenshots/b2a-before
# Réutiliser le script de baseline B1 — il doit exister dans specs/065-design-tokens-2-layers/
ls specs/065-design-tokens-2-layers/ 2>/dev/null | grep -i screen
```

Si un script existe (ex: `capture_baseline.rb`) :
```bash
bin/rails runner specs/065-design-tokens-2-layers/capture_baseline.rb tmp/screenshots/b2a-before
```

Sinon (créer un script minimaliste) :
```ruby
# tmp/capture_b2a_baseline.rb — à exécuter via bin/rails runner
require 'capybara'
require 'selenium-webdriver'

URLS = {
  # 5 écrans baseline B1
  "student_login"        => "/login/classes-test",
  "student_subjects"     => "/student/subjects",
  "teacher_classrooms"   => "/teacher/classrooms",
  "teacher_subjects"     => "/teacher/subjects",
  "design_preview"       => "/teacher/design-system/preview",
  # 2 écrans Card-footer
  "teacher_classrooms_footer"  => "/teacher/classrooms",   # même URL, screenshot scrollé
  "student_subjects_footer"    => "/student/subjects"
}

# Pour chaque URL, capturer en light + dark
# (Méthode exacte à reprendre du script B1 existant)
```

Expected: 14 PNG (7 URLs × 2 thèmes) dans `tmp/screenshots/b2a-before/`.

- [ ] **Step 3: Commit (rien à committer — c'est du tmp)**

```bash
git status
```

Expected: aucun changement à committer (le dossier `tmp/` est gitignored).

---

## Task 3: CardComponent — TDD bugfix footer (SC-3)

**Files:**
- Test: `spec/components/card_component_spec.rb`
- Modify: `app/components/card_component.rb`
- Modify: `app/components/card_component.html.erb`

Premier composant, on commence par le bugfix car c'est le plus chirurgical.

- [ ] **Step 1: Écrire le test qui prouve le bug actuel (RED)**

Ouvrir `spec/components/card_component_spec.rb`, ajouter à la fin :

```ruby
  describe "footer inherits variant tokens (bugfix audit P1 #6)" do
    it "for variant :hero with accent :success, footer border uses accent-success (not rad-rule)" do
      render_inline(described_class.new(variant: :hero, accent: :success)) do |card|
        card.with_body { "body" }
        card.with_footer { "footer" }
      end

      footer_div = page.find("div", text: "footer")
      footer_classes = footer_div[:class]

      # Le bug actuel : footer rend "border-t border-rad-rule" en dur
      # Cible : il doit utiliser un token cohérent avec la variant hero (ex: accent-success ou un on-accent border)
      expect(footer_classes).not_to include("border-rad-rule")
      expect(footer_classes).to include("border-accent-success").or include("border-on-accent")
    end
  end
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue (RED)**

```bash
bin/rspec spec/components/card_component_spec.rb -e "footer inherits variant tokens"
```

Expected: 1 example, 1 failure. Le test rouge confirme le bug (`expected ... not to include "border-rad-rule"`).

- [ ] **Step 3: Refondre `card_component.rb` avec API cible + aliases legacy + helper `footer_classes`**

Remplacer **tout le contenu** de `app/components/card_component.rb` par :

```ruby
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :footer

  ACCENT_TOKENS = {
    primary:   "accent-primary",
    secondary: "accent-secondary",
    warning:   "accent-warning",
    success:   "accent-success"
  }.freeze

  def initialize(variant: :default, accent: nil)
    @variant = variant.to_sym
    @accent = accent&.to_sym
  end

  def card_classes
    base = "rounded-2xl overflow-hidden"

    case @variant
    when :default
      "#{base} bg-surface border border-rule"
    when :elevated
      "#{base} bg-surface-elevated border border-rule shadow-sm"
    when :hero
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} bg-#{accent_token} text-on-accent"
    when :outlined
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} bg-transparent border-l-4 border-#{accent_token}"
    # DEPRECATED — see #<ISSUE_NUMBER>
    when :rad
      "#{base} bg-rad-paper border border-rad-rule"
    # DEPRECATED — see #<ISSUE_NUMBER>
    when :glow
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-indigo-500/15 dark:shadow-[0_0_15px_rgba(99,102,241,0.05)] transition-shadow hover:shadow-md dark:hover:shadow-[0_0_25px_rgba(99,102,241,0.15)]"
    else
      # DEPRECATED legacy default — preserve pixel-perfect rendering — see #<ISSUE_NUMBER>
      "#{base} bg-white dark:bg-slate-800/80 border border-slate-200 shadow-sm dark:border-slate-700 dark:shadow-none"
    end
  end

  def footer_classes
    base = "px-5 py-4 border-t"

    case @variant
    when :hero
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      # hero variant on dark accent bg: border continues the accent color, slightly opacified
      "#{base} border-#{accent_token}"
    when :outlined
      accent_token = ACCENT_TOKENS.fetch(@accent || :primary)
      "#{base} border-#{accent_token}/30"
    when :default, :elevated
      "#{base} border-rule"
    # DEPRECATED legacy variants — preserve pre-B2a rendering — see #<ISSUE_NUMBER>
    else
      "#{base} border-rad-rule"
    end
  end
end
```

**IMPORTANT**: remplacer chaque `#<ISSUE_NUMBER>` par le numéro lu depuis `/tmp/b2a_issue_number.env`.

- [ ] **Step 4: Modifier le template ERB pour utiliser `footer_classes`**

Remplacer **tout le contenu** de `app/components/card_component.html.erb` par :

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
    <div class="<%= footer_classes %>">
      <%= footer %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Relancer le test bugfix (GREEN)**

```bash
bin/rspec spec/components/card_component_spec.rb -e "footer inherits variant tokens"
```

Expected: 1 example, 0 failures.

- [ ] **Step 6: Lancer le spec complet du Card pour vérifier qu'on ne casse rien**

```bash
bin/rspec spec/components/card_component_spec.rb
```

Expected: tous les examples passent (les anciens + le nouveau).

Si un ancien test casse (par ex. attendait `border-rad-rule` en dur sur le footer du variant default) : ce test exprimait le bug, **le mettre à jour** pour refléter la cible (footer default doit avoir `border-rule`, pas `border-rad-rule`).

- [ ] **Step 7: Commit**

```bash
git add app/components/card_component.rb app/components/card_component.html.erb spec/components/card_component_spec.rb
git commit -m "fix(b2a): card footer inherits variant tokens (audit P1 #6)

footer_classes helper replaces hardcoded border-rad-rule.
hero/outlined variants now produce a footer border cohérent with accent.
default/elevated use semantic --color-rule token.
Legacy variants :rad/:glow preserved as deprecated aliases."
```

---

## Task 4: CardComponent — specs pour nouvelles variantes sémantiques

**Files:**
- Test: `spec/components/card_component_spec.rb`

Couvre 4 variantes × accent + aliases legacy + slots.

- [ ] **Step 1: Ajouter le bloc specs pour les nouvelles variantes**

Ajouter à la fin de `spec/components/card_component_spec.rb` (avant le `end` final de `RSpec.describe`) :

```ruby
  describe "new semantic variants" do
    it ":default renders bg-surface + border-rule" do
      render_inline(described_class.new(variant: :default)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-surface.border.border-rule.rounded-2xl")
    end

    it ":elevated renders bg-surface-elevated + shadow" do
      render_inline(described_class.new(variant: :elevated)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-surface-elevated.shadow-sm")
    end

    it ":hero with accent :success renders bg-accent-success + text-on-accent" do
      render_inline(described_class.new(variant: :hero, accent: :success)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-accent-success.text-on-accent.rounded-2xl")
    end

    it ":hero defaults to accent :primary when none provided" do
      render_inline(described_class.new(variant: :hero)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-accent-primary.text-on-accent")
    end

    it ":outlined with accent :warning renders border-l-4 + border-accent-warning" do
      render_inline(described_class.new(variant: :outlined, accent: :warning)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-transparent.border-l-4.border-accent-warning")
    end

    it ":outlined defaults to accent :primary when none provided" do
      render_inline(described_class.new(variant: :outlined)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.border-accent-primary")
    end
  end

  describe "deprecated legacy variants (pixel-perfect baseline)" do
    it ":rad renders the original bg-rad-paper classes" do
      render_inline(described_class.new(variant: :rad)) do |c|
        c.with_body { "x" }
      end
      expect(page).to have_css("div.bg-rad-paper.border.border-rad-rule.rounded-2xl")
    end

    it ":glow renders the original indigo glow classes" do
      render_inline(described_class.new(variant: :glow)) do |c|
        c.with_body { "x" }
      end
      # Présence des classes clé d'origine
      expect(page).to have_css("div.bg-white.shadow-sm")
      # On vérifie une classe distinctive du glow
      html = page.native.to_html
      expect(html).to include("dark:shadow-[0_0_15px_rgba(99,102,241,0.05)]")
    end
  end
```

- [ ] **Step 2: Lancer le spec complet du Card**

```bash
bin/rspec spec/components/card_component_spec.rb
```

Expected: tous les examples passent (anciens + nouveaux variants + aliases).

- [ ] **Step 3: Commit**

```bash
git add spec/components/card_component_spec.rb
git commit -m "test(b2a): card semantic variants + legacy aliases"
```

---

## Task 5: BadgeComponent — refonte + tests (TDD)

**Files:**
- Modify: `app/components/badge_component.rb`
- Test: `spec/components/badge_component_spec.rb`

- [ ] **Step 1: Grep les sites d'appel actuels pour figer le mapping specialty**

```bash
grep -rn "color: :rad_yellow\|color: :rad_teal" app/views | grep -i "specialty\|specialite\|spé"
grep -rn "BadgeComponent" app/views | grep -i "specialty\|specialite"
```

Expected: liste limitée. Si une vue passe aujourd'hui `:rad_yellow` ou `:rad_teal` pour la spécialité, noter ce mapping (à utiliser dans les variantes `:specialty_*`).

**Mapping cible figé** (à utiliser dans la refonte, ajuster si grep révèle un usage existant qu'il faudrait préserver) :
- `:specialty_sin` → `bg-accent-secondary/10 text-accent-secondary border-accent-secondary/20` (teal)
- `:specialty_itec` → `bg-accent-warning/10 text-accent-warning border-accent-warning/20` (amber)
- `:specialty_ec` → `bg-accent-primary/10 text-accent-primary border-accent-primary/20` (rouge/teal selon audience)

- [ ] **Step 2: Écrire les specs pour nouvelles variantes sémantiques (RED)**

Ajouter à `spec/components/badge_component_spec.rb` (à la fin, avant le `end` final) :

```ruby
  describe "new semantic variants" do
    {
      primary:   "accent-primary",
      secondary: "accent-secondary",
      warning:   "accent-warning",
      success:   "accent-success"
    }.each do |variant, token|
      it ":#{variant} renders bg-#{token}/10 + text-#{token}" do
        render_inline(described_class.new(color: variant, label: "x"))
        expect(page).to have_css("span.bg-#{token}\\/10.text-#{token}")
      end
    end

    it ":neutral renders rule + text-muted" do
      render_inline(described_class.new(color: :neutral, label: "x"))
      expect(page).to have_css("span.bg-rule\\/40.text-text-muted")
    end

    it ":specialty_sin renders accent-secondary token (teal)" do
      render_inline(described_class.new(color: :specialty_sin, label: "SIN"))
      expect(page).to have_css("span.bg-accent-secondary\\/10.text-accent-secondary")
    end

    it ":specialty_itec renders accent-warning token (amber)" do
      render_inline(described_class.new(color: :specialty_itec, label: "ITEC"))
      expect(page).to have_css("span.bg-accent-warning\\/10.text-accent-warning")
    end

    it ":specialty_ec renders accent-primary token" do
      render_inline(described_class.new(color: :specialty_ec, label: "EC"))
      expect(page).to have_css("span.bg-accent-primary\\/10.text-accent-primary")
    end
  end

  describe "deprecated legacy colors (pixel-perfect baseline)" do
    {
      indigo:     "bg-indigo-100",
      emerald:    "bg-emerald-100",
      amber:      "bg-amber-100",
      blue:       "bg-blue-100",
      slate:      "bg-slate-200",
      rose:       "bg-rose-100",
      rad_teal:   "bg-rad-teal/10",
      rad_red:    "bg-rad-red/10",
      rad_yellow: "bg-rad-yellow/15",
      rad_muted:  "bg-rad-rule/40"
    }.each do |color, expected_bg|
      it ":#{color} preserves the original bg class #{expected_bg}" do
        render_inline(described_class.new(color: color, label: "x"))
        # On vérifie via le HTML brut pour gérer les classes contenant '/'
        expect(page.native.to_html).to include(expected_bg)
      end
    end
  end
```

- [ ] **Step 3: Lancer les specs pour vérifier qu'ils échouent (RED)**

```bash
bin/rspec spec/components/badge_component_spec.rb -e "new semantic variants"
```

Expected: 7+ failures (les nouvelles variantes n'existent pas encore dans le composant).

- [ ] **Step 4: Refondre `badge_component.rb`**

Remplacer **tout le contenu** de `app/components/badge_component.rb` par :

```ruby
class BadgeComponent < ViewComponent::Base
  # Pattern sémantique : bg-{token}/10 + text-{token} + border-{token}/20
  SEMANTIC_BASE = "border".freeze

  COLORS = {
    # Variantes sémantiques (cibles)
    primary:   "bg-accent-primary/10 text-accent-primary border-accent-primary/20",
    secondary: "bg-accent-secondary/10 text-accent-secondary border-accent-secondary/20",
    warning:   "bg-accent-warning/10 text-accent-warning border-accent-warning/20",
    success:   "bg-accent-success/10 text-accent-success border-accent-success/20",
    neutral:   "bg-rule/40 text-text-muted border-rule",

    # Variantes spécialités (sémantique métier)
    specialty_sin:  "bg-accent-secondary/10 text-accent-secondary border-accent-secondary/20",
    specialty_itec: "bg-accent-warning/10 text-accent-warning border-accent-warning/20",
    specialty_ec:   "bg-accent-primary/10 text-accent-primary border-accent-primary/20",

    # DEPRECATED — see #<ISSUE_NUMBER> — preserved pixel-perfect for zero regression
    indigo:    "bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-400",
    emerald:   "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-400",
    amber:     "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-400",
    blue:      "bg-blue-100 text-blue-700 dark:bg-blue-500/15 dark:text-blue-400",
    slate:     "bg-slate-200 text-slate-700 dark:bg-slate-500/15 dark:text-slate-400",
    rose:      "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-400",
    rad_teal:  "bg-rad-teal/10 text-rad-teal border border-rad-teal/20",
    rad_red:   "bg-rad-red/10 text-rad-red border border-rad-red/20",
    rad_yellow: "bg-rad-yellow/15 text-rad-ink border border-rad-yellow/30",
    rad_muted: "bg-rad-rule/40 text-rad-muted border border-rad-rule"
  }.freeze

  SEMANTIC_COLORS = %i[primary secondary warning success neutral specialty_sin specialty_itec specialty_ec].freeze

  def initialize(color:, label:)
    @color = color.to_sym
    @label = label
  end

  def call
    css = class_names(
      "inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium",
      SEMANTIC_COLORS.include?(@color) ? SEMANTIC_BASE : nil,
      COLORS[@color]
    )

    content_tag(:span, @label, class: css)
  end
end
```

**IMPORTANT**: substituer `#<ISSUE_NUMBER>` par le numéro lu depuis `/tmp/b2a_issue_number.env`.

- [ ] **Step 5: Relancer les specs (GREEN)**

```bash
bin/rspec spec/components/badge_component_spec.rb
```

Expected: tous les examples passent (anciens + nouvelles variantes + aliases legacy).

Si une vue existante (cf. grep step 1) utilise déjà une syntaxe specialty et que le rendu change : alerter, ajuster le mapping pour préserver, puis re-tester. **Critère SC-2**: aucun rendu pré-existant ne doit changer.

- [ ] **Step 6: Commit**

```bash
git add app/components/badge_component.rb spec/components/badge_component_spec.rb
git commit -m "refactor(b2a): badge semantic API + legacy aliases

8 nouvelles variantes sémantiques (primary, secondary, warning, success,
neutral, specialty_sin/itec/ec) consomment les tokens B1.
10 aliases legacy (indigo, emerald, amber, blue, slate, rose, rad_*)
conservent pixel-perfect leur rendu pré-B2a.

Param color: préservé pour zéro migration de vue (cf. spec §3.2)."
```

---

## Task 6: ButtonComponent — refonte API + nouvelles variantes (TDD)

**Files:**
- Modify: `app/components/button_component.rb`
- Test: `spec/components/button_component_spec.rb`

Le plus risqué (18 sites d'appel, états nouveaux).

- [ ] **Step 1: Écrire les specs nouvelles variantes (RED)**

Ajouter à `spec/components/button_component_spec.rb` (à la fin) :

```ruby
  describe "new semantic variants" do
    it ":primary renders bg-accent-primary + text-on-accent" do
      render_inline(described_class.new(variant: :primary))
      expect(page).to have_css("button.bg-accent-primary.text-on-accent")
    end

    it ":secondary renders border-text-primary outline + transparent bg" do
      render_inline(described_class.new(variant: :secondary))
      expect(page).to have_css("button.border.bg-transparent.text-text-primary")
    end

    it ":ghost renders transparent bg + text-muted" do
      render_inline(described_class.new(variant: :ghost))
      expect(page).to have_css("button.bg-transparent.text-text-muted")
    end

    it ":danger renders bg-accent-danger + text-on-accent" do
      render_inline(described_class.new(variant: :danger))
      expect(page).to have_css("button.bg-accent-danger.text-on-accent")
    end

    it ":ink renders bg-surface-inverse + text-on-inverse" do
      render_inline(described_class.new(variant: :ink))
      expect(page).to have_css("button.bg-surface-inverse.text-on-inverse")
    end
  end

  describe "deprecated legacy variants (pixel-perfect baseline)" do
    it ":gradient preserves the original indigo gradient classes" do
      render_inline(described_class.new(variant: :gradient))
      html = page.native.to_html
      expect(html).to include("from-indigo-500")
      expect(html).to include("to-violet-500")
    end

    it ":success preserves the original emerald classes" do
      render_inline(described_class.new(variant: :success))
      expect(page).to have_css("button.bg-emerald-500.text-white")
    end
  end

  describe "states" do
    it "disabled: true renders aria-disabled + opacity-60" do
      render_inline(described_class.new(variant: :primary, disabled: true))
      expect(page).to have_css("button[aria-disabled='true']")
      expect(page.native.to_html).to include("opacity-60")
    end

    it "loading: true renders aria-busy + a spinner span" do
      render_inline(described_class.new(variant: :primary, loading: true)) { "Submit" }
      expect(page).to have_css("button[aria-busy='true']")
      expect(page).to have_css("button span.animate-spin", visible: :all)
    end

    it "focus-visible ring uses accent-secondary + offset-2" do
      render_inline(described_class.new(variant: :primary))
      html = page.native.to_html
      expect(html).to include("focus-visible:ring-accent-secondary")
      expect(html).to include("focus-visible:ring-offset-2")
    end
  end

  describe "structural props" do
    it ":href renders an <a> element" do
      render_inline(described_class.new(variant: :primary, href: "/foo")) { "link" }
      expect(page).to have_css("a[href='/foo']")
    end

    it ":pill renders rounded-full" do
      render_inline(described_class.new(variant: :primary, pill: true))
      expect(page).to have_css("button.rounded-full")
    end

    %i[sm md lg].each do |size|
      it "size #{size} renders the matching size class" do
        render_inline(described_class.new(variant: :primary, size: size))
        case size
        when :sm then expect(page).to have_css("button.px-3.py-1\\.5.text-xs")
        when :md then expect(page).to have_css("button.px-4.py-2.text-sm")
        when :lg then expect(page).to have_css("button.px-6.py-3.text-base")
        end
      end
    end
  end
```

- [ ] **Step 2: Lancer les specs pour vérifier qu'ils échouent (RED)**

```bash
bin/rspec spec/components/button_component_spec.rb -e "new semantic variants"
```

Expected: 5+ failures.

- [ ] **Step 3: Refondre `button_component.rb`**

Remplacer **tout le contenu** de `app/components/button_component.rb` par :

```ruby
class ButtonComponent < ViewComponent::Base
  # DEPRECATED — see #<ISSUE_NUMBER>
  LEGACY_PRIMARY_CLASSES = "bg-gradient-to-br from-indigo-500 to-violet-500 text-white hover:from-indigo-600 hover:to-violet-600 focus-visible:ring-indigo-500 shadow-[0_0_16px_rgba(99,102,241,0.3)] disabled:opacity-60 disabled:saturate-50 disabled:shadow-none".freeze

  VARIANTS = {
    # Variantes sémantiques (cibles)
    primary:   "bg-accent-primary text-on-accent hover:bg-accent-primary/90 focus-visible:ring-accent-secondary",
    secondary: "bg-transparent border border-text-primary text-text-primary hover:bg-surface-elevated focus-visible:ring-accent-secondary",
    ghost:     "bg-transparent text-text-muted hover:bg-surface-elevated focus-visible:ring-accent-secondary",
    danger:    "bg-accent-danger text-on-accent hover:bg-accent-danger/90 focus-visible:ring-accent-secondary",
    ink:       "bg-surface-inverse text-on-inverse hover:bg-surface-inverse/90 focus-visible:ring-accent-secondary",

    # DEPRECATED — see #<ISSUE_NUMBER> — preserved pixel-perfect
    gradient: LEGACY_PRIMARY_CLASSES,
    success:  "bg-emerald-500 text-white hover:bg-emerald-600 focus-visible:ring-emerald-500 disabled:opacity-60"
  }.freeze

  SEMANTIC_VARIANTS = %i[primary secondary ghost danger ink].freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  def initialize(variant: :primary, size: :md, pill: false, href: nil,
                 disabled: false, loading: false, **html_options)
    @variant = variant.to_sym
    @size = size.to_sym
    @pill = pill
    @href = href
    @disabled = disabled
    @loading = loading
    @html_options = html_options
  end

  def call
    css = class_names(
      "inline-flex items-center justify-center gap-2 font-semibold transition-all",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2",
      "cursor-pointer disabled:cursor-not-allowed",
      VARIANTS[@variant],
      SIZES[@size],
      @pill ? "rounded-full" : "rounded-lg",
      @disabled || @loading ? "opacity-60 cursor-not-allowed" : nil
    )

    extra_attrs = @html_options.dup
    extra_attrs[:"aria-disabled"] = "true" if @disabled
    extra_attrs[:"aria-busy"]     = "true" if @loading
    extra_attrs[:disabled]        = true   if @disabled || @loading

    inner = if @loading
              # spinner SVG inline + content
              spinner = content_tag(:span, "", class: "inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-r-transparent", "aria-hidden": "true")
              safe_join([spinner, content])
            else
              content
            end

    if @href
      # On retire les attrs spécifiques <button> pour un <a>
      extra_attrs.delete(:disabled)
      content_tag(:a, inner, href: @href, class: css, **extra_attrs)
    else
      content_tag(:button, inner, class: css, **extra_attrs)
    end
  end
end
```

**IMPORTANT**: substituer `#<ISSUE_NUMBER>` par le numéro lu depuis `/tmp/b2a_issue_number.env`.

- [ ] **Step 4: Relancer les specs (GREEN)**

```bash
bin/rspec spec/components/button_component_spec.rb
```

Expected: tous les examples passent (anciens + nouvelles variantes + états + structural).

- [ ] **Step 5: Vérifier la pixel-perfection de l'alias `gradient` vis-à-vis de l'ancien `primary`**

Comparer ce que rendait `ButtonComponent.new(variant: :primary)` AVANT B2a (= `LEGACY_PRIMARY_CLASSES`) à ce que rend MAINTENANT `ButtonComponent.new(variant: :gradient)` (= même `LEGACY_PRIMARY_CLASSES`). C'est par construction identique, mais on capture aussi visuellement à la prochaine task.

⚠️ **Risque connu** : les vues actuelles passent souvent `variant: :primary` (qui rendait l'indigo gradient). Désormais `:primary` rend le rouge accent-primary (Radical). **C'est une régression visuelle SC-2 sur ces sites d'appel** sauf si on les laisse tels quels — et c'est précisément ce qu'on fait : 0 migration.

**Décision SC-2** : on doit donc faire en sorte que `:primary` continue à rendre l'indigo gradient sur les 18 sites d'appel existants… ce qui contredit l'objectif d'une API sémantique propre.

**Résolution** : faire `:primary` rendre l'**indigo gradient** dans l'ancien comportement (= maintenir la rétrocompat), et créer une nouvelle variante `:rad_primary` pour la cible sémantique. NON, ça crée deux APIs.

**Décision révisée (à valider avec l'utilisateur)** : **inverser** la stratégie sur Button :
- `variant: :primary` rend désormais `accent-primary` (la cible sémantique)
- Les 18 sites d'appel qui passent `:primary` rendront du rouge Radical, pas de l'indigo
- Cela **change le rendu visuel** sur teacher (mais teacher sera reskiné en B5 — la dérive est anticipée)
- Le bon alias legacy est `variant: :gradient` que personne n'utilise (à grep pour confirmer)

```bash
grep -rn "variant: :primary\|variant: :gradient" app/views | wc -l
grep -rn "variant: :primary" app/views | head
```

Si les vues passent majoritairement `variant: :primary` → SC-2 ne sera PAS atteint sur Button. Deux choix pour l'utilisateur :

(A) **Garder SC-2 strict** : renommer `:primary` → `:rad_primary` côté sémantique, garder `:primary` en alias indigo gradient legacy.
(B) **Accepter dérive visuelle Button** : `:primary` devient le rouge Radical, le screenshot diff sera != 0 sur les écrans qui utilisent Button — on documente que c'est attendu et anticipe B5.

**Default plan** : poser la question à l'utilisateur AVANT le commit Button (cf. Task 7 step 1). Le code ci-dessus présume (B).

- [ ] **Step 6: Commit (provisoire — bloqué par la décision SC-2 Task 7)**

```bash
git add app/components/button_component.rb spec/components/button_component_spec.rb
git commit -m "refactor(b2a): button semantic API + legacy aliases + states

5 nouvelles variantes sémantiques (primary, secondary, ghost, danger, ink)
consomment les tokens B1.
2 aliases legacy (gradient = indigo, success = emerald).
Nouveaux états : disabled (aria-disabled + opacity), loading (spinner +
aria-busy), focus ring accent-secondary (audit P1 #5).

⚠️ variant: :primary change de rendu (indigo → accent-primary).
Voir Task 7 pour résolution SC-2."
```

---

## Task 7: Décision SC-2 sur Button — clarification avec l'utilisateur

**Files:** none (interactif)

- [ ] **Step 1: Compter combien de sites passent `variant: :primary` explicitement**

```bash
echo "=== usages explicites de :primary ==="
grep -rn "variant: :primary" app/views | wc -l
grep -rn "variant: :primary" app/views

echo "=== usages explicites de :gradient ==="
grep -rn "variant: :gradient" app/views | wc -l
grep -rn "variant: :gradient" app/views

echo "=== usages sans variant: (= default :primary implicite) ==="
grep -rn "ButtonComponent.new" app/views | grep -v "variant:" | wc -l
```

- [ ] **Step 2: Présenter le diagnostic à l'utilisateur**

Reporter à l'utilisateur :
- N usages `:primary` explicite
- M usages `:gradient` explicite
- P usages implicite (= :primary par défaut)
- Total exposé à la dérive si on garde le code de Task 6 : N+P

Demander :
- **(A) SC-2 strict** : renommer cible sémantique → `:rad_primary` ; restaurer `:primary` comme alias indigo gradient.
- **(B) Accepter dérive Button** : laisser le code de Task 6 tel quel, documenter la dérive comme attendue (à corriger en B5).

- [ ] **Step 3: Si (A) — appliquer le rename `:primary` → `:rad_primary`**

Si l'utilisateur choisit (A) :
1. Dans `app/components/button_component.rb`, renommer la clé `primary:` du hash en `rad_primary:` dans la zone sémantique
2. Ajouter une nouvelle clé `primary:` dans la zone DEPRECATED qui pointe sur `LEGACY_PRIMARY_CLASSES`
3. Adapter `SEMANTIC_VARIANTS = %i[rad_primary secondary ghost danger ink]`
4. Mettre à jour `button_component_spec.rb` :
   - Renommer le test `:primary renders bg-accent-primary` en `:rad_primary renders bg-accent-primary`
   - Ajouter un test `:primary preserves the original indigo gradient classes`
5. Commit :
   ```bash
   git add app/components/button_component.rb spec/components/button_component_spec.rb
   git commit -m "refactor(b2a): rename Button :primary cible sémantique → :rad_primary

   Préserve SC-2 strict : :primary continue à rendre l'indigo gradient
   pour les 18 sites d'appel existants. La nouvelle variante :rad_primary
   est la cible sémantique consommant accent-primary.

   Suppression du rename prévue en B5 quand teacher migrera."
   ```

- [ ] **Step 4: Si (B) — laisser tel quel et documenter**

Si l'utilisateur choisit (B) :
1. Créer/Mettre à jour `docs/superpowers/notes/b2a-known-deviations.md` :
   ```markdown
   # B2a — dérives visuelles connues sur Button

   Les sites d'appel passant `variant: :primary` (~N sites côté teacher) verront
   le rendu changer d'indigo gradient → rouge Radical (accent-primary).

   Décision validée par l'utilisateur le 2026-05-25 : on accepte cette dérive
   car teacher sera reskiné en B5 (où ce rouge sera de toute façon la cible).

   SC-2 reste vert sur les écrans student et sur les autres composants
   (Badge, Card) qui n'ont pas ce piège.
   ```
2. Commit :
   ```bash
   git add docs/superpowers/notes/b2a-known-deviations.md
   git commit -m "docs(b2a): document expected Button :primary visual drift"
   ```

---

## Task 8: Capture visuelle post-B2a + diff SC-2

**Files:** `tmp/screenshots/b2a-after/`, `tmp/screenshots/b2a-diff/`

- [ ] **Step 1: Capturer les screenshots post-B2a**

```bash
mkdir -p tmp/screenshots/b2a-after
bin/dev &  # si pas déjà tourné
sleep 5
bin/rails runner tmp/capture_b2a_baseline.rb tmp/screenshots/b2a-after  # ou le script B1 réutilisé
```

Expected: 14 PNG dans `tmp/screenshots/b2a-after/`.

- [ ] **Step 2: Diff ImageMagick par paire**

```bash
mkdir -p tmp/screenshots/b2a-diff
for f in tmp/screenshots/b2a-before/*.png; do
  name=$(basename "$f")
  compare -metric AE "$f" "tmp/screenshots/b2a-after/$name" "tmp/screenshots/b2a-diff/$name" 2>&1 | tee -a tmp/screenshots/b2a-diff/_metrics.log
  echo " ← $name"
done
cat tmp/screenshots/b2a-diff/_metrics.log
```

Expected pour décision (B) : AE=0 sur tous les écrans **sauf** ceux qui contiennent un Button `:primary`. La log précise quels écrans ont dérivé — vérifier qu'ils correspondent à la dérive attendue.

Expected pour décision (A) : AE=0 sur **tous** les écrans.

Si AE > 0 sur un écran qui ne devrait pas dériver : investigation. Causes probables :
- Un alias legacy a divergé (revérifier la string de classes)
- Un site d'appel utilise une variante qu'on aurait pas anticipée
- Un effet de cascade Tailwind (token sémantique qui calcule différemment qu'avant)

- [ ] **Step 3: Documenter le résultat dans le journal de feature**

Créer `docs/superpowers/journals/2026-05-25-b2a-visual-diff.md` :

```markdown
# B2a — Validation visuelle SC-2

Date : 2026-05-25
Mode : (A) SC-2 strict | (B) dérive Button acceptée  ← cocher

## Résultats AE par écran

| Écran | Light AE | Dark AE | Dérive attendue ? |
|---|---|---|---|
| student_login | <X> | <X> | non |
| student_subjects | <X> | <X> | non |
| teacher_classrooms | <X> | <X> | <oui si Button :primary visible> |
| teacher_subjects | <X> | <X> | <idem> |
| design_preview | <X> | <X> | non |
| teacher_classrooms_footer | <X> | <X> | non (bugfix footer attendu sur défaut → pas d'écran avec hero footer) |
| student_subjects_footer | <X> | <X> | non |

## Anomalies

[Liste des dérives non attendues, ou "aucune"]

## Verdict

SC-2 ☑ atteint / ☐ partiel — détails ci-dessus.
```

- [ ] **Step 4: Commit du journal**

```bash
git add docs/superpowers/journals/2026-05-25-b2a-visual-diff.md
git commit -m "docs(b2a): journal validation visuelle SC-2"
```

---

## Task 9: Vérification d'ensemble + grep sanity checks

**Files:** none

- [ ] **Step 1: Suite RSpec ViewComponent complète**

```bash
bin/rspec spec/components/
```

Expected: 100% pass.

- [ ] **Step 2: Grep — aucune couleur hardcodée dans les nouvelles variantes**

```bash
echo "=== chercher couleurs Tailwind dans les variantes sémantiques (devrait être vide ou n'apparaître que dans les blocs DEPRECATED) ==="
grep -E "bg-(indigo|emerald|violet|slate|amber|blue|rose)-[0-9]" app/components/button_component.rb app/components/badge_component.rb app/components/card_component.rb
```

Expected: matches uniquement dans les zones marquées `DEPRECATED` (LEGACY_*, aliases). Aucune dans les blocs sémantiques.

- [ ] **Step 3: Grep — chaque alias DEPRECATED référence l'issue**

```bash
grep -B1 "DEPRECATED" app/components/button_component.rb app/components/badge_component.rb app/components/card_component.rb | grep -c "see #"
```

Expected: au moins 3 occurrences (un par fichier).

- [ ] **Step 4: Suite complète Rails**

```bash
bin/rspec
```

Expected: 100% pass — pas de spec cassé par effet de bord (les vues existantes utilisent les aliases legacy).

Si une spec system/feature échoue : c'est probablement un site d'appel qui utilise une variante qu'on n'aurait pas correctement mappée. Investigation.

- [ ] **Step 5: Commit final si reliquats (sinon skip)**

S'il reste des correctifs après les vérifications :
```bash
git add -p
git commit -m "fix(b2a): <description précise>"
```

---

## Task 10: Push + ouvrir la PR

**Files:** none (git/gh only)

- [ ] **Step 1: Push de la branche**

```bash
git push -u origin 066-design-system-b2a-atoms-refactor
```

- [ ] **Step 2: Créer la PR via gh CLI**

```bash
gh pr create \
  --title "feat(b2a): refonte atomes Button/Badge/Card avec API sémantique" \
  --body "$(cat <<'EOF'
## Summary

- Refonte des 3 composants atomiques `ButtonComponent`, `BadgeComponent`, `CardComponent` avec une API de variantes sémantiques consommant les tokens B1 (`accent-primary`, `surface`, `on-accent`, etc.)
- Aliases legacy conservés pixel-perfect pour zéro régression sur les 79 sites d'appel
- Bugfix audit P1 #6 : footer Card hérite désormais des tokens de la variant courante
- Nouveaux états ButtonComponent : `disabled:`, `loading:`, focus ring `accent-secondary`

## Test plan

- [x] Specs ViewComponent verts (nouvelles variantes + aliases legacy + bugfix footer + états)
- [x] Diff visuel ImageMagick AE=0 sur baseline B1 étendue (sauf dérive Button :primary documentée — cf. docs/superpowers/notes/b2a-known-deviations.md si applicable)
- [x] Aucune couleur Tailwind hardcodée dans les variantes sémantiques (grep verified)
- [x] Chaque alias DEPRECATED référence l'issue GitHub de suivi
- [x] CI verte

## Références

- Spec : `docs/superpowers/specs/2026-05-25-design-system-b2a-atoms-refactor-design.md`
- Plan : `docs/superpowers/plans/2026-05-25-design-system-b2a-atoms-refactor.md`
- Issue de suivi : #<ISSUE_NUMBER>
- Prérequis : PR #102 (B1 tokens 2 couches)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**IMPORTANT**: substituer `<ISSUE_NUMBER>` par le numéro réel.

- [ ] **Step 3: Vérifier la CI**

```bash
gh pr checks --watch
```

Expected: tous les checks verts.

Si rouge : lire les logs (`gh run view <run-id> --log-failed`), corriger, push.

- [ ] **Step 4: Mémoriser la PR**

Une fois la CI verte, écrire une mémoire projet `project_b2a_atoms_refactor_pr.md` avec :
- Numéro de PR
- Décision SC-2 retenue ((A) ou (B))
- Issue de suivi
- Statut (ouverte / mergée)

---

## Self-Review

**Spec coverage check:**

| Spec section | Couverte par |
|---|---|
| 3.1 In scope — nouvelles variantes Button | Task 6 |
| 3.1 In scope — nouvelles variantes Badge | Task 5 |
| 3.1 In scope — nouvelles variantes Card | Tasks 3+4 |
| 3.1 In scope — aliases pixel-perfect | Tasks 3, 4 step 1, 5, 6 |
| 3.1 In scope — bugfix footer Card | Task 3 |
| 3.1 In scope — états Button (disabled, loading, focus ring) | Task 6 |
| 3.1 In scope — tests RSpec ViewComponent | Tasks 3, 4, 5, 6 |
| 3.1 In scope — issue GitHub de suivi | Task 1 |
| 4 SC-1 (tokens utilisés) | Task 9 step 2 |
| 4 SC-2 (zéro régression visuelle) | Tasks 2 + 8 + 7 (décision) |
| 4 SC-3 (footer bugfix) | Task 3 |
| 4 SC-4 (tests pass) | Task 9 step 1 |
| 4 SC-5 (issue référencée) | Task 9 step 3 |
| 5.5 Ordre Card → Badge → Button | Tasks 3-4 → 5 → 6 ✓ |
| 9 Définition de "terminé" | Couverte par Tasks 1-10 |

Le piège SC-2 sur `Button :primary` n'était pas explicitement adressé dans le spec — Task 7 le rend explicite et demande arbitrage utilisateur. C'est une amélioration du spec, pas une déviation.

**Placeholder scan:** Trois occurrences de `<ISSUE_NUMBER>` dans le code Ruby — c'est volontaire et documenté (Task 1 step 2 explique le mécanisme). `<paste_number_here>` dans Task 1 step 2 — c'est une saisie utilisateur explicite.

**Type consistency:** `SEMANTIC_VARIANTS`/`SEMANTIC_COLORS` cohérents. `ACCENT_TOKENS` (Card) défini une fois et utilisé pour `card_classes` et `footer_classes`. Pas de dérive de nom de méthode/constante entre les tasks.

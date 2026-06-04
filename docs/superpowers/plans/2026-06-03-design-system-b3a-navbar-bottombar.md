# B3a — Refonte tokens NavBar + BottomBar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aligner `NavBarComponent` et `BottomBarComponent` sur les tokens sémantiques B1 (`surface`, `on-surface`, `accent-primary`...) en supprimant les classes Tailwind legacy (`slate-*`, `indigo-*`, `violet-*`, `emerald-*`) et en retirant 1 slot mort (`with_breadcrumb`) + 1 variant mort (`:gradient`).

**Architecture:** Refonte directe des 2 composants ViewComponent (1 site d'appel pour NavBar, 0 pour BottomBar — pas de DEPRECATED aliases). Tests RSpec rendering + B1 contract guard (UNDEFINED_TOKENS pattern). Aucune adoption sur `student/questions/show` (convergence tokens rad-*/B1 reportée).

**Tech Stack:** Rails 8.1.3 + ViewComponent + Tailwind CSS v4 + RSpec.

**Spec:** `docs/superpowers/specs/2026-06-03-design-system-b3a-navbar-bottombar-design.md`

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `app/components/nav_bar_component.rb` | Slots + lien helper | **Modify** (retrait slot breadcrumb, tokens dans lien helper) |
| `app/components/nav_bar_component.html.erb` | Template NavBar | **Rewrite** (tokens B1, retrait bloc breadcrumb) |
| `app/components/bottom_bar_component.rb` | API prev/next/center | **Modify** (défaut `next_variant: :primary`) |
| `app/components/bottom_bar_component.html.erb` | Template BottomBar | **Rewrite** (tokens B1, breakpoint md:hidden, retrait gradient) |
| `spec/components/nav_bar_component_spec.rb` | Specs NavBar | **Rewrite** (rendering + B1 contract guard) |
| `spec/components/bottom_bar_component_spec.rb` | Specs BottomBar | **Rewrite** (rendering + B1 contract guard) |
| `app/views/layouts/teacher.html.erb` | Site d'appel NavBar | _Untouched_ (n'utilise pas `with_breadcrumb`) |

---

## Task Execution Order

1. **Task 1 — Vérification défensive** (grep, sanity check)
2. **Task 2 — NavBar : spec refonte (TDD red)**
3. **Task 3 — NavBar : implémentation (TDD green)**
4. **Task 4 — BottomBar : spec refonte (TDD red)**
5. **Task 5 — BottomBar : implémentation (TDD green)**
6. **Task 6 — Smoke test manuel `/teacher`**
7. **Task 7 — Open PR**

---

### Task 1: Vérification défensive avant refonte

**Files:** Aucune modification. Vérifications grep.

- [ ] **Step 1: Confirmer 0 usage de `with_breadcrumb`**

Run: `grep -rn "with_breadcrumb" app/ spec/`
Expected: aucune sortie (exit 1, "no match").

- [ ] **Step 2: Confirmer le seul site d'appel NavBar**

Run: `grep -rn "NavBarComponent.new" app/ spec/`
Expected: seul résultat = `app/views/layouts/teacher.html.erb:28`.

- [ ] **Step 3: Confirmer 0 site d'appel BottomBar dans app/**

Run: `grep -rn "BottomBarComponent" app/`
Expected: seul résultat = `app/components/bottom_bar_component.rb` (définition + commentaire).

- [ ] **Step 4: Confirmer 0 caller du variant `:gradient`**

Run: `grep -rn "next_variant: *:gradient\|next_variant: :gradient" app/views/ spec/`
Expected: aucune sortie.

- [ ] **Step 5: Stop conditionnel**

Si l'un des grep retourne un résultat inattendu (cf. spec section "Vérification rétrocompat & sites d'appel" → "Stops"), STOPPER et présenter le cas à l'utilisateur avant de poursuivre.

Sinon, continuer à Task 2.

Pas de commit pour Task 1 (lecture seule).

---

### Task 2: NavBar — réécriture spec (TDD red)

**Files:**
- Rewrite: `spec/components/nav_bar_component_spec.rb`

- [ ] **Step 1: Réécrire le spec complet**

Remplacer intégralement le contenu de `spec/components/nav_bar_component_spec.rb` par :

```ruby
require "rails_helper"

RSpec.describe NavBarComponent, type: :component do
  describe "rendering" do
    it "renders brand slot inside accent-primary container" do
      render_inline(described_class.new) do |nav|
        nav.with_brand { "DekatjeBakLa" }
      end
      expect(page).to have_css("nav .text-accent-primary", text: "DekatjeBakLa")
    end

    it "renders links via with_link helper" do
      render_inline(described_class.new) do |nav|
        nav.with_link(href: "/a", label: "Lien A")
        nav.with_link(href: "/b", label: "Lien B")
      end
      expect(page).to have_link("Lien A", href: "/a")
      expect(page).to have_link("Lien B", href: "/b")
    end

    it "renders actions slot in desktop and mobile dropdown" do
      render_inline(described_class.new) do |nav|
        nav.with_actions { '<button>Profil</button>'.html_safe }
      end
      expect(page).to have_css("button", text: "Profil", count: 2)
    end

    it "renders mobile burger button with nav-menu controller" do
      render_inline(described_class.new)
      expect(page).to have_css("nav[data-controller='nav-menu']")
      expect(page).to have_css("button[data-action='click->nav-menu#toggle']")
    end

    it "does NOT respond to with_breadcrumb (slot removed)" do
      component = described_class.new
      expect(component).not_to respond_to(:with_breadcrumb)
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new) do |nav|
        nav.with_brand { "Brand" }
        nav.with_link(href: "/x", label: "X")
        nav.with_actions { "actions" }
      end.to_html
    end

    it "uses bg-surface and border-rule" do
      expect(rendered).to include("bg-surface")
      expect(rendered).to include("border-rule")
    end

    it "uses accent-primary for brand color" do
      expect(rendered).to include("text-accent-primary")
    end

    it "uses on-surface-muted for muted text" do
      expect(rendered).to include("text-on-surface-muted")
    end

    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].freeze

    UNDEFINED_TOKENS.each do |token|
      it "does NOT use undefined token `#{token}`" do
        expect(rendered).not_to include(token)
      end
    end

    it "does NOT contain indigo/violet legacy gradient" do
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("to-violet-500")
    end

    it "does NOT contain slate-* dark mode pairs (replaced by tokens)" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
    end
  end
end
```

- [ ] **Step 2: Lancer le spec, vérifier qu'il échoue (red)**

Run: `bundle exec rspec spec/components/nav_bar_component_spec.rb`
Expected: plusieurs FAILURES (rendering avec tokens B1 absents, brand encore en dégradé indigo, etc.). Si tout passe, STOP — c'est un signal que le rendu actuel a déjà les tokens, donc spec mal écrit.

- [ ] **Step 3: Commit**

```bash
git add spec/components/nav_bar_component_spec.rb
git commit -m "test(b3a): NavBar spec refonte tokens B1 + retrait breadcrumb (red)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: NavBar — implémentation (TDD green)

**Files:**
- Modify: `app/components/nav_bar_component.rb`
- Rewrite: `app/components/nav_bar_component.html.erb`

- [ ] **Step 1: Modifier `nav_bar_component.rb` — retirer slot breadcrumb + tokenizer le helper de lien**

Remplacer intégralement le contenu par :

```ruby
class NavBarComponent < ViewComponent::Base
  renders_one :brand
  renders_many :links, ->(href:, label:) {
    content_tag(:a, label, href: href,
      class: "text-sm text-on-surface-muted hover:text-on-surface transition-colors")
  }
  renders_one :actions
end
```

- [ ] **Step 2: Réécrire `nav_bar_component.html.erb` avec tokens B1**

Remplacer intégralement le contenu par :

```erb
<nav class="flex items-center justify-between px-4 py-3 bg-surface border-b border-rule backdrop-blur-sm"
     data-controller="nav-menu">
  <%# Left: brand %>
  <div class="flex items-center gap-3 min-w-0">
    <% if brand? %>
      <div class="text-base font-bold text-accent-primary whitespace-nowrap">
        <%= brand %>
      </div>
    <% end %>
  </div>

  <%# Desktop: links + actions visible %>
  <div class="hidden md:flex items-center gap-6">
    <% if links? %>
      <div class="flex items-center gap-4">
        <% links.each do |link| %>
          <%= link %>
        <% end %>
      </div>
    <% end %>
    <% if actions? %>
      <div class="flex items-center gap-3">
        <%= actions %>
      </div>
    <% end %>
  </div>

  <%# Mobile: burger button %>
  <button data-action="click->nav-menu#toggle" data-nav-menu-target="button"
          class="md:hidden p-2 rounded-lg text-on-surface-muted hover:bg-surface-raised cursor-pointer"
          aria-label="Menu">
    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/>
    </svg>
  </button>

  <%# Mobile dropdown %>
  <div data-nav-menu-target="menu"
       class="hidden md:hidden absolute top-[57px] left-0 right-0 bg-surface border-b border-rule shadow-lg z-40 px-4 py-3">
    <div class="flex flex-col gap-3">
      <% if links? %>
        <% links.each do |link| %>
          <%= link %>
        <% end %>
      <% end %>
      <% if actions? %>
        <div class="flex flex-wrap items-center gap-3 pt-2 border-t border-rule">
          <%= actions %>
        </div>
      <% end %>
    </div>
  </div>
</nav>
```

- [ ] **Step 3: Lancer le spec, vérifier qu'il passe (green)**

Run: `bundle exec rspec spec/components/nav_bar_component_spec.rb`
Expected: tout PASS (0 failures).

- [ ] **Step 4: Vérifier qu'aucun autre spec ne casse**

Run: `bundle exec rspec spec/components/ --tag ~slow`
Expected: tout PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/nav_bar_component.rb app/components/nav_bar_component.html.erb
git commit -m "feat(b3a): NavBar refonte tokens B1 + retrait slot breadcrumb (green)

- Slot breadcrumb retiré (0 usage confirmé par grep)
- Brand passe de gradient indigo→violet à text-accent-primary (couleur unie)
- Tokens : bg-surface, border-rule, text-on-surface-muted, hover:bg-surface-raised
- Stimulus nav-menu controller conservé

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: BottomBar — réécriture spec (TDD red)

**Files:**
- Rewrite: `spec/components/bottom_bar_component_spec.rb`

- [ ] **Step 1: Réécrire le spec complet**

Remplacer intégralement le contenu de `spec/components/bottom_bar_component_spec.rb` par :

```ruby
require "rails_helper"

RSpec.describe BottomBarComponent, type: :component do
  describe "rendering" do
    it "renders prev link when prev_href is provided" do
      render_inline(described_class.new(prev_href: "/prev", prev_label: "Q1.1"))
      expect(page).to have_link(text: /Q1\.1/, href: "/prev")
    end

    it "renders next link with default :primary variant" do
      render_inline(described_class.new(next_href: "/next", next_label: "Q1.3"))
      expect(page).to have_css("a.text-accent-primary", text: /Q1\.3/)
    end

    it "renders next link with :success variant in success color" do
      render_inline(described_class.new(next_href: "/done", next_label: "Terminer", next_variant: :success))
      expect(page).to have_css("a.text-success", text: /Terminer/)
    end

    it "renders center slot when provided" do
      render_inline(described_class.new) do |bar|
        bar.with_center { '<button>Tutorat</button>'.html_safe }
      end
      expect(page).to have_css("button", text: "Tutorat")
    end

    it "renders default labels when no label given" do
      render_inline(described_class.new(prev_href: "/p", next_href: "/n"))
      expect(page).to have_link(text: /Précédent/)
      expect(page).to have_link(text: /Suivant/)
    end

    it "uses md:hidden breakpoint (not lg:hidden)" do
      render_inline(described_class.new)
      expect(page).to have_css("div.md\\:hidden")
      expect(page).not_to have_css("div.lg\\:hidden")
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new(prev_href: "/p", prev_label: "Prev", next_href: "/n", next_label: "Next"))
        .to_html
    end

    it "uses bg-surface and border-rule" do
      expect(rendered).to include("bg-surface")
      expect(rendered).to include("border-rule")
    end

    it "uses on-surface-muted and accent-primary for prev link" do
      expect(rendered).to include("text-on-surface-muted")
      expect(rendered).to include("hover:text-accent-primary")
    end

    UNDEFINED_TOKENS = %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].freeze

    UNDEFINED_TOKENS.each do |token|
      it "does NOT use undefined token `#{token}`" do
        expect(rendered).not_to include(token)
      end
    end

    it "does NOT contain legacy indigo/violet/emerald colors" do
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("to-violet-500")
      expect(rendered).not_to include("indigo-600")
      expect(rendered).not_to include("emerald-600")
      expect(rendered).not_to include("emerald-400")
    end

    it "does NOT contain slate-* legacy classes" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
    end
  end

  describe ":gradient variant removed" do
    it "renders :gradient as :primary (no legacy gradient classes)" do
      rendered = render_inline(described_class.new(next_href: "/n", next_label: "X", next_variant: :gradient)).to_html
      expect(rendered).not_to include("from-indigo-500")
      expect(rendered).not_to include("bg-clip-text")
    end
  end
end
```

- [ ] **Step 2: Lancer le spec, vérifier qu'il échoue (red)**

Run: `bundle exec rspec spec/components/bottom_bar_component_spec.rb`
Expected: plusieurs FAILURES (lg:hidden encore présent, tokens B1 absents, gradient indigo encore présent).

- [ ] **Step 3: Commit**

```bash
git add spec/components/bottom_bar_component_spec.rb
git commit -m "test(b3a): BottomBar spec refonte tokens B1 + md:hidden + retrait :gradient (red)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: BottomBar — implémentation (TDD green)

**Files:**
- Modify: `app/components/bottom_bar_component.rb`
- Rewrite: `app/components/bottom_bar_component.html.erb`

- [ ] **Step 1: Modifier `bottom_bar_component.rb` — défaut `:primary`**

Remplacer intégralement le contenu par :

```ruby
class BottomBarComponent < ViewComponent::Base
  # Bottom bar fixed on mobile (md:hidden) with prev/next navigation and an optional center action.
  #
  # Usage:
  #   render(BottomBarComponent.new(prev_href: ..., prev_label: "Q1.1", next_href: ..., next_label: "Q1.3")) do |bar|
  #     bar.with_center { render(ButtonComponent.new(variant: :rad_primary) { "Tutorat" }) }
  #   end
  renders_one :center

  def initialize(prev_href: nil, prev_label: nil, next_href: nil, next_label: nil, next_variant: :primary)
    @prev_href = prev_href
    @prev_label = prev_label
    @next_href = next_href
    @next_label = next_label
    @next_variant = next_variant.to_sym
  end
end
```

- [ ] **Step 2: Réécrire `bottom_bar_component.html.erb` avec tokens B1 et `md:hidden`**

Remplacer intégralement le contenu par :

```erb
<div class="md:hidden fixed bottom-0 left-0 right-0 z-[var(--z-bottom-bar)] bg-surface border-t border-rule backdrop-blur-sm px-4 py-3 flex items-center gap-3">
  <% if @prev_href %>
    <%= link_to @prev_href,
        class: "flex-1 min-w-0 text-left text-sm text-on-surface-muted hover:text-accent-primary truncate no-underline" do %>
      &larr; <%= @prev_label || "Précédent" %>
    <% end %>
  <% else %>
    <span class="flex-1"></span>
  <% end %>

  <% if center? %>
    <div class="flex-shrink-0">
      <%= center %>
    </div>
  <% end %>

  <% if @next_href %>
    <%= link_to @next_href,
        class: "flex-1 min-w-0 text-right text-sm font-semibold truncate no-underline #{@next_variant == :success ? 'text-success' : 'text-accent-primary'}" do %>
      <%= @next_label || "Suivant" %> &rarr;
    <% end %>
  <% else %>
    <span class="flex-1"></span>
  <% end %>
</div>
```

- [ ] **Step 3: Lancer le spec, vérifier qu'il passe (green)**

Run: `bundle exec rspec spec/components/bottom_bar_component_spec.rb`
Expected: tout PASS (0 failures).

- [ ] **Step 4: Vérifier que tous les specs components passent**

Run: `bundle exec rspec spec/components/ --tag ~slow`
Expected: tout PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/bottom_bar_component.rb app/components/bottom_bar_component.html.erb
git commit -m "feat(b3a): BottomBar refonte tokens B1 + md:hidden + retrait variant :gradient (green)

- Tokens : bg-surface, border-rule, text-on-surface-muted, text-accent-primary, text-success
- Breakpoint : lg:hidden → md:hidden (visible <768px)
- Variant :gradient retiré, fallback silencieux sur :primary (défaut)
- API (prev/next/center) conservée

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Smoke test manuel `/teacher`

**Files:** Aucune modification.

- [ ] **Step 1: Lancer Rails server**

Run: `bin/rails server` (en background).
Expected: server démarre sur `http://localhost:3000`.

- [ ] **Step 2: Vérification visuelle NavBar — mode clair**

Ouvrir `http://localhost:3000/teacher/classrooms` (ou autre route teacher) dans Chrome.
Vérifier visuellement :
- ✅ NavBar rendue (pas de page blanche, pas d'erreur ViewComponent)
- ✅ Brand "DekatjeBakLa" en couleur unie `accent-primary` (Radical brand color, pas de dégradé indigo)
- ✅ Liens "Mes classes" / "Mes sujets" visibles desktop (≥768px)
- ✅ Actions "Profil" / "Déconnexion" visibles desktop
- ✅ Fond `bg-surface` (pas `bg-white` pure ni `bg-slate-900`)
- ✅ Border `border-rule` visible en bas de la nav

- [ ] **Step 3: Vérification mobile NavBar**

Resize la fenêtre à <768px (DevTools, mode responsive).
Vérifier :
- ✅ Liens et actions cachés
- ✅ Burger menu visible
- ✅ Click burger ouvre le dropdown
- ✅ Liens visibles dans le dropdown

- [ ] **Step 4: Vérification mode sombre**

Toggle dark mode (ThemeToggleComponent dans les actions).
Vérifier :
- ✅ NavBar bascule sur couleurs dark via tokens
- ✅ Brand `accent-primary` reste lisible
- ✅ Aucune "tâche claire" visible (signe que `bg-white` legacy persiste)

- [ ] **Step 5: Arrêter Rails server**

Kill the background process.

- [ ] **Step 6: Si tout est OK, pas de commit (lecture seule)**

Sinon, identifier le problème, retourner à Task 3 / Task 5 selon le composant.

---

### Task 7: Open PR

**Files:** Aucune modification de code. Branche `066-design-system-b3a-navbar-bottombar`.

- [ ] **Step 1: Vérifier l'état de la branche**

Run: `git log main..HEAD --oneline`
Expected: liste 5 commits (docs spec + 2x test red + 2x feat green).

- [ ] **Step 2: Push de la branche**

Run: `git push -u origin 066-design-system-b3a-navbar-bottombar`
Expected: branche poussée.

- [ ] **Step 3: Créer la PR via gh**

Run:
```bash
gh pr create --title "feat(b3a): refonte tokens NavBar + BottomBar (B1)" --body "$(cat <<'EOF'
## Summary
- Refonte `NavBarComponent` : tokens B1 (`bg-surface`, `border-rule`, `text-accent-primary`), retrait du slot `with_breadcrumb` (0 usage)
- Refonte `BottomBarComponent` : tokens B1, breakpoint `md:hidden` (était `lg:hidden`), retrait variant `:gradient` (fallback silencieux sur `:primary`)
- Specs RSpec rendering + B1 contract guard (UNDEFINED_TOKENS pattern, 8 tokens fantômes verrouillés)

Phase 4/8 du chantier design system Radical unifié.

## Changement visuel
Le brand "DekatjeBakLa" dans la NavBar passe de **dégradé indigo→violet** à **couleur unie `accent-primary`**. Aligné avec les tokens B1 et le reste du système Radical.

## YAGNI cuts
- Pattern "tabs 3 onglets" sur BottomBar (n'existe nulle part)
- Intégration `StripesComponent` dans NavBar (découplage clair)
- Composant `BreadcrumbComponent` dédié (planifié B3d)
- DEPRECATED aliases (1 seul/0 site d'appel, refonte directe possible)
- Adoption sur `student/questions/show` (convergence tokens rad-*/B1 reportée à un B3x dédié)

## Test plan
- [ ] CI verte (RSpec + Capybara)
- [ ] Smoke test manuel `/teacher` mode clair (Task 6)
- [ ] Smoke test manuel `/teacher` mode sombre (Task 6)
- [ ] Smoke test mobile <768px (burger + dropdown) (Task 6)

## Spec & plan
- Spec : `docs/superpowers/specs/2026-06-03-design-system-b3a-navbar-bottombar-design.md`
- Plan : `docs/superpowers/plans/2026-06-03-design-system-b3a-navbar-bottombar.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: URL de la PR retournée.

- [ ] **Step 4: Watch CI**

Run: `gh pr checks --watch` (timeout 600000ms).
Expected: tout vert.

Si flake issue #96 (drawer Tibo cascade Selenium) → pattern admin bypass merge documenté.

---

## Self-Review

### Couverture spec

| Spec section | Couverte par |
|---|---|
| Périmètre & non-périmètre | Tasks 2-5 (refonte) + Task 1 (vérif) |
| API `NavBarComponent` (retrait breadcrumb) | Task 3 step 1 + Task 2 step 1 "does NOT respond to with_breadcrumb" |
| API `BottomBarComponent` (`next_variant: :primary` défaut) | Task 5 step 1 |
| Template NavBar tokens B1 | Task 3 step 2 |
| Template BottomBar tokens B1 + `md:hidden` | Task 5 step 2 |
| Specs RSpec rendering | Tasks 2 et 4 |
| Specs B1 contract guard (UNDEFINED_TOKENS) | Tasks 2 et 4 |
| Vérification rétrocompat (grep défensif) | Task 1 |
| Smoke test visuel `/teacher` | Task 6 |
| SC-1 (NavBar zéro classe legacy) | Task 2 spec B1 contract guard |
| SC-2 (slot breadcrumb retiré) | Task 2 + Task 3 |
| SC-3 (burger Stimulus toujours fonctionnel) | Task 2 + Task 6 step 3 |
| SC-4 (BottomBar zéro classe legacy) | Task 4 spec B1 contract guard |
| SC-5 (md:hidden) | Task 4 "uses md:hidden breakpoint" + Task 5 |
| SC-6 (variants :primary et :success, :gradient retiré) | Task 4 "renders :gradient as :primary" |
| SC-7 (0 site d'appel cassé) | Task 1 + Task 6 |
| SC-8 (8 UNDEFINED_TOKENS) | Tasks 2 et 4 |
| SC-9 (CI verte) | Task 7 step 4 |

Aucun gap identifié.

### Placeholder scan

Aucun "TBD", "TODO", "implement later", "add validation", "similar to Task N", "fill in details".

### Type consistency

- `NavBarComponent` slots : `brand`, `links`, `actions` (cohérent Tasks 2, 3, 6).
- `BottomBarComponent` kwargs : `prev_href`, `prev_label`, `next_href`, `next_label`, `next_variant` (cohérent Tasks 4, 5).
- `next_variant` valeurs : `:primary` (défaut), `:success`, `:gradient` (fallback silencieux) (cohérent Tasks 4, 5).
- UNDEFINED_TOKENS liste : identique Tasks 2 et 4 (8 tokens).

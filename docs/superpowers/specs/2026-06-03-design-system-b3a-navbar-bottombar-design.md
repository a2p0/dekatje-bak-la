# B3a — Refonte tokens NavBar + BottomBar

**Phase** : 4/8 du chantier design system Radical unifié.
**Précédents** : B0 (tokens 2 couches), B1 (semantic tokens), B2a (atomes Button/Badge/Card), B2b (Field+Stripes).
**Suivants** : B3b (Modal+Flash), B3c (ProgressBar+EmptyState), B3d (Breadcrumb+ThemeToggle).

## Objectif

Aligner `NavBarComponent` et `BottomBarComponent` sur les **tokens sémantiques B1** (`surface`, `on-surface`, `accent-primary`…), en supprimant les classes Tailwind legacy (`slate-*`, `indigo-*`, `violet-*`, `emerald-*`).

Suppression d'un slot mort (`with_breadcrumb`) et d'un variant mort (`:gradient`) au passage — YAGNI.

## Périmètre

### Dans B3a

- Refonte `NavBarComponent` (tokens + retrait slot `breadcrumb`)
- Refonte `BottomBarComponent` (tokens + breakpoint `md:hidden` + retrait variant `:gradient`)
- Specs RSpec : rendering + **B1 contract guard** (token contract)

### Hors B3a (YAGNI explicite)

| Coupé | Raison |
|---|---|
| Pattern "tabs 3 onglets" sur BottomBar | N'existe nulle part dans le code. Si besoin émerge, B3x dédié. |
| Intégration `StripesComponent` dans NavBar | Découplage clair. Stripes peut être appelé séparément dans un layout. |
| Composant `BreadcrumbComponent` dédié | Planifié B3d. |
| Refonte du controller Stimulus `nav-menu` | Marche, pas besoin de réécrire. |
| DEPRECATED aliases pixel-perfect | 1 seul site d'appel NavBar, 0 site BottomBar → refonte directe possible. |
| Adoption BottomBar sur `student/questions/show` | L'ad-hoc Tibo utilise les tokens `rad-*` chauds (système distinct de B1). Convergence reportée à un B3x dédié. |

## API publique des composants (après refonte)

### `NavBarComponent`

```ruby
class NavBarComponent < ViewComponent::Base
  renders_one :brand
  renders_many :links, ->(href:, label:) {
    content_tag(:a, label, href: href,
      class: "text-sm text-on-surface-muted hover:text-on-surface transition-colors")
  }
  renders_one :actions
  # PAS de renders_one :breadcrumb (retiré)
end
```

**Diff vs actuel** :
- ❌ Retrait `renders_one :breadcrumb`
- ✏️ Slot `links` : classes Tailwind `text-slate-*` → tokens B1
- API constructeur inchangée (aucun argument)

### `BottomBarComponent`

```ruby
class BottomBarComponent < ViewComponent::Base
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

**Diff vs actuel** :
- ✏️ Défaut `next_variant: :gradient` → `next_variant: :primary`
- Variantes finales : `:primary` (par défaut), `:success`
- `:gradient` retiré (fallback silencieux sur `:primary` via ternaire `next_variant == :success ? ... : primary-classes`)

## Templates (tokens B1)

### `nav_bar_component.html.erb` (refonte)

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

**Mapping des tokens NavBar** :

| Avant | Après |
|---|---|
| `bg-white dark:bg-slate-900/95` | `bg-surface` |
| `border-slate-200 dark:border-indigo-500/15` | `border-rule` |
| `bg-gradient-to-br from-indigo-500 to-violet-500 bg-clip-text text-transparent` (brand) | `text-accent-primary` |
| `text-slate-400 dark:text-slate-600` (séparateur breadcrumb) | _supprimé_ |
| `text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700` (burger) | `text-on-surface-muted hover:bg-surface-raised` |
| `bg-white dark:bg-slate-800` (dropdown) | `bg-surface` |
| `border-slate-200 dark:border-slate-700` (séparateur dropdown) | `border-rule` |

**Changement visuel volontaire** : le brand passe de **dégradé indigo→violet** à **couleur unie `accent-primary`** (Radical brand color).

### `bottom_bar_component.html.erb` (refonte)

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

**Mapping des tokens BottomBar** :

| Avant | Après |
|---|---|
| `lg:hidden` | `md:hidden` |
| `bg-white/95 dark:bg-slate-900/95` | `bg-surface` |
| `border-slate-200 dark:border-indigo-500/15` | `border-rule` |
| `text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400` (prev) | `text-on-surface-muted hover:text-accent-primary` |
| `bg-gradient-to-br from-indigo-500 to-violet-500 bg-clip-text text-transparent` (next gradient) | `text-accent-primary` |
| `text-emerald-600 dark:text-emerald-400` (next success) | `text-success` |
| Variante `:gradient` | Supprimée — devient `:primary` (défaut) |

**Z-index** : `z-[var(--z-bottom-bar)]` conservé tel quel (variable CSS définie dans `application.css`, hors scope tokens B1).

## Specs RSpec

### `spec/components/nav_bar_component_spec.rb`

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

### `spec/components/bottom_bar_component_spec.rb`

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

## Vérification rétrocompat & sites d'appel

### NavBar — site d'appel à vérifier

**1 seul site** : `app/views/layouts/teacher.html.erb:28-39`.

N'utilise pas `with_breadcrumb` → retrait sans risque. N'utilise pas d'argument constructeur → aucune migration.

### BottomBar — sites d'appel

**0 site d'appel actuel** (composant orphelin). Aucune migration nécessaire.

### Plan de vérification (en début d'implémentation)

```bash
grep -rn "with_breadcrumb" app/ spec/                  # doit retourner 0 résultat
grep -rn "NavBarComponent.new" app/ spec/              # doit lister uniquement layouts/teacher.html.erb
grep -rn "BottomBarComponent.new" app/ spec/           # doit retourner 0 résultat (app/)
grep -rn "next_variant: *:gradient" app/ spec/         # doit retourner 0 résultat
```

**Stops** :
- `with_breadcrumb` trouvé ailleurs → présenter le cas avant de retirer le slot
- NavBar appelé dans un autre layout → l'inclure dans la vérif visuelle finale
- BottomBar appelé quelque part → revoir le scope
- `:gradient` utilisé → revoir le retrait

### Vérification visuelle finale (avant PR)

- Smoke test manuel `/teacher` (mode clair + sombre) : NavBar rendue, brand color = `accent-primary`, burger mobile fonctionne
- Pas de BottomBar à smoke-tester (0 site d'appel)

## Critères de succès (SC)

| ID | Critère | Vérification |
|---|---|---|
| SC-1 | NavBar refondue : zéro classe Tailwind legacy (`slate-*`, `indigo-*`, `violet-*`) | Spec B1 contract guard |
| SC-2 | NavBar : slot `with_breadcrumb` retiré, slots `brand`/`links`/`actions` conservés | Spec dédiée |
| SC-3 | NavBar : burger mobile Stimulus `nav-menu` toujours fonctionnel | Spec présence controller/action |
| SC-4 | BottomBar refondue : zéro classe Tailwind legacy (`slate-*`, `indigo-*`, `violet-*`, `emerald-*`) | Spec B1 contract guard |
| SC-5 | BottomBar : breakpoint `md:hidden` (était `lg:hidden`) | Spec dédiée |
| SC-6 | BottomBar : variants `:primary` (défaut) et `:success` ; `:gradient` retiré (fallback `:primary`) | Spec dédiée |
| SC-7 | Aucun site d'appel cassé : `layouts/teacher.html.erb` rend sans erreur, 0 usage de `with_breadcrumb` | grep + smoke test manuel `/teacher` |
| SC-8 | B1 contract guard : 8 undefined tokens absents du HTML des 2 composants | Spec UNDEFINED_TOKENS |
| SC-9 | CI verte sur la PR | gh run watch |

### Hors SC (explicitement)

- Pas de SC visuel pixel-perfect : refonte change volontairement l'apparence (brand passe de dégradé à `accent-primary`).
- Pas de SC sur adoption `student/questions/show` (retiré du scope).
- Pas de SC sur intégration Stripes (hors scope).

## Notes architecture

### Convergence tokens B1 ↔ Radical chauds — reportée

Le système Radical définit aujourd'hui 2 espaces de couleurs :

- **(a) tokens B1 sémantiques** (`surface`, `on-surface`, `accent-primary`, `rule`…) utilisés par les écrans teacher/admin et tout composant générique (Button, Badge, Card, Field, Stripes, NavBar, BottomBar).
- **(b) tokens Radical chauds** (`rad-bg`, `rad-cream`, `rad-red`, `rad-ink`, `rad-paper`, `rad-raise`, `rad-rule`, `rad-text`, `rad-muted`…) utilisés par les écrans Tibo / élève reskiné (features 054-057).

La convergence éventuelle (un seul système, ou couplage explicite via aliases) est un chantier B3x distinct.

### Issue #109 — DEPRECATED tracking

**Pas d'entrée à ajouter pour B3a** : aucun alias DEPRECATED introduit (refonte directe possible grâce au 1-seul-site / 0-site).

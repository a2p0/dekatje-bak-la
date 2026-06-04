# B3b — Refonte tokens Modal + Flash

**Phase** : 5/8 du chantier design system Radical unifié.
**Précédents** : B0+B1 (#102), B2a Button/Badge/Card (#110), B2b Field+Stripes (#111), B3a NavBar+BottomBar (#118).
**Suivants** : B3c (ProgressBar+EmptyState), B3d (Breadcrumb+ThemeToggle).

## Objectif

Aligner `ModalComponent` et `FlashComponent` sur les **tokens sémantiques B1**, en supprimant les classes Tailwind legacy (`slate-*`, `indigo-*`, `emerald-*`, `rose-*` et `dark:` pairs devenus inutiles).

API publique des 2 composants inchangée. Stimulus controllers (modal/focus-trap/dismissable) inchangés.

## Périmètre

### Dans B3b

- Refonte tokens `ModalComponent` (template uniquement, `.rb` inchangé)
- Refonte tokens `FlashComponent` (constante `TYPES` dans le `.rb`, c'est un composant `.call`-style)
- Specs RSpec : rendering + B1 contract guard inline (8 UNDEFINED_TOKENS + regex bans)

### Hors B3b (YAGNI explicite)

| Coupé | Raison |
|---|---|
| Slot `:footer` sur Modal | 0 site d'appel actuel, spéculation |
| Types Flash `:warning` / `:info` | Aucun usage actuel ne le demande |
| Token `bg-overlay` pour backdrop | 1 seul usage, surdimensionné |
| API Flash via Turbo Streams | Pas dans le code aujourd'hui, évolution séparée |
| DEPRECATED aliases | 0 site Modal, 6 sites Flash sans classes injectées |
| Refonte controllers Stimulus | Marchent, YAGNI |
| Renommage `notice`/`alert` → `success`/`danger` dans l'API | Casse 6 sites + sémantique Rails `flash[:notice]` standard |
| Refonte page démo `design_system/preview.html.erb` | Hors scope tokens, juste vérifier qu'elle rend |

## API publique des composants (après refonte)

### `ModalComponent` — inchangée

```ruby
class ModalComponent < ViewComponent::Base
  renders_one :body

  def initialize(title:, title_id: nil)
    @title = title
    @title_id = title_id || "modal-title-#{SecureRandom.hex(4)}"
  end
end
```

Aucune modification du `.rb`. Seul le template change.

### `FlashComponent` — structurellement inchangée, constante `TYPES` refondue

```ruby
class FlashComponent < ViewComponent::Base
  TYPES = {
    notice: "bg-success/10 text-success border-success/20",
    alert:  "bg-danger/10 text-danger border-danger/20"
  }.freeze

  def initialize(type:, message:)
    @type = type.to_sym
    @message = message
  end

  def render?
    @message.present?
  end

  def call
    content_tag(:div, class: "flex items-center justify-between px-4 py-3 rounded-lg border text-sm #{TYPES[@type]}", data: { controller: "dismissable" }) do
      content_tag(:span, @message) +
      content_tag(:button, "×",
        class: "ml-3 text-current opacity-50 hover:opacity-100 cursor-pointer",
        data: { action: "click->dismissable#dismiss" },
        aria: { label: "Fermer" })
    end
  end
end
```

**Diff vs actuel** :
- Mapping `TYPES[:notice]` : `bg-emerald-50 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-500/20` → `bg-success/10 text-success border-success/20`
- Mapping `TYPES[:alert]` : `bg-rose-50 dark:bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-500/20` → `bg-danger/10 text-danger border-danger/20`
- API publique (`type:`, `message:`, `render?`, `.call`) inchangée
- 6 sites d'appel continuent à fonctionner sans modification

## Templates (tokens B1)

### `modal_component.html.erb` (refonte)

```erb
<div role="dialog"
     aria-modal="true"
     aria-labelledby="<%= @title_id %>"
     data-controller="modal focus-trap"
     data-action="focus-trap:close->modal#close"
     class="fixed inset-0 z-[var(--z-modal)] flex items-center justify-center"
     tabindex="-1">
  <div class="absolute inset-0 bg-black/50" data-action="click->modal#close"></div>
  <div class="relative bg-surface-raised border border-rule rounded-2xl shadow-xl max-w-md w-full mx-4 p-6">
    <div class="flex items-start justify-between mb-4">
      <h3 id="<%= @title_id %>" class="text-lg font-semibold text-on-surface"><%= @title %></h3>
      <button type="button"
              data-action="click->modal#close"
              aria-label="Fermer"
              class="text-on-surface-muted hover:text-on-surface bg-transparent border-0 cursor-pointer text-xl leading-none p-1">
        &times;
      </button>
    </div>
    <% if body? %>
      <%= body %>
    <% end %>
  </div>
</div>
```

**Mapping des tokens Modal** :

| Avant | Après |
|---|---|
| `bg-white dark:bg-slate-800/95` (panel) | `bg-surface-raised` |
| `border-slate-200 dark:border-indigo-500/15` (panel) | `border-rule` |
| `dark:shadow-[0_0_30px_rgba(99,102,241,0.15)]` (glow indigo dark mode) | _supprimé_ — `shadow-xl` suffit |
| `text-slate-800 dark:text-slate-100` (titre) | `text-on-surface` |
| `text-slate-400 hover:text-slate-700 dark:hover:text-slate-200` (X close) | `text-on-surface-muted hover:text-on-surface` |
| `bg-black/50` (backdrop) | _conservé_ (hardcoded volontairement, neutre thèmes) |

**Z-index** : `z-[var(--z-modal)]` conservé tel quel (variable CSS définie dans `application.css`, hors scope tokens B1).

**Changement visuel volontaire** : le glow indigo dark mode disparaît (aligné suppression brand gradient en B3a).

### `FlashComponent` (`.call` style — pas de template ERB)

Refonte dans la constante `TYPES` du `.rb` (section API ci-dessus).

**Mapping résultant des classes appliquées** :

| Avant (notice) | Après (notice) |
|---|---|
| `bg-emerald-50` | `bg-success/10` |
| `dark:bg-emerald-500/10` | _supprimé_ (token `success` a déjà sa variante dark) |
| `text-emerald-700` | `text-success` |
| `dark:text-emerald-300` | _supprimé_ |
| `border-emerald-200` | `border-success/20` |
| `dark:border-emerald-500/20` | _supprimé_ |

| Avant (alert) | Après (alert) |
|---|---|
| `bg-rose-50` | `bg-danger/10` |
| `dark:bg-rose-500/10` | _supprimé_ |
| `text-rose-700` | `text-danger` |
| `dark:text-rose-300` | _supprimé_ |
| `border-rose-200` | `border-danger/20` |
| `dark:border-rose-500/20` | _supprimé_ |

**Pourquoi pas de `dark:` pair** : les tokens B1 sémantiques (`--color-success`, `--color-danger`) sont déjà conscients du thème via `application.css` (override dans le bloc `:where([data-audience])`). Plus besoin de `dark:` pairs explicites.

## Specs RSpec

### `spec/components/modal_component_spec.rb`

```ruby
require "rails_helper"

RSpec.describe ModalComponent, type: :component do
  describe "rendering" do
    it "renders dialog with title and aria attributes" do
      render_inline(described_class.new(title: "Confirmer")) do |modal|
        modal.with_body { "Êtes-vous sûr ?" }
      end
      expect(page).to have_css("[role='dialog'][aria-modal='true']")
      expect(page).to have_css("h3", text: "Confirmer")
      expect(page).to have_text("Êtes-vous sûr ?")
    end

    it "uses provided title_id" do
      render_inline(described_class.new(title: "T", title_id: "my-modal"))
      expect(page).to have_css("[aria-labelledby='my-modal']")
      expect(page).to have_css("h3#my-modal")
    end

    it "generates a unique title_id when none given" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("h3[id^='modal-title-']")
    end

    it "renders close button with aria-label" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("button[aria-label='Fermer']")
    end

    it "wires Stimulus modal + focus-trap controllers" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("[data-controller='modal focus-trap']")
      expect(page).to have_css("[data-action='focus-trap:close->modal#close']")
    end

    it "renders backdrop with click-to-close action" do
      render_inline(described_class.new(title: "T"))
      expect(page).to have_css("div.bg-black\\/50[data-action='click->modal#close']")
    end
  end

  describe "B1 token contract" do
    let(:rendered) do
      render_inline(described_class.new(title: "T")) do |modal|
        modal.with_body { "body" }
      end.to_html
    end

    it "uses bg-surface-raised and border-rule on the panel" do
      expect(rendered).to include("bg-surface-raised")
      expect(rendered).to include("border-rule")
    end

    it "uses text-on-surface for title and text-on-surface-muted for close button" do
      expect(rendered).to include("text-on-surface")
      expect(rendered).to include("text-on-surface-muted")
    end

    it "keeps bg-black/50 hardcoded for backdrop (theme-neutral)" do
      expect(rendered).to include("bg-black/50")
    end

    %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].each do |token|
      it "does NOT use undefined token `#{token}`" do
        expect(rendered).not_to include(token)
      end
    end

    it "does NOT contain legacy slate-* / indigo-* dark mode pairs" do
      expect(rendered).not_to match(/bg-slate-\d{3}/)
      expect(rendered).not_to match(/text-slate-\d{3}/)
      expect(rendered).not_to match(/border-slate-\d{3}/)
      expect(rendered).not_to include("border-indigo-500/15")
      expect(rendered).not_to include("rgba(99,102,241")
    end
  end
end
```

### `spec/components/flash_component_spec.rb`

```ruby
require "rails_helper"

RSpec.describe FlashComponent, type: :component do
  describe "rendering" do
    it "renders a notice flash in success colors" do
      render_inline(described_class.new(type: :notice, message: "Sauvegardé"))
      expect(page).to have_text("Sauvegardé")
      expect(page).to have_css("div.text-success")
      expect(page).to have_css("div.bg-success\\/10")
    end

    it "renders an alert flash in danger colors" do
      render_inline(described_class.new(type: :alert, message: "Erreur"))
      expect(page).to have_text("Erreur")
      expect(page).to have_css("div.text-danger")
      expect(page).to have_css("div.bg-danger\\/10")
    end

    it "renders nothing when message is blank" do
      render_inline(described_class.new(type: :notice, message: nil))
      expect(page.text).to be_empty
    end

    it "renders nothing when message is empty string" do
      render_inline(described_class.new(type: :alert, message: ""))
      expect(page.text).to be_empty
    end

    it "renders a dismiss button wired to dismissable controller" do
      render_inline(described_class.new(type: :notice, message: "msg"))
      expect(page).to have_css("[data-controller='dismissable']")
      expect(page).to have_css("button[aria-label='Fermer'][data-action='click->dismissable#dismiss']")
    end
  end

  describe "B1 token contract" do
    let(:rendered_notice) { render_inline(described_class.new(type: :notice, message: "X")).to_html }
    let(:rendered_alert)  { render_inline(described_class.new(type: :alert,  message: "X")).to_html }

    it "notice uses success tokens (not emerald)" do
      expect(rendered_notice).to include("bg-success/10")
      expect(rendered_notice).to include("text-success")
      expect(rendered_notice).to include("border-success/20")
    end

    it "alert uses danger tokens (not rose)" do
      expect(rendered_alert).to include("bg-danger/10")
      expect(rendered_alert).to include("text-danger")
      expect(rendered_alert).to include("border-danger/20")
    end

    %w[
      accent-warning accent-success accent-danger on-accent
      surface-elevated surface-inverse on-inverse
      text-text-primary text-text-muted
    ].each do |token|
      it "does NOT use undefined token `#{token}` (notice)" do
        expect(rendered_notice).not_to include(token)
      end
    end

    it "does NOT contain legacy emerald-* / rose-* / slate-* classes" do
      [rendered_notice, rendered_alert].each do |html|
        expect(html).not_to match(/emerald-\d{3}/)
        expect(html).not_to match(/rose-\d{3}/)
        expect(html).not_to match(/bg-slate-\d{3}/)
        expect(html).not_to match(/text-slate-\d{3}/)
        expect(html).not_to match(/border-slate-\d{3}/)
      end
    end

    it "does NOT contain dark: mode pairs (tokens already theme-aware)" do
      [rendered_notice, rendered_alert].each do |html|
        expect(html).not_to match(/dark:bg-/)
        expect(html).not_to match(/dark:text-/)
        expect(html).not_to match(/dark:border-/)
      end
    end
  end
end
```

## Vérification rétrocompat & sites d'appel

### Modal — sites d'appel

**0 dans `app/`**. Orphelin (similaire à BottomBar en B3a). Refonte directe possible.

### Flash — sites d'appel

**6 sites** :
1. `app/views/layouts/application.html.erb:41` — `notice`
2. `app/views/layouts/application.html.erb:46` — `alert`
3. `app/views/layouts/student.html.erb:40` — `notice`
4. `app/views/layouts/student.html.erb:45` — `alert`
5. `app/views/shared/_flash.html.erb:4` — `notice` (utilisé par `layouts/teacher.html.erb:42`)
6. `app/views/shared/_flash.html.erb:9` — `alert`

Tous n'utilisent que `type:` et `message:` — aucun n'injecte de classes Tailwind externes. **0 site cassé** par la refonte.

### Plan de vérification (en début d'implémentation)

```bash
grep -rn "ModalComponent.new\|render(ModalComponent" app/         # 0 caller production
grep -rn "FlashComponent.new" app/views/                          # 6 callers, tous type:+message:
grep -rn "FlashComponent.new" app/views/ | grep -vE "type:.*message:|message:.*type:"  # 0 résultat
```

**Stops** :
- Modal trouvé ailleurs dans `app/views/` → présenter le cas (refonte directe risquée si site utilise tokens dépendants)
- Flash site ne respecte pas `type:`+`message:` uniquement → comprendre la dépendance

### Vérification visuelle finale (avant PR)

- **Flash notice** : déclencher login réussi (`/users/sign_in` → flash[:notice])
- **Flash alert** : déclencher login raté (mauvais mot de passe → flash[:alert])
- Vérifier mode clair + sombre : vert (success) / rouge (danger), pas emerald/rose
- **Modal** : pas testable directement (0 site d'appel production). Page démo `design_system/preview.html.erb` éventuellement.

### Issue #109 — DEPRECATED tracking

**Pas d'entrée à ajouter pour B3b** : aucun alias DEPRECATED introduit.

## Critères de succès (SC)

| ID | Critère | Vérification |
|---|---|---|
| SC-1 | Modal panel utilise tokens B1 (`bg-surface-raised`, `border-rule`, `text-on-surface`, `text-on-surface-muted`) | Spec B1 contract guard |
| SC-2 | Modal backdrop `bg-black/50` conservé (theme-neutral) | Spec dédiée |
| SC-3 | Modal : Stimulus controllers + ARIA + data-actions intacts | Spec présence controllers + actions |
| SC-4 | Flash `:notice` → tokens `success` family ; `:alert` → tokens `danger` family | Spec dédiée |
| SC-5 | Flash : `render?` retourne false sur message blank ou nil ; API publique inchangée | Spec dédiée |
| SC-6 | B1 contract guard : 8 undefined tokens absents des 2 composants | Spec UNDEFINED_TOKENS inline |
| SC-7 | 0 classe legacy `slate-*`, `indigo-*`, `emerald-*`, `rose-*`, glow rgba | Spec regex bans |
| SC-8 | 0 `dark:` pair sur Flash (tokens déjà theme-aware) | Spec dédiée |
| SC-9 | 6 sites d'appel Flash continuent de rendre sans erreur | Smoke test manuel |
| SC-10 | CI verte sur la PR | gh run watch |

### Hors SC (explicitement)

- Pas de SC visuel pixel-perfect : changement volontaire (couleurs success/danger remplacent emerald/rose, glow indigo dark mode Modal disparaît).
- Pas de SC sur Modal en smoke test si page démo n'instancie pas un Modal.
- Pas de SC sur convergence rad-* (système chaud Tibo non concerné par overlays génériques).

## Notes architecture

### Pattern `.call`-style vs ERB

`FlashComponent` est un composant `.call` (rendu inline en Ruby), `ModalComponent` est un composant ERB. Les 2 sont des conventions ViewComponent légitimes :
- `.call` quand le rendu est court et statique
- ERB quand il y a structure HTML, slots, conditionnels

Aucun changement de style dans B3b.

### Convergence tokens B1 ↔ Radical chauds — toujours reportée

Comme en B3a, les écrans Tibo (drawer chat) utilisent les tokens `rad-*` chauds. Les overlays Modal/Flash B3b sont neutres (système B1) — pas de couplage forcé. Convergence éventuelle = chantier B3x distinct.

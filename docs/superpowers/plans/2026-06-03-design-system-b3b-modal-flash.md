# B3b — Refonte tokens Modal + Flash — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aligner `ModalComponent` et `FlashComponent` sur les tokens sémantiques B1 (`surface-raised`, `on-surface`, `success`, `danger`...) en supprimant les classes Tailwind legacy (`slate-*`, `indigo-*`, `emerald-*`, `rose-*`) et les `dark:` pairs devenus inutiles.

**Architecture:** Refonte directe des 2 composants ViewComponent (0 site d'appel pour Modal, 6 sites pour Flash mais aucun n'injecte de classes — refonte sans DEPRECATED aliases). Modal = template ERB refactoré. Flash = constante `TYPES` du `.rb` refondue. Tests RSpec rendering + B1 contract guard inline (8 UNDEFINED_TOKENS).

**Tech Stack:** Rails 8.1.3 + ViewComponent + Tailwind CSS v4 + RSpec.

**Spec:** `docs/superpowers/specs/2026-06-03-design-system-b3b-modal-flash-design.md`

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `app/components/modal_component.rb` | API (`title:`, `title_id:`, slot `body`) | _Untouched_ |
| `app/components/modal_component.html.erb` | Template Modal | **Rewrite** (tokens B1) |
| `app/components/flash_component.rb` | API + constante `TYPES` + `.call` rendu | **Modify** (constante `TYPES` uniquement) |
| `spec/components/modal_component_spec.rb` | Specs Modal | **Rewrite** (rendering + B1 contract guard) |
| `spec/components/flash_component_spec.rb` | Specs Flash | **Rewrite** (rendering + B1 contract guard) |
| `app/views/layouts/application.html.erb` | 2 callers Flash | _Untouched_ |
| `app/views/layouts/student.html.erb` | 2 callers Flash | _Untouched_ |
| `app/views/shared/_flash.html.erb` | 2 callers Flash | _Untouched_ |
| `app/javascript/controllers/modal_controller.js` | Stimulus close | _Untouched_ |
| `app/javascript/controllers/focus_trap_controller.js` | Stimulus focus-trap | _Untouched_ |
| `app/javascript/controllers/dismissable_controller.js` | Stimulus dismiss | _Untouched_ |

---

## Task Execution Order

1. **Task 1 — Vérification défensive** (grep, sanity check)
2. **Task 2 — Modal : spec refonte (TDD red)**
3. **Task 3 — Modal : implémentation (TDD green)**
4. **Task 4 — Flash : spec refonte (TDD red)**
5. **Task 5 — Flash : implémentation (TDD green)**
6. **Task 6 — Smoke test manuel flash notice/alert**
7. **Task 7 — Open PR + watch CI**

---

### Task 1: Vérification défensive avant refonte

**Files:** Aucune modification. Vérifications grep.

- [ ] **Step 1: Confirmer 0 site d'appel `ModalComponent` dans `app/`**

Run: `grep -rn "ModalComponent.new\|render(ModalComponent" app/`
Expected: aucune sortie (la définition du composant elle-même est dans `app/components/modal_component.rb` mais ce n'est pas un caller).

- [ ] **Step 2: Confirmer sites d'appel `FlashComponent`**

Run: `grep -rn "FlashComponent.new" app/views/`
Expected: 6 résultats — 2 dans `layouts/application.html.erb`, 2 dans `layouts/student.html.erb`, 2 dans `shared/_flash.html.erb`.

- [ ] **Step 3: Confirmer 0 caller Flash avec signature non-standard**

Run: `grep -rn "FlashComponent.new" app/views/ | grep -vE "type: *:notice.*message:|type: *:alert.*message:"`
Expected: aucune sortie. Tous les callers utilisent exactement `type:` (`:notice` ou `:alert`) + `message:`.

- [ ] **Step 4: Stop conditionnel**

Si l'un des grep retourne un résultat inattendu (cf. spec section "Vérification rétrocompat & sites d'appel" → "Stops"), STOPPER et présenter le cas à l'utilisateur avant de poursuivre.

Sinon, continuer à Task 2.

Pas de commit pour Task 1 (lecture seule).

---

### Task 2: Modal — réécriture spec (TDD red)

**Files:**
- Rewrite: `spec/components/modal_component_spec.rb`

- [ ] **Step 1: Réécrire le spec complet**

Remplacer intégralement le contenu de `spec/components/modal_component_spec.rb` par :

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

- [ ] **Step 2: Lancer le spec, vérifier qu'il échoue (red)**

Run: `bundle exec rspec spec/components/modal_component_spec.rb`
Expected: plusieurs FAILURES (rendering attend `bg-surface-raised` / `border-rule` / `text-on-surface*` qui ne sont pas dans le template legacy ; et le rendered HTML contient encore `bg-slate-*`, `border-indigo-500/15`, `rgba(99,102,241`). Si tout passe, STOP — spec mal écrit.

- [ ] **Step 3: Commit**

```bash
git add spec/components/modal_component_spec.rb
git commit -m "test(b3b): Modal spec refonte tokens B1 (red)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Modal — implémentation (TDD green)

**Files:**
- Rewrite: `app/components/modal_component.html.erb`
- _Untouched_: `app/components/modal_component.rb`

- [ ] **Step 1: Réécrire `modal_component.html.erb` avec tokens B1**

Remplacer intégralement le contenu par :

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

- [ ] **Step 2: Lancer le spec Modal, vérifier qu'il passe (green)**

Run: `bundle exec rspec spec/components/modal_component_spec.rb`
Expected: tout PASS (0 failures).

- [ ] **Step 3: Vérifier qu'aucun autre spec ne casse**

Run: `bundle exec rspec spec/components/`
Expected: tout PASS.

- [ ] **Step 4: Commit**

```bash
git add app/components/modal_component.html.erb
git commit -m "feat(b3b): Modal refonte tokens B1 (green)

- Panel : bg-surface-raised, border-rule (était bg-white / dark:bg-slate-800/95)
- Titre : text-on-surface (était text-slate-800 / dark:text-slate-100)
- Close X : text-on-surface-muted hover:text-on-surface (était text-slate-400 / hover:text-slate-700)
- Backdrop : bg-black/50 conservé (theme-neutral)
- Glow indigo dark mode supprimé (shadow-xl suffit)
- API + Stimulus controllers (modal/focus-trap) + ARIA inchangés

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Flash — réécriture spec (TDD red)

**Files:**
- Rewrite: `spec/components/flash_component_spec.rb`

- [ ] **Step 1: Réécrire le spec complet**

Remplacer intégralement le contenu de `spec/components/flash_component_spec.rb` par :

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

- [ ] **Step 2: Lancer le spec, vérifier qu'il échoue (red)**

Run: `bundle exec rspec spec/components/flash_component_spec.rb`
Expected: plusieurs FAILURES (rendering attend `text-success` / `text-danger` / `bg-success/10` / `bg-danger/10` qui ne sont pas dans la constante `TYPES` legacy ; et le HTML contient encore `bg-emerald-50`, `bg-rose-50`, `dark:bg-*`, etc.).

- [ ] **Step 3: Commit**

```bash
git add spec/components/flash_component_spec.rb
git commit -m "test(b3b): Flash spec refonte tokens B1 (red)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Flash — implémentation (TDD green)

**Files:**
- Modify: `app/components/flash_component.rb` (constante `TYPES` uniquement)

- [ ] **Step 1: Modifier la constante `TYPES` dans `flash_component.rb`**

Remplacer intégralement le contenu par :

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

- [ ] **Step 2: Lancer le spec Flash, vérifier qu'il passe (green)**

Run: `bundle exec rspec spec/components/flash_component_spec.rb`
Expected: tout PASS (0 failures).

- [ ] **Step 3: Vérifier que tous les specs components passent**

Run: `bundle exec rspec spec/components/`
Expected: tout PASS.

- [ ] **Step 4: Commit**

```bash
git add app/components/flash_component.rb
git commit -m "feat(b3b): Flash refonte tokens B1 (green)

- notice : bg-success/10 text-success border-success/20 (était emerald-* + dark:)
- alert  : bg-danger/10 text-danger border-danger/20 (était rose-* + dark:)
- dark: pairs supprimés (tokens B1 déjà theme-aware)
- API (type:, message:) + render? + Stimulus dismissable inchangés
- 6 sites d'appel continuent à fonctionner sans modification

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Smoke test manuel flash notice/alert

**Files:** Aucune modification.

- [ ] **Step 1: Vérifier que le serveur Rails tourne**

Run: `curl -sf http://localhost:3000/up && echo "OK"`
Expected: `OK`. Si le serveur n'est pas démarré, lancer `bin/rails server -p 3000` en background.

- [ ] **Step 2: Vérification visuelle flash alert (login raté)**

Ouvrir `http://localhost:3000/users/sign_in` dans Chrome.
Saisir un email/mot de passe invalides, soumettre.
Vérifier visuellement le flash en haut de page :
- ✅ Couleur **rouge danger** (token `text-danger`, fond `bg-danger/10`)
- ✅ Pas de rose legacy (`rose-700`, `bg-rose-50`)
- ✅ Bouton X de fermeture visible, clic le supprime

- [ ] **Step 3: Vérification visuelle flash notice (login réussi ou autre action notice)**

Se connecter avec un compte valide.
Vérifier le flash post-login (s'il y en a un) ou déclencher une action notice (ex: déconnexion, modification profil) :
- ✅ Couleur **verte success** (token `text-success`, fond `bg-success/10`)
- ✅ Pas d'emerald legacy (`emerald-700`, `bg-emerald-50`)

- [ ] **Step 4: Vérification mode sombre**

Toggle dark mode via ThemeToggleComponent dans la NavBar.
Déclencher à nouveau notice et alert.
Vérifier :
- ✅ Couleurs success/danger restent lisibles
- ✅ Pas de pair `dark:bg-emerald-500/10` ou similaire dans le HTML rendu (DevTools Inspector)

- [ ] **Step 5: Si tout OK, pas de commit (lecture seule)**

Sinon, identifier le problème, retourner à Task 5.

---

### Task 7: Open PR

**Files:** Aucune modification de code. Branche `067-design-system-b3b-modal-flash`.

- [ ] **Step 1: Vérifier l'état de la branche**

Run: `git log main..HEAD --oneline`
Expected: liste 5 commits (docs spec + 2x test red + 2x feat green).

- [ ] **Step 2: Push de la branche**

Run: `git push -u origin 067-design-system-b3b-modal-flash`
Expected: branche poussée.

- [ ] **Step 3: Créer la PR via gh**

Run:
```bash
gh pr create --title "feat(b3b): refonte tokens Modal + Flash (B1)" --body "$(cat <<'EOF'
## Summary
- Refonte `ModalComponent` : tokens B1 (`bg-surface-raised`, `border-rule`, `text-on-surface`, `text-on-surface-muted`), backdrop `bg-black/50` conservé
- Refonte `FlashComponent` : constante `TYPES` → tokens sémantiques (`notice` → `success` family, `alert` → `danger` family), `dark:` pairs supprimés (tokens déjà theme-aware)
- Specs RSpec rendering + B1 contract guard inline (8 tokens fantômes verrouillés)
- API publique des 2 composants inchangée, Stimulus controllers inchangés, 6 sites d'appel Flash continuent à fonctionner

Phase 5/8 du chantier design system Radical unifié.

## Changements visuels
- Modal : glow indigo dark mode supprimé (`shadow-xl` suffit)
- Flash notice : passe du vert emerald au vert `success` token (variation tonale)
- Flash alert : passe du rose au rouge `danger` token

## YAGNI cuts
- Slot `:footer` sur Modal (0 site d'appel, spéculation)
- Types Flash `:warning` / `:info` (aucun usage actuel)
- Token `bg-overlay` pour backdrop (1 seul usage, surdimensionné)
- API Flash via Turbo Streams (pas dans le code, évolution séparée)
- DEPRECATED aliases (0 site Modal, 6 sites Flash sans classes injectées)
- Refonte controllers Stimulus (marchent, YAGNI)

## Test plan
- [x] Smoke test manuel flash notice/alert mode clair + sombre (Task 6)
- [ ] CI verte (RSpec + Capybara)

## Spec & plan
- Spec : \`docs/superpowers/specs/2026-06-03-design-system-b3b-modal-flash-design.md\`
- Plan : \`docs/superpowers/plans/2026-06-03-design-system-b3b-modal-flash.md\`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: URL de la PR retournée.

- [ ] **Step 4: Watch CI**

Run: `gh pr checks --watch` (timeout 600000ms).
Expected: tout vert.

Si flake issue #96 (drawer Tibo cascade Selenium) → admin bypass merge documenté (pattern B2a/B2b/B3a).

---

## Self-Review

### Couverture spec

| Spec section | Couverte par |
|---|---|
| Périmètre & non-périmètre | Tasks 2-5 (refonte) + Task 1 (vérif) |
| API `ModalComponent` (inchangée) | Task 3 (template uniquement, `.rb` _Untouched_) + Task 2 spec asserte ARIA + Stimulus + close button |
| API `FlashComponent` (TYPES refondue) | Task 5 step 1 |
| Template Modal tokens B1 | Task 3 step 1 |
| Constante TYPES Flash tokens B1 | Task 5 step 1 |
| Specs RSpec rendering | Tasks 2 et 4 |
| Specs B1 contract guard (UNDEFINED_TOKENS inline) | Tasks 2 et 4 |
| Vérification rétrocompat (grep défensif) | Task 1 |
| Smoke test visuel flash | Task 6 |
| SC-1 (Modal tokens B1) | Task 2 spec B1 contract guard |
| SC-2 (Modal backdrop bg-black/50) | Task 2 spec dédiée |
| SC-3 (Modal Stimulus + ARIA intacts) | Task 2 specs présence controllers + actions |
| SC-4 (Flash notice→success, alert→danger) | Task 4 spec dédiée |
| SC-5 (Flash render? + API inchangée) | Task 4 specs blank/empty |
| SC-6 (8 UNDEFINED_TOKENS) | Tasks 2 et 4 |
| SC-7 (0 classe legacy) | Tasks 2 et 4 regex bans |
| SC-8 (0 dark: pair Flash) | Task 4 spec dédiée |
| SC-9 (6 sites Flash OK) | Task 1 + Task 6 |
| SC-10 (CI verte) | Task 7 step 4 |

Aucun gap identifié.

### Placeholder scan

Aucun "TBD", "TODO", "implement later", "add validation", "similar to Task N", "fill in details".

### Type consistency

- `ModalComponent` API : `title:` (string), `title_id:` (string nullable), slot `body` (cohérent Tasks 2, 3, 6).
- `FlashComponent` API : `type:` (`:notice` | `:alert`), `message:` (string nullable), `render?` (bool) (cohérent Tasks 4, 5).
- Tokens `success` / `danger` : mêmes noms entre Section Templates spec et constante `TYPES` (cohérent).
- Pattern `%w[...].each do |token|` inline (pas de constante `UNDEFINED_TOKENS` qui collidait en B3a) : Tasks 2 et 4 identiques.

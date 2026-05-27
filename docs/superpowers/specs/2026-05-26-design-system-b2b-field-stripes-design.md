# Feature B2b — FieldComponent + StripesComponent (création atomes)

**Date** : 2026-05-26
**Branche cible** : `067-design-system-b2b-field-stripes`
**Phase** : B2b — deuxième sous-feature de B2 (atomes du design system Radical unifié)
**Prérequis** : B1 (PR #102, tokens 2 couches), B2a (PR #110, refonte 3 atomes existants)
**DEPRECATED removal tracking** : [issue #109](https://github.com/a2p0/dekatje-bak-la/issues/109) — étendue pour B2b (partial `_field.html.erb`)

---

## 1. Contexte

Phase 3/8 du chantier design system Radical unifié (suite de B1 et B2a). B2a a refondu 3 ViewComponents atomiques existants (Button, Badge, Card) avec API sémantique + DEPRECATED aliases pour zéro régression. B2b complète la palette d'atomes avec **2 composants entièrement nouveaux** : `FieldComponent` (wrapper input unifié) et `StripesComponent` (bandeau 4 couleurs signature Radical).

Roadmap source : `docs/design-system/2026-05-17-radical-unified-synthesis.md` §4.1.

Contrairement à B2a, **pas de rétrocompat à gérer** pour les composants eux-mêmes (création pure). Toutefois, un partial Rails existant `app/views/teacher/shared/_field.html.erb` (utilisé par 4+ vues teacher) recouvre une partie du périmètre Field. Décision validée brainstorming 2026-05-26 : conserver ce partial intact (DEPRECATED header ajouté), migration des 4 vues prévue en B5.

---

## 2. Objectif

Créer 2 ViewComponents atomiques manquants consommant les tokens B1 réels, prêts à être consommés par les composés B3 (NavBar, layouts) et les vues B4/B5 (reskin student/teacher).

---

## 3. Périmètre

### 3.1 In scope

- `FieldComponent` : wrapper input form-builder-aware (6 types : `:text, :textarea, :file, :file_dropzone, :select, :checkbox`)
- `StripesComponent` : bande 4 couleurs sans paramètre, audience-aware via tokens accent
- Tests RSpec ViewComponent (variantes, états d'erreur, B1 contract guard)
- Header DEPRECATED ajouté sur `app/views/teacher/shared/_field.html.erb`
- Mise à jour de l'issue #109 avec une section B2b

### 3.2 Out of scope

- **Aucune migration de vue** : les 4 vues teacher (`classrooms/new`, `classrooms/edit`, `subjects/new`, `questions/_question_form`) continuent à utiliser le partial. Migration en B5.
- Aucune adoption de Stripes dans les layouts (`application.html.erb`, `teacher.html.erb`, `student.html.erb` non touchés). Adoption prévue en B5/B7.
- Page démo `/teacher/design-system/preview` non touchée (PR docs dédiée plus tard).
- Composés (NavBar, Modal, Flash, ProgressBar, EmptyState, etc. → B3).
- Stimulus controller `dropzone` pour drag-and-drop (YAGNI — pas demandé aujourd'hui).
- Types Field au-delà des 6 listés (`:number, :email, :password` etc. retirés par YAGNI — aucune vue actuelle n'en utilise).

### 3.3 YAGNI cuts explicites

Validés brainstorming 2026-05-26 (voir mémoire [[feedback-yagni-discipline]]) :

- ❌ `label:` auto-derivation via `form.label attribute` → `label:` est requis
- ❌ `accept:` séparé de `options:` → passe via `options: { accept: ... }`
- ❌ `data: { dropzone_target: "input" }` dans la dropzone → aucun Stimulus controller cible
- ❌ Types `:number, :email, :password` → aucun usage actuel
- ❌ Configurabilité de Stripes (hauteur, orientation, couleurs custom) → signature fixe Radical

---

## 4. Critères de succès

| ID | Critère | Validation |
|---|---|---|
| SC-1 | Les 2 composants consomment exclusivement des tokens B1 réels (pas de couleur Tailwind hardcodée, pas de token fantôme) | RSpec : B1 contract guard `UNDEFINED_TOKENS` sur chaque composant + grep manuel |
| SC-2 | Zéro régression sur les 4 vues teacher qui utilisent le partial `_field.html.erb` (intact sauf header DEPRECATED) | Diff `git show -- _field.html.erb` ne touche que les commentaires |
| SC-3 | FieldComponent rend correctement les 6 types avec helpers Rails attendus et tokens B1 | RSpec ViewComponent : 1 spec par type + erreur/hint/label |
| SC-4 | StripesComponent rend une div flex 5px avec 4 bandes aux tokens corrects, `aria-hidden="true"` | RSpec ViewComponent |
| SC-5 | CI verte, tous les composants specs passent | GitHub Actions |
| SC-6 | Issue #109 mise à jour avec section B2b (partial `_field.html.erb` à migrer en B5) | Manuel : `gh issue view 109` |

---

## 5. Architecture

### 5.1 FieldComponent

**Fichiers** :
- `app/components/field_component.rb`
- `app/components/field_component.html.erb`

**API publique** :

```ruby
FieldComponent.new(
  form:,                  # form builder Rails (requis)
  attribute:,             # symbol du champ (requis)
  label:,                 # String (requis — pas de dérivation auto)
  type: :text,            # :text | :textarea | :file | :file_dropzone | :select | :checkbox
  hint: nil,              # String optionnel
  collection: nil,        # Array pour :select (requis si type == :select)
  options: {}             # Hash passé au helper Rails (accept, placeholder, required, rows, etc.)
)
```

**Validation d'init** :
- `type: :select` sans `collection:` → `ArgumentError` (« FieldComponent: :select requires a collection »)

**Classes communes du champ** :
```
bg-surface text-on-surface
border border-rule rounded-lg
px-3 py-2 text-sm
focus:outline-none focus:ring-2 focus:ring-accent-secondary focus:border-accent-primary
disabled:opacity-60 disabled:cursor-not-allowed
w-full
```

**En cas d'erreur** (`form.object.errors[attribute].any?`) :
- Le champ ajoute `border-danger` (override de `border-rule`)
- Sous le champ : `<p class="text-danger text-xs mt-1 font-semibold">` avec chaque message d'erreur

**Label** :
- `<label class="block text-sm font-semibold text-on-surface mb-1">`

**Hint** :
- `<p class="text-on-surface-muted text-xs mt-1">`
- Affiché seulement si `hint:` fourni
- Pas affiché pour `:checkbox` (le label est inline)

**Comportement par type** :

| `type` | Helper Rails | Particularités |
|---|---|---|
| `:text` | `f.text_field attribute, **merged_options` | classes communes |
| `:textarea` | `f.text_area attribute, **merged_options` | + `min-h-24`, `rows` overridable via `options:` |
| `:file` | `f.file_field attribute, **merged_options` | input file natif Rails, classes pour file: `text-sm file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-accent-secondary/15 file:text-accent-secondary hover:file:bg-accent-secondary/25` |
| `:file_dropzone` | wrapper custom + `f.file_field` `sr-only` | voir bloc dédié ci-dessous |
| `:select` | `f.select attribute, collection, options, html_options` | classes communes + `appearance-none` ; raise si collection nil |
| `:checkbox` | `f.check_box attribute, **merged_options` | label aligné inline : `<label class="flex items-center gap-2"><input ...><span>label</span></label>` ; `accent-accent-primary h-4 w-4 rounded` |

**Dropzone (`:file_dropzone`) markup** :

Le wrapper est un `<label>` HTML standard qui contient le `<input type="file" sr-only>`. C'est le mécanisme HTML idiomatique pour rendre une zone arbitraire cliquable et déclencher l'ouverture du sélecteur de fichier — sans JavaScript.

```erb
<%= @form.label @attribute, class: "w-full p-5 rounded-lg border-2 border-dashed border-rule bg-surface-raised flex flex-col items-center gap-2 cursor-pointer" do %>
  <div class="w-9 h-9 rounded-lg bg-accent-secondary/15 flex items-center justify-center">
    <%# Upload icon SVG inline %>
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
         class="text-accent-secondary">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
      <polyline points="17 8 12 3 7 8"/>
      <line x1="12" y1="3" x2="12" y2="15"/>
    </svg>
  </div>
  <div class="text-center">
    <div class="text-sm font-semibold text-accent-secondary">Déposer un fichier</div>
    <% if @hint %>
      <div class="text-xs text-on-surface-muted"><%= @hint %></div>
    <% end %>
  </div>
  <%= @form.file_field @attribute, **@options.merge(class: "sr-only") %>
<% end %>
```

**Note a11y** :
- Le `<label>` enveloppe l'input `file` (rendu `sr-only`) — cliquer n'importe où dans le wrapper déclenche l'input par mécanisme HTML standard.
- L'input reste accessible screen readers via la classe `sr-only` (visuellement caché mais focusable).
- Le label visuel "Déposer un fichier" est dans le wrapper, pas un `<label>` séparé pour éviter double-labelling.
- **`label:` du composant est ignoré pour `:file_dropzone`** : le titre visuel est figé à "Déposer un fichier" (cohérence design Radical). Le `label:` du composant peut servir à un éventuel `aria-label` futur si besoin (pas implémenté maintenant — YAGNI).
- Le drag-and-drop nécessitera un Stimulus controller séparé en B5 (hors scope B2b).

### 5.2 StripesComponent

**Fichier** :
- `app/components/stripes_component.rb` (style `.call` — pas de template ERB séparé)

**API publique** :

```ruby
StripesComponent.new  # zéro param
```

**Rendu** :

```ruby
class StripesComponent < ViewComponent::Base
  def call
    content_tag(:div, class: "flex h-[5px] flex-shrink-0", "aria-hidden": "true") do
      safe_join([
        content_tag(:div, "", class: "flex-1 bg-accent-primary"),
        content_tag(:div, "", class: "flex-1 bg-warning"),
        content_tag(:div, "", class: "flex-1 bg-accent-secondary"),
        content_tag(:div, "", class: "flex-1 bg-on-surface")
      ])
    end
  end
end
```

**Tokens utilisés** (mapping validé brainstorming) :
- Bande 1 → `bg-accent-primary` (rouge student, teal teacher après audience swap)
- Bande 2 → `bg-warning` (jaune global, état non swappable — identique partout)
- Bande 3 → `bg-accent-secondary` (teal student, rouge teacher)
- Bande 4 → `bg-on-surface` (ink en light, cream en dark)

**A11y** : `aria-hidden="true"` car purement décoratif.

**Hauteur** : 5px (aligné sur `teacher/shared.jsx:64`). Le bundle `radical.jsx:22` utilise 6px, mais 5px est privilégié pour cohérence inter-audience.

### 5.3 Partial `_field.html.erb` (DEPRECATED header)

Le partial `app/views/teacher/shared/_field.html.erb` reste fonctionnellement intact (4 vues teacher dépendantes). Seul son commentaire de tête change :

```erb
<%#
  DEPRECATED — see #109

  This partial is kept until B5 (teacher reskin) migrates the 4 calling views
  to FieldComponent:
    - app/views/teacher/classrooms/new.html.erb
    - app/views/teacher/classrooms/edit.html.erb
    - app/views/teacher/subjects/new.html.erb
    - app/views/teacher/questions/_question_form.html.erb

  New code should use FieldComponent:
    <%%= render FieldComponent.new(form: f, attribute: :name, label: "Nom", type: :text) %%>

  Tracked: https://github.com/a2p0/dekatje-bak-la/issues/109

  ## Original locals (preserved)
  f          — form builder Rails (obligatoire)
  field      — Symbol, nom du champ (obligatoire)
  label_text — String, texte du label (obligatoire)
  type       — Symbol : :text, :textarea, :file, :select, :checkbox (défaut :text)
  options    — Hash, options supplémentaires (défaut {})
  hint       — String optionnel
  collection — Array [label, value] pour :select
%>
```

### 5.4 Ordre d'implémentation interne

1. **StripesComponent** d'abord (très petit, calibre le pattern `.call`)
2. **FieldComponent** ensuite (plus complexe, 6 types, dropzone SVG)
3. **DEPRECATED header** sur `_field.html.erb` en dernier (toggle docs)

---

## 6. Validation et tests

### 6.1 Tests RSpec ViewComponent

**`spec/components/field_component_spec.rb`** (~13 examples) :

- `:text` → rend `<input type="text">` + classes communes B1 (`bg-surface`, `border-rule`, `focus:ring-accent-secondary`)
- `:textarea` → rend `<textarea>` + classes communes + `min-h-24`
- `:file` → rend `<input type="file">` + classes file: spécifiques (`file:bg-accent-secondary/15`)
- `:file_dropzone` → rend `<label>` dashed (cliquable) + SVG + input `<input type="file">` avec `sr-only` à l'intérieur du label
- `:select` avec `collection:` → rend `<select>` avec `<option>` populés
- `:select` sans `collection:` → raise `ArgumentError`
- `:checkbox` → rend `<label><input type="checkbox"><span>` aligné inline
- Label `:` rendu avec `text-on-surface font-semibold mb-1`
- `hint:` fourni → `<p class="text-on-surface-muted">` visible
- `hint:` nil → pas de `<p>` hint
- Erreur sur `form.object.errors[attribute]` → `border-danger` sur champ + `<p class="text-danger">`
- `options: { placeholder: "X" }` → passe au helper Rails (placeholder visible dans HTML)
- B1 contract guard : aucun `UNDEFINED_TOKENS` dans le HTML pour les 6 types

**`spec/components/stripes_component_spec.rb`** (~5 examples) :

- Rend exactement 4 child divs
- Chaque div a le bon token : `bg-accent-primary`, `bg-warning`, `bg-accent-secondary`, `bg-on-surface`
- Wrapper a `flex`, `h-[5px]`, `flex-shrink-0`
- Wrapper a `aria-hidden="true"`
- B1 contract guard : aucun `UNDEFINED_TOKENS`

### 6.2 CI

Pipeline inchangé. La suite RSpec complète s'exécute. Aucun spec system/feature ajouté — les atomes sont testés en isolation.

### 6.3 Visual regression

Non utilisée pour B2b (pattern validé B2a : specs RSpec sur classes rendues suffisent pour les composants en isolation sans consommateur). L'outil `lib/tasks/visual_regression.rake` reste disponible mais non invoqué.

---

## 7. Mise à jour issue #109

Section à ajouter au body de l'issue :

```markdown
### B2b — Partial `_field.html.erb` à migrer

`app/views/teacher/shared/_field.html.erb` reste actif pour 4 vues teacher.
À migrer vers `FieldComponent` en B5 (reskin teacher) :
- app/views/teacher/classrooms/new.html.erb
- app/views/teacher/classrooms/edit.html.erb
- app/views/teacher/subjects/new.html.erb
- app/views/teacher/questions/_question_form.html.erb

Une fois les 4 vues migrées, supprimer le partial.
```

---

## 8. Risques et mitigations

| Risque | Probabilité | Mitigation |
|---|---|---|
| Token fantôme utilisé par erreur | Faible | B1 contract guard sur les 2 specs (pattern B2a) |
| `:file_dropzone` non testée visuellement (pas de consommateur en B2b) | Moyenne | Pixel-validation requise au 1er usage (B5). Documenté en commentaire dans `field_component.rb`. |
| API `:select` avec collection mal formée (pas `[[label, value], ...]`) | Faible | Helper Rails `f.select` gère déjà ; spec dédié pour le format attendu |
| Dropzone clickable sans label HTML standard (a11y) | Moyenne | Vérifier que le `sr-only` `<input file>` est cliquable via le wrapper. Si pas, wrapper devient `<label>`. Test feature optionnel en B5. |

---

## 9. Définition de "terminé"

Conforme à la constitution §Definition of Done :

- [x] Plan validé par l'utilisateur avant implémentation *(en cours)*
- [ ] Tests RSpec passent (FieldComponent + StripesComponent + B1 guard)
- [ ] Branche dédiée `067-design-system-b2b-field-stripes` créée
- [ ] PR créée et CI verte
- [ ] Partial `_field.html.erb` annoté DEPRECATED sans changement comportemental
- [ ] Issue #109 mise à jour
- [ ] Pas de couleur Tailwind hardcodée dans les 2 nouveaux composants (grep `bg-indigo|bg-emerald|bg-violet|bg-slate` = 0 match)

---

## 10. Suite

Après merge B2b :
- **B3** — composés (NavBar, Modal, Flash, ProgressBar, EmptyState, BottomBar, Breadcrumb, ThemeToggle)
- **B4** — adoption student (5 CTA ad-hoc → ButtonComponent)
- **B5** — reskin teacher (`data-audience="teacher"` activé, migration partial `_field.html.erb` → FieldComponent, suppression des aliases B2a, adoption Stripes dans layouts)
- **B6** — cleanup magic numbers
- **B7** — polish desktop élève

---

## Annexes

### A.1 Fichiers touchés

```
app/components/field_component.rb            (création)
app/components/field_component.html.erb      (création)
app/components/stripes_component.rb          (création, style .call)
app/views/teacher/shared/_field.html.erb     (modification : header DEPRECATED seulement)
spec/components/field_component_spec.rb      (création)
spec/components/stripes_component_spec.rb    (création)
```

### A.2 Références

- Roadmap : `docs/design-system/2026-05-17-radical-unified-synthesis.md` §4.1
- Bundle Field : `.design-bundles/h-YiyL6SBBamTp3pu9UnSZsg/project/teacher/shared.jsx:171-201`
- Bundle Stripes : `.design-bundles/h-YiyL6SBBamTp3pu9UnSZsg/project/teacher/shared.jsx:62-70` et `directions/radical.jsx:21-27`
- B1 livré : PR #102, tokens documentés dans `app/assets/tailwind/application.css`
- B2a livré : PR #110 (squash `ef86a79`), pattern DEPRECATED + B1 contract guard
- Issue de suivi : [#109](https://github.com/a2p0/dekatje-bak-la/issues/109)

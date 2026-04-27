# Data Model: Teacher Pages Redesign (050)

## Pas de changements de modèle

Cette feature est un redesign pur des vues ERB. Aucune migration, aucun modèle, aucun controller ne sont modifiés.

## Nouveaux artefacts de vue

### Partial `app/views/teacher/shared/_field.html.erb`

Centralise le style des champs de formulaire enseignant.

**Interface** (locals attendus) :
- `f` — form builder Rails (obligatoire)
- `field` — Symbol, nom du champ (obligatoire)
- `label_text` — String, texte du label (obligatoire)
- `type` — Symbol : `:text`, `:textarea`, `:file`, `:select`, `:checkbox` (défaut : `:text`)
- `options` — Hash, options supplémentaires passées au helper Rails (défaut : `{}`)
- `hint` — String, texte d'aide sous le champ (optionnel)

**Rendu** : label + champ + erreurs inline + hint éventuel, avec classes Tailwind centralisées.

### BreadcrumbComponent (existant — `app/components/breadcrumb_component.rb`)

Déjà implémenté dans la feature 025. Interface : `items: [{label:, href:}]`.
Sera ajouté dans les vues `subjects/show`, `subjects/new`, `parts/show`, `subjects/assignments/edit`.

## ViewComponents existants utilisés (rappel)

| Composant | Props clés | Utilisé dans |
|---|---|---|
| `ButtonComponent` | `variant`, `size`, `href`, `pill` | Tous les formulaires et pages de liste |
| `CardComponent` | `variant` (default/glow) | Sections de détail |
| `BadgeComponent` | `color`, `label` | Statuts et spécialités |
| `ProgressBarComponent` | `current`, `total`, `color` | subjects/_stats |
| `BreadcrumbComponent` | `items: [{label, href}]` | Pages de profondeur ≥ 2 |

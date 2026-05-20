# Implementation Plan: Architecture tokens 2 couches pour thème Radical unifié (B1)

**Branch**: `065-design-tokens-2-layers` | **Date**: 2026-05-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/065-design-tokens-2-layers/spec.md`

## Summary

Refondre l'architecture des tokens de couleur en deux couches :
1. **Primitives** (couleurs absolues nommées par essence : `--rad-prim-cream`, `--rad-prim-balisier-red`, `--rad-prim-teal`, etc.) — source de vérité, jamais consommées par les vues.
2. **Sémantiques** (rôles d'usage : `--color-surface`, `--color-accent-primary`, `--color-success`, etc. — set minimum garanti de **19 tokens**) — consommées par les vues et composants.

Mapping par audience via un attribut HTML `data-audience` (`student` / `teacher` / `public`) posé sur `<body>` du layout correspondant. Mode dark conservé via la classe `.dark` existante sur `<html>`, croisée avec l'audience → 6 combinaisons (3 audiences × 2 modes).

Les 12 tokens existants `--color-rad-*` deviennent des **aliases** pointant vers la nouvelle couche pour assurer la rétrocompatibilité 100 %. Aucune vue ni composant existant n'est modifié.

Livrables additionnels : (a) spec RSpec automatisé vérifiant le mapping audience-dépendant via `getComputedStyle`, (b) page démo persistante `/teacher/design-system/preview` sous auth teacher servant de Storybook-light pour les phases B2-B7.

**Approche technique** : Tailwind v4 `@theme` pour la couche primitives + sémantiques, sélecteurs d'attribut `[data-audience="X"]` pour les overrides. Détails dans `research.md`.

## Technical Context

**Language/Version**: Ruby 3.3+, Rails 8.1.3, Tailwind CSS v4
**Primary Dependencies**: `tailwindcss-rails` (déjà intégré), ViewComponent (existant), Capybara + Selenium pour test SC-003
**Storage**: N/A (refacto CSS pure + 1 controller stateless)
**Testing**: RSpec + Capybara (Chrome headless). Outil de diff visuel CLI : ImageMagick `compare -metric AE` (à confirmer dans research.md Q3)
**Target Platform**: Navigateurs modernes (Chrome/Firefox/Safari 15.4+ — confirmé dans Definition of Done §6). Linux Fedora dev, GitHub Actions Ubuntu CI
**Project Type**: Web application Rails fullstack Hotwire
**Performance Goals**: Aucune dégradation perceptible. CSS compilé : +10 % brut max, +5 % gzippé max (SC-007)
**Constraints**:
- Rétrocompatibilité 100 % : aucune vue/composant existant ne change visuellement (tolérance diff visuel ≤ 1 % pixels ET ΔE ≤ 2 par pixel, SC-001)
- Tailwind v4 syntaxe `@theme` exclusivement (pas de `tailwind.config.js`)
- Compatible script dark mode existant (`.dark` sur `<html>`, lecture `localStorage` + `prefers-color-scheme`)
- `data-audience` doit être lisible par tous les composants descendants via `var(--color-*)`
- Aucun JavaScript nouveau hormis ce que la page démo requiert pour ses interactions de preview
**Scale/Scope**:
- 19 tokens sémantiques × 6 combinaisons (3 audiences × 2 modes) = 114 valeurs de mapping CSS
- ~25-30 primitives (light + dark) au total
- 3 fichiers Rails modifiés (layouts) + 2 nouveaux fichiers (controller + vue page démo) + tests
- Aucune migration de base de données

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Évaluation contre `.specify/memory/constitution.md` v2.1.0 :

| Principe | Conformité | Note |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | ✅ | CSS pur + 1 controller Rails stateless pour la page démo. Pas de SPA, pas de framework JS. |
| II. RGPD & Protection mineurs | ✅ | Aucune donnée personnelle, aucun élève impacté. Page démo sous auth teacher. |
| III. Security | ✅ | Page démo gated par `authenticate_user!` (Devise teacher). Aucun secret manipulé. |
| IV. Testing (TDD, NON-NEGOTIABLE) | ✅ | Specs prévus : (a) présence tokens sémantiques dans CSS compilé, (b) `data-audience` dans layouts, (c) mapping audience-dépendant via Capybara. Pas de migration ⇒ pas de spec migration. |
| V. Performance & Simplicity | ✅ | Approche minimale (3 couches CSS + 1 attribut HTML + 1 page démo). Pas d'optim prématurée. Seuils CSS bornés (SC-007). |
| VI. Development Workflow (NON-NEGOTIABLE) | ✅ | Speckit en cours (specify ✅ + clarify ✅ + plan ↻). Feature branch `065-design-tokens-2-layers` créée. PR systématique prévue. 1 concern (tokens) = 1 PR. |
| RGPD & Security Requirements | ✅ | Aucun impact. |
| Definition of Done | ✅ | Tous les critères atteignables : plan validé (en cours), specs prévus, branche dédiée, PR + CI, Chrome + Firefox supportés, pas de secret, RGPD inchangé, code en anglais (variables CSS sémantiques en anglais). |

**Verdict** : **0 violation**. La feature est dans l'esprit de la constitution (refacto safe, scope strict, rétrocompat 100 %). Pas de Complexity Tracking nécessaire.

Re-check après Phase 1 : voir section dédiée en fin de plan.

## Project Structure

### Documentation (this feature)

```text
specs/065-design-tokens-2-layers/
├── spec.md              # Spec validée (clarifications session 2026-05-17)
├── plan.md              # Ce fichier
├── research.md          # Phase 0 — décisions techniques (Tailwind v4, dark+audience, diff visuel, etc.)
├── data-model.md        # Phase 1 — entités tokens (primitives, sémantiques, aliases)
├── contracts/
│   └── design-tokens.md # Phase 1 — contrat API tokens consommables
├── quickstart.md        # Phase 1 — comment consommer les tokens (pour B2-B7)
├── checklists/
│   └── requirements.md  # 10/10 ✅
└── tasks.md             # Phase 2 (à générer par /speckit.tasks après ce plan)
```

### Source Code (repository root)

Structure ciblée pour cette feature (uniquement les fichiers touchés ou créés) :

```text
app/
├── assets/
│   └── tailwind/
│       └── application.css                   # MODIFIÉ — ajout primitives + sémantiques + mappings audience + bridge aliases
├── views/
│   └── layouts/
│       ├── application.html.erb              # MODIFIÉ — ajout data-audience="public" sur <body>
│       ├── student.html.erb                  # MODIFIÉ — ajout data-audience="student" sur <body>
│       └── teacher.html.erb                  # MODIFIÉ — ajout data-audience="teacher" sur <body>
├── controllers/
│   └── teacher/
│       └── design_system_controller.rb       # NOUVEAU — page démo Storybook-light
└── views/
    └── teacher/
        └── design_system/
            └── preview.html.erb              # NOUVEAU — vue page démo (19 tokens × 6 combinaisons)

config/
└── routes.rb                                 # MODIFIÉ — route /teacher/design-system/preview

spec/
├── features/
│   └── teacher/
│       └── design_system_preview_spec.rb     # NOUVEAU — feature spec page démo (accessible + render)
├── system/
│   └── design_tokens_audience_mapping_spec.rb # NOUVEAU — vérifie SC-003 (mapping audience-dépendant via getComputedStyle)
└── lib/
    └── tasks/
        └── css_size_audit_spec.rb            # NOUVEAU (optionnel) — vérifie SC-007 (poids CSS)
```

**Structure Decision** :
- Aucun nouveau module Rails (pas de namespace ou engine). Refacto CSS + 1 mini-controller stateless.
- Le controller `Teacher::DesignSystemController` hérite de `Teacher::BaseController` (déjà existant, gère `authenticate_user!`).
- Pas de modèle, pas de migration, pas de service.
- Tests structurés en `features/` (Capybara : page démo accessible) + `system/` (Capybara : mapping audience). Pas de tests unitaires pour B1 car il n'y a pas de logique Ruby substantielle.
- Le test SC-007 (poids CSS) est délibérément optionnel et non-bloquant : c'est une mesure à reporter dans le body de PR, pas un test CI qui peut flaker selon l'environnement de compilation.

## Complexity Tracking

> Constitution Check est passé sans violation. Section vide.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

---

## Phase 0 — Research (sortie : research.md)

**Status** : research.md généré en parallèle par agent dédié, voir fichier.

### Inconnues techniques à résoudre

1. **Q1 — Tailwind v4 + sélecteurs d'attribut dans `@theme`** : peut-on définir des tokens qui varient selon `[data-audience="X"]` en restant compatible avec la génération de classes utilitaires Tailwind ? Fallback `@layer base` si non.
2. **Q2 — Combiner `[data-audience]` (sur `<body>`) + `.dark` (sur `<html>`)** : sélecteurs CSS portables (Chrome/Firefox/Safari récents). Évaluation `body[data-audience]` vs `:has()` vs `@scope`.
3. **Q3 — Outil CLI diff visuel** : ImageMagick `compare` vs `pixelmatch` vs autres. Critères : install Fedora, métriques % pixels + ΔE, sortie machine-readable, légèreté.
4. **Q4 — Lecture CSS custom property via Capybara/Selenium** : pattern exact `page.evaluate_script("getComputedStyle(...).getPropertyValue(...)")`. La valeur résolue est-elle la primitive ou le `var(...)` brut ?
5. **Q5 — Mesurer poids CSS Rails compilé (brut + gzip)** : commandes exactes, chemins, méthode de compression.

Les réponses (Decision / Rationale / Alternatives / Sources) alimentent `research.md` et lèvent les `NEEDS CLARIFICATION` implicites du Technical Context.

---

## Phase 1 — Design & Contracts (sorties : data-model.md, contracts/, quickstart.md)

### data-model.md (à générer)

Entités du système de tokens :

1. **Primitive** : nom (essence visuelle), valeur hex light, valeur hex dark
2. **Sémantique** : nom (rôle d'usage), références primitives par audience × mode (6 combinaisons)
3. **Alias rétrocompatible** : nom ancien `--color-rad-*`, référence vers primitive ou sémantique cible

État des transitions : N/A (tokens sont statiques, pas de cycle de vie).

Liste exhaustive des 19 tokens sémantiques garantis (FR-003 verrouillé) avec leur mapping par défaut (student-light) :
- `surface`, `surface-raised`, `surface-sunken`
- `on-surface`, `on-surface-muted`
- `rule`, `rule-strong`
- `accent-primary`, `on-accent-primary`
- `accent-secondary`, `on-accent-secondary`
- `success`, `on-success`
- `warning`, `on-warning`
- `danger`, `on-danger`
- `info`, `on-info`

### contracts/design-tokens.md (à générer)

Contrat de consommation pour les futurs développeurs (B2-B7) :
- Quels tokens sémantiques consommer pour quel cas d'usage
- Convention de nommage `var(--color-<role>)` ou classe Tailwind `bg-<role>` (selon Q1 research)
- Ce qu'il ne faut PAS faire (consommer des primitives directement, hardcoder des hex, etc.)
- Garantie de stabilité : le set minimum de 19 tokens est stable pour B2-B7. Ajouts possibles, retraits interdits.

### quickstart.md (à générer)

Guide « comment utiliser le nouveau système » pour B2-B7 :
- Exemple : refondre un Button avec `var(--color-accent-primary)` / `bg-accent-primary`
- Comment tester son composant sous les 3 audiences (visite `/teacher/design-system/preview` ou écrire un spec qui force `<body data-audience>`)
- FAQ : quand utiliser `surface-raised` vs `surface`, `rule` vs `rule-strong`, etc.

### Agent context update

Exécuter `.specify/scripts/bash/update-agent-context.sh claude` après la rédaction de la spec et du plan pour ajouter au contexte agent les nouvelles conventions design tokens (à confirmer en Phase 2 si le script en a besoin pour `/speckit.tasks`).

### Constitution Check (re-évaluation post-design)

À re-faire **après** la rédaction de research.md + data-model.md + contracts/ + quickstart.md. La conformité actuelle est solide ; les risques seraient :
- Si research.md révèle qu'un workaround complexe est nécessaire (ex: Tailwind v4 ne supporte pas les attributs dans `@theme`), évaluer si le workaround viole le principe V (simplicity) → si oui, Complexity Tracking à remplir.
- Si data-model.md révèle qu'il faut plus de 25 primitives ou plus de 25 tokens sémantiques pour atteindre la rétrocompatibilité, évaluer si le scope reste maintenable → si non, ajustement spec nécessaire avant Phase 2.

---

## Notes pour /speckit.tasks (Phase 2, hors scope de ce plan)

Le découpage en tâches devra refléter l'ordre :
1. **Setup** : research.md validé, structure de fichiers prête.
2. **Tests d'abord** (TDD constitution) : écrire les specs FR-014 + FR-015 + SC-003 qui doivent échouer initialement.
3. **Couche primitives** dans `application.css`.
4. **Couche sémantique** + mappings light/dark × 3 audiences.
5. **Bridge aliases** `--color-rad-*` pointant vers la nouvelle couche.
6. **Ajout `data-audience`** dans les 3 layouts.
7. **Specs verts** : faire passer les specs FR-014, FR-015.
8. **Page démo** : controller + route + vue + spec accessibility.
9. **Spec SC-003** : passe maintenant que tout est en place.
10. **Mesure CSS** : reporter dans PR (avant/après brut + gzip).
11. **Validation visuelle SC-001** : 3 écrans captures avant/après + diff CLI.
12. **PR** : body documente les 7 SC, CI verte, mesures CSS, captures.

Ordre estimé : 12 tâches, dont 5-6 peuvent être groupées en un seul commit (les fichiers CSS et layouts vont ensemble, en pratique).

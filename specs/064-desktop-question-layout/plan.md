# Implementation Plan: Desktop Question Layout (questions#show)

**Branch** : `064-desktop-question-layout` | **Date** : 2026-05-11 | **Spec** : [spec.md](./spec.md)
**Input** : Feature specification from `/specs/064-desktop-question-layout/spec.md`

## Summary

Refonte du layout desktop élève pour `questions#show` à partir de `lg:` (≥1024px). Le mobile reste inchangé. Sur desktop : top navbar (logo + tabs + bouton Parties + bouton Tibo + avatar) + breadcrumb + split 50/50 (colonne question | colonne DT viewer). En mode correction, la colonne gauche affiche les cartes verte/jaune existantes. En mode tutorat, le drawer Tibo remplace la colonne DT droite en split 60/40 (chat | contexte question).

Approche technique : pure CSS Tailwind (`lg:`) sur l'ERB existant, repositionnement de la sidebar en popover via Stimulus `sidebar_controller` recyclé, adaptation du `chat_drawer_controller` pour absorber 60% de la largeur desktop et exposer un panneau contexte. Pas de nouveau modèle, pas de migration, pas de nouvelle gem.

## Technical Context

**Language/Version** : Ruby 3.3+ / Rails 8.1.3
**Primary Dependencies** : Hotwire (Turbo, Stimulus), ViewComponent, Tailwind CSS 4, ActiveStorage (PDF DT)
**Storage** : PostgreSQL via Neon — aucun changement schema (lecture seule de `Subject.dt_file`, `Question.dt_references`, `Answer.data_hints`)
**Testing** : RSpec + FactoryBot + Capybara (driver `:headless_chrome`, window 1400×900 — déjà desktop)
**Target Platform** : Browser desktop ≥1024px (Chrome, Firefox), Browser mobile <1024px (inchangé)
**Project Type** : Web application (Rails fullstack)
**Performance Goals** : Aucune nouvelle requête réseau (NFR-003) ; iframe PDF déjà chargée en mobile
**Constraints** : Palette `rad-*` uniquement (NFR-002), accessibilité clavier (NFR-001), pas de nouvelle dépendance JS
**Scale/Scope** : 1 page ERB principale (`show.html.erb`) + 4-5 partials + 2-3 Stimulus controllers (réutilisés/étendus) + 3 feature specs Capybara

## Constitution Check

Vérification contre `.specify/memory/constitution.md` v2.1.0.

| Principe | Statut | Justification |
|---|---|---|
| **I. Fullstack Rails — Hotwire Only** | ✅ | Hotwire/Turbo Streams + Stimulus, aucune SPA. Tout depuis le server. |
| **II. RGPD & mineurs** | ✅ | Aucune nouvelle collecte de données. Auth élève inchangée. |
| **III. Security** | ✅ | Aucune nouvelle API key, aucun secret. Pas de log de PII. |
| **IV. Testing (NON-NÉGOCIABLE)** | ✅ | TDD strict — specs Capybara desktop ÉCRITES AVANT le code prod. 3 feature specs (US1, US2, US3) + adaptation des specs existantes. |
| **V. Performance & Simplicity** | ✅ | CSS pur (media queries Tailwind), pas d'optimisation prématurée. Réutilisation maximale des composants existants. |
| **VI. Development Workflow** | ✅ | Branche `064-desktop-question-layout` créée. Plan présent. Workflow speckit suivi (specify → plan → tasks → analyze → implement). PR systématique à la fin. |

**Pas de violation** — pas de Complexity Tracking à remplir.

## Project Structure

### Documentation (this feature)

```text
specs/064-desktop-question-layout/
├── plan.md              # This file
├── spec.md              # Feature specification (amended 2026-05-11 to align with real data model)
├── research.md          # Phase 0 output — Stimulus + popover patterns
├── data-model.md        # Phase 1 output — read-only model surface used
├── quickstart.md        # Phase 1 output — verification script
├── contracts/
│   └── ui-contracts.md  # Phase 1 output — DOM/Stimulus contracts entre composants
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
app/
├── views/
│   ├── layouts/
│   │   └── student.html.erb                   # MODIFIED — insertion navbar desktop
│   └── student/
│       ├── questions/
│       │   ├── show.html.erb                  # MODIFIED — refonte layout `lg:` split 50/50
│       │   ├── _sidebar.html.erb              # MODIFIED — repositionné en popover (overlay style à `lg:`)
│       │   ├── _correction.html.erb           # MODIFIED — cartes adaptées au layout colonne gauche
│       │   ├── _dt_viewer.html.erb            # NEW — partial colonne droite (iframe PDF + bandeau)
│       │   ├── _data_hint_banner.html.erb     # NEW — bandeau "Donnée utile" pour mode correction
│       │   └── _desktop_nav.html.erb          # NEW — navbar desktop (logo, tabs, Parties, Tibo, avatar)
│       └── conversations/
│           ├── _drawer.html.erb               # MODIFIED — variantes `lg:` (60% largeur) + panneau contexte
│           └── _context_panel.html.erb        # NEW — panneau contexte (rappel question + objectif partie)
├── javascript/
│   └── controllers/
│       ├── sidebar_controller.js              # EXTENDED — comportement popover sur desktop (single-overlay coordination)
│       └── chat_drawer_controller.js          # EXTENDED — fermeture Parties à l'ouverture Tibo + classes desktop
└── helpers/
    └── student_helper.rb                      # MODIFIED (si nécessaire) — helper `primary_data_hint(question)`

spec/
└── features/
    ├── student_desktop_reading_spec.rb        # NEW (US1)
    ├── student_desktop_correction_spec.rb     # NEW (US2)
    ├── student_desktop_tutor_spec.rb          # NEW (US3)
    └── student_desktop_navigation_spec.rb     # NEW (US4 — popover Parties)
```

**Structure Decision** : Single Rails monolith. Le périmètre touche `app/views/`, `app/javascript/controllers/`, et `spec/features/`. Aucune nouvelle dépendance, aucun nouveau modèle. Adaptation par classes Tailwind `lg:` + extension légère de 2 Stimulus controllers.

## Phase 0 — Outline & Research

Voir [research.md](./research.md).

**Décisions clés** :

1. **Single-overlay coordination** (Parties ↔ Tibo) : événements DOM custom (`overlay:open`, `overlay:close`) entre `sidebar_controller` et `chat_drawer_controller`. Pas de state manager.
2. **Sidebar en popover** : pas d'élément séparé. Le `<aside>` actuel garde son markup ; on bascule `lg:relative lg:translate-x-0` → `lg:fixed lg:-translate-x-full` + bouton "Parties" qui appelle `sidebar#open` à toutes les tailles. Ré-utilisation pure.
3. **Drawer Tibo desktop 60/40** : ajout d'un panneau contexte interne au drawer. Largeur drawer passe de `lg:w-[420px]` à `lg:w-[60vw] lg:max-w-[900px]` quand desktop. Le panneau contexte est rendu dans le drawer existant (pas un nouvel élément).
4. **DT viewer** : iframe + bandeau références dérivé de `question.dt_references`. Bandeau "donnée utile" dérivé de `answer.data_hints.first` (seulement en mode correction).
5. **Navbar desktop** : insérée dans `layouts/student.html.erb` sous `<main>`, avec `class="hidden lg:flex ..."`. Conditionnellement rendue uniquement si `request.path` matche les routes élève (helper).

## Phase 1 — Design & Contracts

Voir [data-model.md](./data-model.md) et [contracts/ui-contracts.md](./contracts/ui-contracts.md).

**Pas de nouveau modèle.** Surface utilisée (lecture seule) :
- `Subject` : `title`, `exam`, `specialty`, `dt_file` (ActiveStorage), `presentation_text`
- `Part` : `number`, `title`, `objective_text`, `section_type`
- `Question` : `number`, `label`, `context_text`, `dt_references`, `dr_references`, `answer`
- `Answer` : `correction_text`, `explanation_text`, `data_hints` (JSONB `[{source, location}]`)
- `StudentSession` : `progression`, `answered?`, `answered_count_for`
- `Conversation` : `active?`, `messages`

**Contrats UI** : événements DOM (`overlay:open`, `overlay:close`), attributs `data-overlay-name` pour distinguer `sidebar` vs `tibo`, structure HTML attendue par les Stimulus controllers étendus.

**Quickstart** : voir [quickstart.md](./quickstart.md) — script de vérif manuelle desktop + mobile.

## Constitution Re-check (after Phase 1 design)

Tous les principes restent ✅. Le design ne crée pas de divergence :
- Pas de nouveau modèle ou migration.
- Pas de nouvelle dépendance JS.
- TDD préservé : specs Capybara avant code.
- Composants ViewComponent existants réutilisés (Card, Badge, Button).

## Complexity Tracking

*Aucune violation à justifier.*

# Implementation Plan: Metrics structurelles déterministes pour le tuning du prompt tuteur

**Branch**: `039-structural-metrics` | **Date**: 2026-04-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/039-structural-metrics/spec.md`

## Summary

Ajouter 4 métriques déterministes (`first_turn_with_transition`, `action_verb_ratio_guiding`,
`dt_dr_leak_count_non_spotting`, `short_message_ratio`) au service existant
`TutorSimulation::StructuralMetrics`, et un guard `SKIP_JUDGE=1` dans `TutorSimulation::Runner`
pour désactiver l'appel au juge LLM pendant les itérations de tuning prompt.

**Approche** : instrument-then-measure. On ne touche PAS au prompt tuteur dans ce feature.
On livre d'abord l'outil de mesure à signal propre (σ ≈ 0.01 vs ±0.50 du juge), puis dans
un feature ultérieur on re-testera H1/H2 avec cet instrument. Aucune migration DB, aucun
changement du pipeline `Tutor::ProcessMessage` de prod. Le `Runner` capture un tableau
`phase_per_turn` in-memory pendant la sim pour alimenter la métrique H1 sans persistance
nouvelle.

## Technical Context

**Language/Version**: Ruby 3.3+, Rails 8.1
**Primary Dependencies**: RSpec (tests), FactoryBot (fixtures). Services existants :
  `TutorSimulation::Runner`, `TutorSimulation::StructuralMetrics`,
  `TutorSimulation::ReportGenerator`, `TutorSimulation::Judge`.
**Storage**: N/A — feature in-memory only (pas de migration, pas de nouvelle table).
  Les résultats sont sérialisés dans `tmp/tutor_simulations/<timestamp>/raw.json`
  et `report.md` comme avant.
**Testing**: RSpec unitaires pour `StructuralMetrics`, RSpec d'intégration pour
  `Runner` avec mock du `judge_client` (vérification que `SKIP_JUDGE=1` empêche l'appel).
**Target Platform**: CLI rake task (`rake tutor:simulate`) exécutée localement ou
  dans GitHub Actions (`.github/workflows/tutor_simulation.yml` existant, déjà wired).
**Project Type**: Outil de développement interne (single project Rails).
**Performance Goals**: `StructuralMetrics.compute` < 50 ms sur une conversation de 10 tours
  (contrainte SC-001, code Ruby local, zéro I/O réseau).
**Constraints**:
  - Rétrocompat STRICTE de `StructuralMetrics.compute(conversation:)` (SC-004) —
    la signature existante continue de fonctionner sans arg nouveau.
  - Aucun changement de `Tutor::ProcessMessage` (pipeline prod).
  - Aucune migration DB.
  - Variance des 4 nouvelles métriques < 0.05 sur runs identiques (FR-005, SC-002).
**Scale/Scope**: 1 service existant étendu (~70 LOC → ~150 LOC estimées),
  1 guard env var dans 1 méthode du Runner (~5 LOC), 1 section `ReportGenerator`
  étendue (~20 LOC). ~8-10 specs RSpec ajoutés.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Audit vs `.specify/memory/constitution.md` v2.0.0 :

| Principe | Impact du feature | Verdict |
|---|---|---|
| **I. Fullstack Rails / Hotwire** | Aucun — c'est un service Ruby pur sans vue, sans Hotwire, sans AI call prod | ✅ PASS |
| **II. RGPD / Mineurs** | Aucun — n'affecte ni l'auth élève, ni les données élève. Les conversations simulées sont créées via un User/Student "tutor-sim" dédié | ✅ PASS |
| **III. Security** | Aucun — n'expose aucune clé, `ANTHROPIC_API_KEY` non touché, `SKIP_JUDGE` est un flag local dev | ✅ PASS |
| **IV. Testing (NON-NEGOTIABLE)** | TDD obligatoire : FR-012 + FR-013 imposent specs avant code. CI = runner autorité. Pas de feature spec Capybara requise (pas d'UI) | ✅ PASS — respecter ordre spec-first |
| **V. Performance & Simplicity** | SC-001 impose < 50 ms calcul local. Code Ruby lisible privilégié sur optimisation. Soft delete N/A | ✅ PASS |
| **VI. Development Workflow** | Plan validé avant code ✓. Branche dédiée `039-structural-metrics` ✓. PR systématique avant merge. One concern per commit. CI green par batch | ✅ PASS |

**Gate Result** : **PASS** (aucune violation, aucune justification requise dans Complexity Tracking).

## Project Structure

### Documentation (this feature)

```text
specs/039-structural-metrics/
├── spec.md                 # DONE (/speckit.specify output)
├── plan.md                 # THIS FILE (/speckit.plan output)
├── research.md             # Phase 0 output
├── data-model.md           # Phase 1 output
├── quickstart.md           # Phase 1 output
├── contracts/              # Phase 1 output (API interne du service)
│   └── structural_metrics_api.md
├── checklists/
│   └── requirements.md     # DONE (spec quality)
└── tasks.md                # Phase 2 output (/speckit.tasks, NOT created here)
```

### Source Code (repository root)

```text
app/services/tutor_simulation/
├── structural_metrics.rb           # MODIFIED — ajoute 4 métriques + kwarg phase_per_turn:
├── runner.rb                       # MODIFIED — capture phase_per_turn + guard SKIP_JUDGE
├── report_generator.rb             # MODIFIED — rendu des 4 métriques + bloc "Juge désactivé"
├── judge.rb                        # UNCHANGED
└── student_simulator.rb            # UNCHANGED

spec/services/tutor_simulation/
├── structural_metrics_spec.rb      # MODIFIED — +8 specs (2 par nouvelle métrique)
├── runner_spec.rb                  # MODIFIED — +1 spec (SKIP_JUDGE=1 ne call pas judge)
└── report_generator_spec.rb        # MODIFIED — +2 specs (rendu 4 métriques + skipped judge)
```

**Structure Decision** : Single-project Rails. Pas de nouveau dossier, pas de nouveau
fichier — extension de 3 classes existantes dans `app/services/tutor_simulation/` et
mise à jour de leurs specs. Principe de simplicité V respecté.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A — aucune violation de la constitution. Rien à tracker.

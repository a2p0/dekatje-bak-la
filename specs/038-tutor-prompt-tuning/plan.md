# Implementation Plan: Tuning itératif du prompt tuteur

**Branch**: `038-tutor-prompt-tuning` | **Date**: 2026-04-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/038-tutor-prompt-tuning/spec.md`

## Summary

Amélioration par itérations courtes du prompt système tuteur
(`Tutor::BuildContext`), avec mesure via simulations réduites (2 convs)
entre chaque modification, puis validation finale sur simulation complète
(15 convs). Zéro changement de pipeline, de modèle LLM ou de schéma DB.

Baseline Haiku/Haiku/Sonnet (run `24503225082`, 2026-04-16) : guidage 3.00,
process 2.53, focal 3.40. Cibles : ≥4.0 / ≥3.5 / ≥4.0. Non-régression sur
non-div (4.53 → ≥4.5) et bienveillance (4.00 → ≥4.0).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: `ruby_llm` (tutor + sim), rake (sim driver),
GitHub Actions workflow `tutor_simulation.yml`.
**Storage**: PostgreSQL Neon (aucune migration).
**Testing**:
- Spec existant `spec/services/tutor/build_context_spec.rb` — doit rester
  vert après chaque modification du prompt.
- Validation qualitative via `rake tutor:simulate` + GitHub Actions
  (source de vérité pour les SC).
**Target Platform**: Rails server, CI GitHub Actions (workflow manuel).
**Project Type**: application web fullstack Rails.
**Performance Goals**: pas de régression latence (prompt plus long de
≤500 tokens acceptable).
**Constraints**:
- Budget total tuning ≤ $2 (SC-007).
- Config LLM figée (Haiku 4.5 / Haiku 4.5 / Sonnet 4.6).
- Non-régression sur non-div et bienveillance (FR-004/005).
**Scale/Scope**: 1 fichier modifié (`app/services/tutor/build_context.rb`),
1 spec mis à jour. 3 à 5 itérations de prompt, 1 run complet final.

## Constitution Check

Référence : `.specify/memory/constitution.md` v2.0.0.

| Principe | Statut | Note |
|---|---|---|
| I. Fullstack Rails Hotwire | ✅ | Aucun changement UI/backend hors prompt. |
| II. RGPD | ✅ | Pas de nouvelle donnée collectée. |
| III. Sécurité | ✅ | Aucun changement de flow API/clé. |
| IV. Testing NON-NEGOTIABLE | ⚠️ | Spec unitaire à maintenir vert ; la validation qualitative passe par sim LLM (pas TDD classique — documenté). |
| V. Performance & Simplicité | ✅ | Prompt reste simple et lisible. |
| VI. Workflow NON-NEGOTIABLE | ✅ | Branche `038-tutor-prompt-tuning`, PR à venir, commits par concern, CI. |

**Justification §IV** : pour un prompt, le test unitaire "vérifie que la
chaîne contient X" est faiblement prédictif de la qualité pédagogique.
La vraie métrique est le score juge post-sim. La suite unitaire reste
obligatoire pour non-régression structurelle, mais les SC de la spec
sont validés par la sim GitHub Actions (conforme §IV "CI is the
authoritative test runner").

**Gate** : ✅ pas de violation. Pas de `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/038-tutor-prompt-tuning/
├── plan.md                    # Ce fichier
├── spec.md                    # Spec
├── research.md                # Phase 0 — analyse des transcripts baseline
├── hypotheses.md              # Journal des itérations (clé du process A)
├── data-model.md              # Phase 1 — structure des sections du prompt
├── contracts/
│   └── prompt-shape.md        # Contrat interne : sections obligatoires
├── quickstart.md              # Phase 1 — comment itérer vite
├── checklists/
│   └── requirements.md        # ✅ pass
└── tasks.md                   # Phase 2 — produit par /speckit.tasks
```

### Source Code (repository root)

```text
app/services/tutor/
└── build_context.rb          # MODIFIÉ — SYSTEM_TEMPLATE et SPOTTING_SECTION

spec/services/tutor/
└── build_context_spec.rb     # MODIFIÉ — nouvelles assertions structurelles
```

**Structure Decision** : changement ultra-ciblé, 1 fichier de prod +
1 fichier de spec. Aucune nouvelle classe, aucun nouveau service.

## Phase 0 — Research Output

Voir `research.md`. Sujets couverts :

1. **Analyse des transcripts baseline** (run 24503225082) — identifier
   les patterns de faute concrets par critère faiblement scoré.
2. **Hypothèses de modifications prompt** — 5 H ordonnées par impact
   attendu, chaque H déclinée en instruction concrète à ajouter.
3. **Méthode d'itération** — cycle modif → sim réduite → lecture delta →
   ajuster, avec critère d'arrêt (gain ≥0.3 pt par itération ou stop).
4. **Méthode de sim réduite** — `QUESTIONS=A.1 PROFILES=bon_eleve,
   eleve_en_difficulte TURNS=5` → 2 convs, ~$0.05, ~5 min.

## Phase 1 — Design Output

### Data model

Aucun schéma modifié. Voir `data-model.md` : structure du prompt en
sections nommées (pédagogie, contexte, outils, phase, etc.) avec leurs
responsabilités.

### Contracts

`contracts/prompt-shape.md` : sections MUST présentes dans le prompt
final, invariants structurels (ex. la section `[UTILISATION DES OUTILS]`
doit apparaître après `[CORRECTION CONFIDENTIELLE]`).

### Quickstart

`quickstart.md` — procédure exacte pour :
1. Lancer une sim réduite depuis le terminal (1 commande).
2. Lancer une sim complète via workflow dispatch (1 commande).
3. Lire les deltas entre deux runs (script python one-liner).

### Agent context update

Aucune techno nouvelle. Le script `update-agent-context.sh` sera lancé
pour rester en cohérence speckit mais n'ajoutera probablement rien.

## Complexity Tracking

*Aucune violation — section vide.*

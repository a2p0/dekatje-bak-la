---
description: "Task list — Metrics structurelles déterministes pour le tuning du prompt tuteur"
---

# Tasks: Metrics structurelles déterministes

**Input**: Design documents from `/specs/039-structural-metrics/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅
**Branch**: `039-structural-metrics`

**Tests**: TDD obligatoire (Constitution principe IV — NON-NEGOTIABLE). Tous les specs RSpec sont écrits AVANT le code de production correspondant et DOIVENT échouer avant implémentation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallélisable (fichier différent, aucune dépendance non satisfaite)
- **[Story]**: user story (US1..US4 pour les phases user stories)
- Chemins de fichier absolus depuis la racine du dépôt

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Aucun setup — le projet Rails existe, RSpec et FactoryBot sont déjà configurés, les services à étendre sont déjà instanciés par le Runner. Rien à créer au niveau infra.

*(Phase vide — aucune tâche.)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: préparer les constantes et la capture du `phase_per_turn` utilisées par plusieurs user stories.

**⚠️ CRITICAL**: Les user stories US1, US2, US4 dépendent de la disponibilité de `phase_per_turn` depuis le `Runner`. US3 est indépendant.

- [X] T001 [P] Lire `app/services/tutor_simulation/runner.rb` et confirmer l'emplacement exact d'insertion de la capture `phase_per_turn` (dans `simulate_profile`, après `conversation.reload` à la ligne 127). Aucune modification à ce stade — juste valider le point d'insertion.
- [X] T002 [P] Lire `app/services/tutor_simulation/structural_metrics.rb` et confirmer que la constante `PHASE_RANK` existante est réutilisable. Pas de modification.
- [X] T003 Étendre `TutorSimulation::Runner#simulate_profile` pour capturer `phase_per_turn` in-memory (initialiser avec la phase de départ, pousser `conversation.reload.tutor_state.current_phase` après chaque tour), puis passer ce tableau à `StructuralMetrics.compute(conversation:, phase_per_turn: phase_per_turn)`. Fichier : `app/services/tutor_simulation/runner.rb`.
- [X] T004 Mettre à jour la signature de `TutorSimulation::StructuralMetrics` pour accepter `compute(conversation:, phase_per_turn: nil)` et stocker l'argument dans une ivar `@phase_per_turn`. Rester rétrocompatible : si `phase_per_turn` absent, les métriques dépendantes (US1, US2) retournent `nil`. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T005 [P] Ajouter les constantes privées `ACTION_VERBS`, `DT_DR_REGEX`, `SHORT_MESSAGE_WORD_THRESHOLD` à `TutorSimulation::StructuralMetrics`. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T006 Vérifier que les 6 specs existants dans `spec/services/tutor_simulation/structural_metrics_spec.rb` passent toujours après T004-T005 (rétrocompat SC-004). Commande : `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`.

**Checkpoint**: Foundation prête. `phase_per_turn` circule de Runner vers StructuralMetrics. Aucune nouvelle métrique n'est encore calculée. Les tests existants passent.

---

## Phase 3: User Story 1 — Mesurer H1 (Priority: P1) 🎯 MVP

**Goal**: Exposer `first_turn_with_transition` dans le hash retourné par `StructuralMetrics.compute`.

**Independent Test**: Un spec RSpec avec `phase_per_turn: ["idle", "greeting", "reading"]` retourne `first_turn_with_transition == 1`.

### Tests for User Story 1 (TDD) ⚠️

> Écrire ces tests FIRST, vérifier qu'ils ÉCHOUENT avant implémentation.

- [X] T007 [P] [US1] Ajouter spec "returns 1 when transition happens at turn 1" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C3).
- [X] T008 [P] [US1] Ajouter spec "returns 3 when transition happens at turn 3" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C4).
- [X] T009 [P] [US1] Ajouter spec "returns nil when phase_per_turn is all idle" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C5).
- [X] T010 [P] [US1] Ajouter spec "returns nil when phase_per_turn is not provided (backward compat)" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C2, partie first_turn_with_transition).

### Implementation for User Story 1

- [X] T011 [US1] Implémenter la méthode privée `first_turn_with_transition` dans `TutorSimulation::StructuralMetrics` selon l'algorithme de `data-model.md` § "Calcul de first_turn_with_transition". Ajouter la clé au hash retourné par `compute`. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T012 [US1] Vérifier que T007-T010 passent maintenant : `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`.

**Checkpoint**: `first_turn_with_transition` opérationnelle et testée. H1 peut être mesurée sur une prochaine sim.

---

## Phase 4: User Story 2 — Mesurer H2 (Priority: P1) 🎯 MVP

**Goal**: Exposer `action_verb_ratio_guiding` dans le hash retourné par `StructuralMetrics.compute`.

**Independent Test**: Un spec RSpec avec une conversation de 3 messages en phase guiding dont 2 commencent par "Identifie"/"Calcule" retourne `action_verb_ratio_guiding ≈ 0.67`.

### Tests for User Story 2 (TDD) ⚠️

- [X] T013 [P] [US2] Ajouter spec "returns 0.67 when 2 of 3 guiding messages start with action verb" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C6). Le spec doit créer des messages assistant réels avec un `phase_per_turn` cohérent.
- [X] T014 [P] [US2] Ajouter spec "returns nil when guiding phase is never reached" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C7).
- [X] T015 [P] [US2] Ajouter spec "matches case-insensitive with leading whitespace" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C8 — message "  identifie ..." en minuscule).
- [X] T016 [P] [US2] Ajouter spec "matches verb followed by punctuation (Identifie,)" dans `spec/services/tutor_simulation/structural_metrics_spec.rb`.

### Implementation for User Story 2

- [X] T017 [US2] Implémenter la méthode privée `action_verb_ratio_guiding` dans `TutorSimulation::StructuralMetrics` (split + downcase + strip ponctuation finale, matching contre `ACTION_VERBS`). La correspondance message↔phase se fait via `phase_per_turn` aligné sur les messages assistant. Ajouter la clé au hash retourné. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T018 [US2] Vérifier que T013-T016 passent : `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`.

**Checkpoint**: `action_verb_ratio_guiding` opérationnelle. H1 + H2 sont toutes deux mesurables. MVP livré.

---

## Phase 5: User Story 3 — Guard SKIP_JUDGE (Priority: P1) 🎯 MVP

**Goal**: Permettre `SKIP_JUDGE=1 rake tutor:simulate[...]` sans appel au juge LLM, marker `{ "skipped" => true }` dans les résultats, message lisible dans le rapport.

**Independent Test**: Un spec RSpec sur `TutorSimulation::Runner` avec `ENV["SKIP_JUDGE"] = "1"` vérifie que `fake_judge.evaluate` n'est jamais appelé.

**Dépendance** : indépendant de US1/US2 (touche `runner.rb` + `report_generator.rb`, pas `structural_metrics.rb`).

### Tests for User Story 3 (TDD) ⚠️

- [X] T019 [P] [US3] Ajouter spec "does not call judge when SKIP_JUDGE=1" dans `spec/services/tutor_simulation/runner_spec.rb` avec `instance_double(TutorSimulation::Judge)` + `expect(fake_judge).not_to receive(:evaluate)` (contract R1).
- [X] T020 [P] [US3] Ajouter spec "marks evaluation as skipped in profile result" dans `spec/services/tutor_simulation/runner_spec.rb` (contract R2).
- [X] T021 [P] [US3] Ajouter spec "calls judge normally when SKIP_JUDGE is absent" dans `spec/services/tutor_simulation/runner_spec.rb` (contract R3).
- [X] T022 [P] [US3] Ajouter spec "treats SKIP_JUDGE=0 as absent" dans `spec/services/tutor_simulation/runner_spec.rb` (contract R4).
- [X] T023 [P] [US3] Ajouter spec "renders 'Juge désactivé' when evaluation['skipped'] is true" dans `spec/services/tutor_simulation/report_generator_spec.rb` (contract G2).

### Implementation for User Story 3

- [X] T024 [US3] Implémenter le guard `SKIP_JUDGE` dans `TutorSimulation::Runner#simulate_profile` : `evaluation = ENV["SKIP_JUDGE"] == "1" ? { "skipped" => true } : judge_transcript(...)`. Fichier : `app/services/tutor_simulation/runner.rb`.
- [X] T025 [US3] Étendre `TutorSimulation::ReportGenerator#render_qualitative` pour traiter le cas `evaluation&.dig("skipped") == true` AVANT le cas `"error"` et le cas tableau de scores. Rendre un message markdown lisible. Fichier : `app/services/tutor_simulation/report_generator.rb`.
- [X] T026 [US3] Vérifier que T019-T023 passent : `bundle exec rspec spec/services/tutor_simulation/runner_spec.rb spec/services/tutor_simulation/report_generator_spec.rb`.

**Checkpoint**: SKIP_JUDGE opérationnel. Budget sim divisé par ~2 lors des itérations sans juge.

---

## Phase 6: User Story 4 — Metrics bonus (Priority: P2)

**Goal**: Exposer `dt_dr_leak_count_non_spotting` et `short_message_ratio` dans le hash retourné.

**Independent Test**: Specs RSpec sur conversations de test avec leaks DT et messages longs.

### Tests for User Story 4 (TDD) ⚠️

- [X] T027 [P] [US4] Ajouter spec "counts 2 DT1/DT2 leaks in guiding phase" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C9).
- [X] T028 [P] [US4] Ajouter spec "does not count DT leaks during spotting" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C10).
- [X] T029 [P] [US4] Ajouter spec "returns 0.80 when 4 of 5 assistant messages are ≤ 60 words" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C11).
- [X] T030 [P] [US4] Ajouter spec "returns 0.0 short_message_ratio when no assistant messages exist" dans `spec/services/tutor_simulation/structural_metrics_spec.rb` (contract C12, sentinelle I5).

### Implementation for User Story 4

- [X] T031 [US4] Implémenter la méthode privée `dt_dr_leak_count_non_spotting` dans `TutorSimulation::StructuralMetrics` (itère sur `assistant_messages` zippés avec `phase_per_turn`, compte ceux dont la phase n'est pas `spotting` ET dont le contenu matche `DT_DR_REGEX`). Si `phase_per_turn` absent, retourner le compteur sur **tous** les messages (compte les leaks potentiels sans discrimination). Ajouter la clé au hash. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T032 [US4] Implémenter la méthode privée `short_message_ratio` dans `TutorSimulation::StructuralMetrics` (ratio des messages assistant dont `split(/\s+/).size <= SHORT_MESSAGE_WORD_THRESHOLD`). Sentinelle `0.0` si aucun message. Ajouter la clé au hash. Fichier : `app/services/tutor_simulation/structural_metrics.rb`.
- [X] T033 [US4] Vérifier que T027-T030 passent : `bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb`.

**Checkpoint**: Les 4 nouvelles métriques sont exposées dans `structural_metrics` et sérialisées dans `raw.json`.

---

## Phase 7: Rendu Markdown (cross-cutting)

**Purpose**: Les 4 nouvelles métriques doivent apparaître dans `report.md` (par profil + résumé global). Sans cette phase, les métriques sont dans `raw.json` mais invisibles à la lecture humaine.

- [X] T034 [P] Ajouter spec "render_structural includes the 4 new metrics" dans `spec/services/tutor_simulation/report_generator_spec.rb` (contract G1).
- [X] T035 [P] Ajouter spec "global_summary averages non-nil first_turn_with_transition" dans `spec/services/tutor_simulation/report_generator_spec.rb` (contract G3).
- [X] T036 Étendre `TutorSimulation::ReportGenerator#render_structural` avec 4 lignes de tableau pour les nouvelles métriques (afficher "—" pour les `nil`). Fichier : `app/services/tutor_simulation/report_generator.rb`.
- [X] T037 Étendre `TutorSimulation::ReportGenerator#global_summary` pour agréger les 4 nouvelles métriques (moyenne des non-nil pour ratios, somme pour leaks). Fichier : `app/services/tutor_simulation/report_generator.rb`.
- [X] T038 Vérifier que T034-T035 passent : `bundle exec rspec spec/services/tutor_simulation/report_generator_spec.rb`.

**Checkpoint**: Le rapport Markdown est complet. Lecture humaine possible des 4 nouvelles métriques.

---

## Phase 8: Polish & Validation end-to-end

**Purpose**: valider l'intégration complète, lancer une sim réelle n=2, documenter.

- [X] T039 Exécuter la suite complète : `bundle exec rspec spec/services/tutor_simulation/` et confirmer 0 failure. → **42 examples, 0 failures**.
- [X] T040 Rubocop sur les 3 fichiers modifiés : `bundle exec rubocop app/services/tutor_simulation/`. Fixer les warnings éventuels. → **5 files, no offenses**.
- [ ] T041 Lancer une sim réelle n=2 avec `SKIP_JUDGE=1` pour validation end-to-end (SC-006) : `SKIP_JUDGE=1 OPENROUTER_API_KEY=... bundle exec rake 'tutor:simulate[1]' TURNS=3 PROFILES=bon_eleve QUESTIONS=1.1`. Vérifier que `raw.json` contient les 4 nouvelles métriques et `evaluation: { "skipped" => true }`. → **à exécuter manuellement post-merge** (requires OPENROUTER_API_KEY + seeded subject).
- [ ] T042 Vérifier visuellement que `report.md` affiche correctement les 4 métriques par profil + dans le résumé global, et le bloc "Juge désactivé (SKIP_JUDGE=1)". → **à faire après T041**.
- [X] T043 Ajouter une section "Méthodologie D — metrics structurelles" dans `specs/038-tutor-prompt-tuning/hypotheses.md` pointant vers `specs/039-structural-metrics/spec.md` pour la reprise du tuning H1/H2.
- [ ] T044 Commit + push + créer la PR vers `main` (ou vers `038-tutor-prompt-tuning` si on préfère empiler). Titre PR : `feat(tutor-sim): add structural metrics for H1/H2 hypothesis testing + SKIP_JUDGE guard`.

**Checkpoint final**: Feature mergeable. CI verte. PR prête à la review.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup** : vide.
- **Phase 2 Foundational** : doit être complète avant toute user story.
- **Phase 3 US1 (H1)** : dépend de Phase 2 (T003 capture `phase_per_turn`, T004 accepte l'arg).
- **Phase 4 US2 (H2)** : dépend de Phase 2. Peut s'exécuter en parallèle de Phase 3 (mêmes fichiers touchés mais régions indépendantes — sérialiser si conflit de diff).
- **Phase 5 US3 (SKIP_JUDGE)** : **indépendant** de Phase 2/3/4 (touche `runner.rb` guard + `report_generator.rb` rendu qualitatif, pas `structural_metrics.rb`). Peut démarrer immédiatement après T001.
- **Phase 6 US4 (leaks + short)** : dépend de Phase 2 (a besoin de `phase_per_turn` pour T031). Peut tourner en parallèle de Phase 3/4.
- **Phase 7 Rendu Markdown** : dépend des Phases 3, 4, 6 (a besoin que les 4 clés existent dans le hash).
- **Phase 8 Polish** : dépend de toutes les précédentes.

### Within Each User Story (TDD)

- Tests AVANT implémentation (constitution IV).
- Verify fail → write code → verify pass.

### Parallel Opportunities

- **T001 [P] + T002 [P]** : lectures indépendantes, parallèles.
- **T005 [P]** : ajout de constantes, indépendant de T003/T004.
- **T007-T010 [P] [US1]** : 4 specs dans le même fichier mais éditables en un seul commit — peuvent être rédigés en parallèle mentalement, commit groupé.
- **T013-T016 [P] [US2]** : idem.
- **T019-T023 [P] [US3]** : idem (dont T023 dans report_generator_spec.rb, indépendant).
- **T027-T030 [P] [US4]** : idem.
- **T034-T035 [P]** : specs de rendu, parallèles.
- **US3 (Phase 5) entière** : peut tourner en parallèle complet de US1/US2/US4 car touche des fichiers différents.

---

## Parallel Example: User Story 1

```bash
# Les 4 specs US1 peuvent être rédigés en un seul "coup" mental
# (même fichier, mais cas disjoints) :
Task: "Spec 'returns 1 when transition at turn 1' in structural_metrics_spec.rb"
Task: "Spec 'returns 3 when transition at turn 3' in structural_metrics_spec.rb"
Task: "Spec 'returns nil when all idle' in structural_metrics_spec.rb"
Task: "Spec 'returns nil when phase_per_turn absent' in structural_metrics_spec.rb"

# Puis implémentation (sérielle sur un même fichier) :
Task: "Implement first_turn_with_transition method"
```

---

## Implementation Strategy

### MVP First (US1 + US2 + US3)

1. Phase 2 Foundational (T001-T006) — pose l'infra.
2. Phase 3 US1 + Phase 4 US2 (en série ou parallèle selon confort) — livre les 2 métriques H1/H2 testées.
3. Phase 5 US3 (SKIP_JUDGE) — livre l'économie budgétaire.
4. **STOP et VALIDER** : un run sim n=2 avec SKIP_JUDGE doit produire les 2 nouvelles métriques (H1, H2) sans appel juge.
5. Optionnel : Phase 6 US4 pour les métriques bonus.
6. Phase 7 Rendu Markdown (obligatoire pour lisibilité humaine).
7. Phase 8 Polish + PR.

### Incremental Delivery

- **Commit 1** : T003-T006 — foundation Runner + signature (1 commit `refactor(tutor-sim): add phase_per_turn capture and StructuralMetrics kwarg`).
- **Commit 2** : T007-T012 — US1 H1 metric (`feat(tutor-sim): measure first_turn_with_transition for H1`).
- **Commit 3** : T013-T018 — US2 H2 metric (`feat(tutor-sim): measure action_verb_ratio_guiding for H2`).
- **Commit 4** : T019-T026 — US3 SKIP_JUDGE (`feat(tutor-sim): add SKIP_JUDGE guard to Runner`).
- **Commit 5** : T027-T033 — US4 leaks + short (`feat(tutor-sim): measure dt_dr leaks and short message ratio`).
- **Commit 6** : T034-T038 — Markdown rendering (`feat(tutor-sim): render new structural metrics in report.md`).
- **Commit 7** : T039-T044 — Polish + doc (`docs(038): link to 039 structural metrics methodology`).

---

## Notes

- [P] = fichier différent ou région disjointe d'un même fichier.
- TDD strict : chaque spec écrit AVANT le code, vérifier qu'il échoue.
- Commit après chaque User Story complète (ou plus granulaire si bench de lisibilité).
- Aucune migration, aucun nouveau fichier — extension de 3 classes existantes + leurs specs.
- Run `bundle exec rspec spec/services/tutor_simulation/` doit rester green après chaque commit.
- Ne PAS toucher au prompt tuteur (`Tutor::BuildContext`) — hors scope de ce feature.

---
description: "Task list — Câblage des outils du tuteur au LLM"
---

# Tasks: Câblage des outils du tuteur au LLM

**Input**: Design documents from `/specs/037-tutor-wire-tools/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/tools.md, quickstart.md

**Tests**: TDD activé (constitution §IV NON-NEGOTIABLE). Specs RSpec écrits **avant** le code, doivent échouer avant implémentation, passer après.

**Organization**: Les 4 user stories du spec sont interdépendantes en pratique (le LLM ne peut pas appeler `update_learner_model` sans que le câblage général fonctionne), mais chaque US reste **testable indépendamment** via des specs unitaires ciblant chaque outil + spec du pipeline avec un chunk mocké pour cet outil précis.

## Format: `[ID] [P?] [Story] Description`

- **[P]** : exécutable en parallèle (fichier distinct, pas de dépendance)
- **[Story]** : US1, US2, US3, US4
- Chemins absolus depuis la racine du projet Rails

## Path Conventions

Rails fullstack monolithe (constitution §I) :
- Services tuteur : `app/services/tutor/`
- Specs services : `spec/services/tutor/`
- Support RSpec : `spec/support/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose** : vérifications préalables — pas de dépendance à installer, pas de migration.

- [ ] T001 Vérifier que `ruby_llm` est déclaré dans `Gemfile` et que `bundle install` passe (baseline CI verte sur `main`) — commande : `bundle check` à la racine
- [ ] T002 Créer le dossier `app/services/tutor/tools/` (vide, sera peuplé par les US)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose** : infrastructure partagée par les 4 user stories — le fake LLM de test et l'adaptation de `ParseToolCalls` pour la shape Hash-keyed doivent être en place avant toute spec d'US.

**⚠️ CRITICAL** : bloque toute US. Doit être validé par `bundle exec rspec spec/services/tutor/parse_tool_calls_spec.rb spec/support/fake_ruby_llm.rb` (red → green local) avant de commencer les US.

- [ ] T003 Étendre `spec/support/fake_ruby_llm.rb` pour stubber `RubyLLM::Chat#with_tool` et `#with_tools` (no-op renvoyant `nil` sur varargs + kwargs). Doit rester rétro-compatible avec tous les specs existants.
- [ ] T004 [P] Ajouter une spec à `spec/services/tutor/parse_tool_calls_spec.rb` couvrant le cas où `tool_calls` est un `Hash` keyé par id (shape réelle de `ruby_llm` en streaming) — doit échouer avant T005.
- [ ] T005 Adapter `app/services/tutor/call_llm.rb` ligne ~41 pour extraire les **valeurs** du Hash `chunk.tool_calls` (ex. `Array(chunk.tool_calls.respond_to?(:values) ? chunk.tool_calls.values : chunk.tool_calls)`) afin que `ParseToolCalls` reçoive une Array plate. Spec T004 doit passer.
- [ ] T005a [P] Ajouter une spec dans `spec/services/tutor/apply_tool_calls_spec.rb` : transition `idle → greeting` doit être **autorisée**, transition `idle → reading` doit rester **refusée** (FR-009). Doit échouer avant T005b.
- [ ] T005b Modifier `app/services/tutor/apply_tool_calls.rb:5-12` pour ajouter `"idle" => %w[greeting]` dans `TRANSITION_MATRIX`. Spec T005a passe. FR-009 satisfait.

**Checkpoint** : fondations en place — les US peuvent démarrer en parallèle. Sans T005b, les US1-4 seraient testables mais non fonctionnelles en bout de chaîne (première transition refusée).

---

## Phase 3: User Story 1 — Workflow phases (Priority: P1) 🎯 MVP

**Goal** : le LLM peut effectivement invoquer `transition` et faire progresser `TutorState.current_phase` selon la matrice autorisée.

**Independent Test** : spec unitaire `TransitionTool` + spec pipeline `ProcessMessage` avec chunk mocké contenant un `tool_call transition {phase: "reading"}` → `TutorState#current_phase` passe à `reading`.

### Tests for User Story 1 (TDD — ÉCRIRE AVANT LE CODE)

> Les specs T006-T008 doivent ÉCHOUER avant T009-T011.

- [ ] T006 [P] [US1] Créer `spec/services/tutor/tools/transition_tool_spec.rb` : vérifier `description`, `param :phase` (string, required), `param :question_id` (integer, optional), `#execute(phase:, question_id: nil)` renvoie `{ok: true, recorded: {phase:, question_id:}}`.
- [ ] T007 [P] [US1] Mettre à jour `spec/services/tutor/call_llm_spec.rb` : `expect_any_instance_of(RubyLLM::Chat).to receive(:with_tools).with(Tutor::Tools::TransitionTool, Tutor::Tools::UpdateLearnerModelTool, Tutor::Tools::RequestHintTool, Tutor::Tools::EvaluateSpottingTool)`.
- [ ] T008 [P] [US1] Mettre à jour `spec/services/tutor/build_context_spec.rb` : vérifier que la nouvelle section `[UTILISATION DES OUTILS — OBLIGATOIRE]` est bien présente dans le `system_prompt` retourné.

### Implementation for User Story 1

- [ ] T009 [P] [US1] Créer `app/services/tutor/tools/transition_tool.rb` (sous-classe `RubyLLM::Tool`, DSL conforme contrats/tools.md §1, `#execute` renvoie `{ok: true, recorded: {phase:, question_id:}}`). Spec T006 passe.
- [ ] T010 [US1] Modifier `app/services/tutor/call_llm.rb` : ajouter `chat.with_tools(Tutor::Tools::TransitionTool, Tutor::Tools::UpdateLearnerModelTool, Tutor::Tools::RequestHintTool, Tutor::Tools::EvaluateSpottingTool)` après `chat.with_instructions(@system_prompt)` et avant `chat.ask(...)`. Spec T007 passe (les 4 classes doivent exister en coquilles vides — voir US2-4).
- [ ] T011 [US1] Modifier `app/services/tutor/build_context.rb` : ajouter la constante `TOOLS_SECTION` (texte défini dans research.md §Décision 4) et l'inclure dans le `system_prompt` après le bloc `[CORRECTION CONFIDENTIELLE]`. Spec T008 passe.

**Checkpoint** : `TransitionTool` câblé et fonctionnel. Le pipeline `ProcessMessage` peut faire progresser les phases via un mock de `tool_calls`.

---

## Phase 4: User Story 2 — Learner model (Priority: P2)

**Goal** : le LLM peut invoquer `update_learner_model` pour ajouter des concepts maîtrisés / à revoir et ajuster le découragement.

**Independent Test** : spec unitaire `UpdateLearnerModelTool` + pipeline qui vérifie qu'après un tool_call `update_learner_model {concept_mastered: "X"}`, `TutorState#concepts_mastered` contient `"X"` sans doublon.

### Tests for User Story 2

- [ ] T012 [P] [US2] Créer `spec/services/tutor/tools/update_learner_model_tool_spec.rb` : vérifier DSL (3 params optionnels typés), `#execute(**args)` renvoie accusé.

### Implementation for User Story 2

- [ ] T013 [P] [US2] Créer `app/services/tutor/tools/update_learner_model_tool.rb` (DSL conforme contrats/tools.md §2). Spec T012 passe.

**Checkpoint** : `UpdateLearnerModelTool` câblé ; le LLM peut enrichir le modèle de l'élève.

---

## Phase 5: User Story 3 — Indices progressifs (Priority: P2)

**Goal** : le LLM peut invoquer `request_hint` pour demander un indice gradué ; les garde-fous serveur (progression monotone, max 5) restent actifs.

**Independent Test** : spec unitaire `RequestHintTool` + le spec existant `apply_tool_calls_spec.rb` (déjà green) continue de refuser les sauts de niveau.

### Tests for User Story 3

- [ ] T014 [P] [US3] Créer `spec/services/tutor/tools/request_hint_tool_spec.rb` : vérifier DSL (`level: integer, required`), `#execute(level:)` renvoie accusé.

### Implementation for User Story 3

- [ ] T015 [P] [US3] Créer `app/services/tutor/tools/request_hint_tool.rb` (DSL conforme contrats/tools.md §3). Spec T014 passe.

**Checkpoint** : `RequestHintTool` câblé.

---

## Phase 6: User Story 4 — Évaluation du repérage (Priority: P2)

**Goal** : le LLM peut invoquer `evaluate_spotting` pour conclure la phase `spotting` avec un outcome parmi `success`/`failure`/`forced_reveal`.

**Independent Test** : spec unitaire `EvaluateSpottingTool` + spec d'intégration `apply_tool_calls_spec.rb` (déjà green) continue de déclencher la transition `spotting → guiding` sur `success`/`forced_reveal`.

### Tests for User Story 4

- [ ] T016 [P] [US4] Créer `spec/services/tutor/tools/evaluate_spotting_tool_spec.rb` : vérifier DSL (`outcome: string, required`, enum documenté), `#execute(outcome:)` renvoie accusé.

### Implementation for User Story 4

- [ ] T017 [P] [US4] Créer `app/services/tutor/tools/evaluate_spotting_tool.rb` (DSL conforme contrats/tools.md §4). Spec T016 passe.

**Checkpoint** : `EvaluateSpottingTool` câblé. Les 4 outils sont opérationnels.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose** : intégration, vérification globale, préparation PR.

- [ ] T018 Ajouter dans `spec/services/tutor/process_message_spec.rb` deux scénarios d'intégration : (a) "LLM appelle `transition` depuis idle via tool_calls → phase avance à `greeting`" (chunk mocké avec `tool_calls: [Struct(name: "transition", arguments: {"phase" => "greeting"})]`) ; (b) "streaming mixte : chunks texte + chunk tool_calls → broadcast par chunk préservé" (couvre FR-008).
- [ ] T019 [P] Lancer localement `bundle exec rspec spec/services/tutor/ spec/support/fake_ruby_llm.rb` en best-effort (constitution §IV : CI = autorité, local = workaround). Si échec sur `student_tutor_full_flow_spec.rb` ou `student_tutor_spotting_spec.rb`, noter pour correction mais ne pas bloquer — T023 CI tranche.
- [ ] T020 [P] Vérifier `bundle exec rubocop` (0 offense sur les fichiers modifiés).
- [ ] T021 Dérouler `specs/037-tutor-wire-tools/quickstart.md` §1-§2 (vérification locale rapide). Documenter tout écart dans `specs/037-tutor-wire-tools/NOTES.md` si besoin.
- [ ] T022 Commit(s) conventionnels séparés par concern (constitution §VI.6) : `feat(tutor): define 4 RubyLLM::Tool classes`, `feat(tutor): wire tools to chat in CallLlm`, `feat(tutor): add mandatory tool-usage instructions to system prompt`, `test(tutor): extend FakeRubyLlm to stub with_tools` (adapter selon regroupement réel).
- [ ] T023 Push branche `037-tutor-wire-tools` et ouvrir PR vers `main`. Attendre CI verte avant tout merge (constitution §IV.CI, §VI.5).
- [ ] T024 Post-merge : déclencher manuellement le workflow GitHub Actions `tutor_simulation.yml` et comparer les scores au baseline 2026-04-15 (SC-001 à SC-004). Consigner le résultat dans la mémoire projet (update `project_tutor_tools_not_wired.md` → statut RÉSOLU ou follow-up).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance.
- **Foundational (Phase 2)** : dépend de Setup. **Bloque toutes les US**. Inclut T005b (fix `idle → greeting`) sans lequel les US1-4 seraient inefficaces end-to-end.
- **Phase 3 (US1)** : dépend de Foundational (notamment T005b). T010 (câblage `with_tools`) référence les 4 classes → nécessite que les coquilles existent (T009, T013, T015, T017 peuvent être créées tôt).
- **Phases 4-6 (US2/US3/US4)** : dépendent de Foundational. Indépendantes entre elles.
- **Polish (Phase 7)** : dépend de toutes les US terminées.

### User Story Dependencies

- **US1 (P1 MVP)** : seule l'US1 est nécessaire pour démontrer le bon câblage end-to-end (transition). Livrable MVP.
- **US2, US3, US4 (P2)** : indépendantes l'une de l'autre, chacune ajoute la couverture d'un outil.
- Pragmatique : **les 4 US seront livrées dans la même PR** car le câblage T010 exige les 4 classes (sinon `NameError`). Découpage conservé pour la traçabilité et les checkpoints de test.

### Within Each User Story

- Tests [Px] avant implémentation (TDD — constitution §IV).
- Chaque US expose un fichier tool + un bloc de spec unitaire → pas de conflit de fichier.

### Parallel Opportunities

- **[P] cross-US** : T009, T013, T015, T017 (création des 4 classes tools) peuvent être dispatcheés en parallèle — fichiers distincts.
- **[P] specs unitaires** : T006, T012, T014, T016 peuvent s'écrire en parallèle.
- T007 et T008 (mises à jour des specs `call_llm` et `build_context`) sont indépendantes et [P].
- T019 et T020 (RSpec et Rubocop final) sont [P].

---

## Parallel Example — Création des 4 tools

```text
# Dispatch en parallèle (4 agents Frontend/Backend Dev) :
Task T009: "Créer app/services/tutor/tools/transition_tool.rb selon contrats/tools.md §1"
Task T013: "Créer app/services/tutor/tools/update_learner_model_tool.rb selon contrats/tools.md §2"
Task T015: "Créer app/services/tutor/tools/request_hint_tool.rb selon contrats/tools.md §3"
Task T017: "Créer app/services/tutor/tools/evaluate_spotting_tool.rb selon contrats/tools.md §4"
```

---

## Implementation Strategy

### MVP First (US1 Only — découplé)

Possible en théorie mais **non recommandé** car T010 (`with_tools(4 classes)`) casserait en `NameError`. Alternative MVP :
- Livrer un premier commit avec **les 4 coquilles** + câblage (`with_tools`), puis les specs TDD une par US dans des commits distincts. Le MVP fonctionnel reste la capacité de `transition` (US1).

### Incremental Delivery

1. Phase 1 + 2 (Setup + Foundational) → CI verte sur refactor ParseToolCalls seul.
2. Phase 3 (US1) → MVP : le tuteur transite effectivement les phases.
3. Phases 4-6 en parallèle → couverture learner model + hints + spotting.
4. Phase 7 → QA locale + PR + CI + sim post-merge.

### Parallel Team Strategy

Solo dev : enchaînement séquentiel par phase, en exploitant les [P] pour lancer `rspec` ciblé en arrière-plan.
Si dispatch subagents : Phase 3 (un agent par tool) + Phase 7 (agents rubocop/rspec en [P]).

---

## Notes

- TDD obligatoire (constitution §IV) : specs d'abord, échec visible, puis code.
- Un concern par commit (constitution §VI.6, mémoire `feedback_commit_scope.md`).
- Conventional Commits (CLAUDE.md §Conventions Git).
- Tous les `#execute` renvoient un accusé léger **sans mutation** (invariant I1/I2 de data-model.md).
- Aucune migration DB. Aucun changement de provider ni de clé API.
- SC-001 à SC-004 **ne se valident qu'après merge** via la sim (T024) — ne pas bloquer la PR sur ces critères.

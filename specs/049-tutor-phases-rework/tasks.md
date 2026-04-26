# Tasks: Refonte phases tuteur + answer_type (049)

**Input**: Design documents from `/specs/049-tutor-phases-rework/`
**Prerequisites**: plan.md ✅, spec.md ✅, data-model.md ✅

**TDD**: Constitution IV impose TDD mandatory — specs écrites et en échec AVANT le code de production.

---

## Phase 1: Setup (Branche + migration)

**Purpose**: Préparer la migration enum et l'infrastructure de test

- [x] T001 Créer la migration `rename_answer_types` dans `db/migrate/` — séquence SQL exacte dans `up` :
  1. `UPDATE questions SET answer_type = 3 WHERE answer_type = 4` (completion → representation, même int que dr_reference)
  2. `UPDATE questions SET answer_type = 4 WHERE answer_type = 5` (choice → qcm)
  - Les types `text`(0), `calculation`(1), `argumentation`(2), `dr_reference`(3) conservent leur int — pas d'UPDATE nécessaire
  - `down` inverse : `UPDATE questions SET answer_type = 5 WHERE answer_type = 4`, puis `UPDATE questions SET answer_type = 4 WHERE answer_type = 3 AND answer_type NOT IN (SELECT ...)` — ou plus simplement : conserver un snapshot des anciens ints dans un commentaire de migration
  - Migration réversible avec `down`
- [x] T002 Mettre à jour le prompt d'extraction PDF dans `app/services/build_extraction_prompt.rb` pour produire les nouveaux libellés (`identification`, `calcul`, `justification`, `representation`, `qcm`, `verification`, `conclusion`) à la place des anciens

---

## Phase 2: Foundational (Modèles de données — bloquant)

**Purpose**: `TutorState`, `QuestionState`, et `Question#answer_type` mis à jour — bloque toutes les user stories

⚠️ **CRITIQUE** : Aucune user story ne peut démarrer avant cette phase

- [x] T003 Écrire les specs `spec/models/tutor_state_spec.rb` — tester : nouveau champ `last_activity_at` (défaut nil), `QuestionState#phase` (défaut `"enonce"`), compatibilité ascendante (désérialisation JSONB sans `phase` ni `last_activity_at`)
- [x] T004 Mettre à jour `app/models/tutor_state.rb` : ajouter `last_activity_at` à `TutorState`, ajouter `phase` à `QuestionState`, valeurs par défaut compatibles, `TutorState.default` mis à jour — faire passer T003
- [x] T005 [P] Écrire les specs `spec/models/question_spec.rb` — tester : les 7 nouvelles valeurs d'enum (`identification`, `calcul`, `justification`, `representation`, `qcm`, `verification`, `conclusion`), absence des anciennes valeurs
- [x] T006 [P] Mettre à jour `app/models/question.rb` : remplacer l'enum `answer_type` par les 7 nouveaux types (ints 0-6), faire passer T005
- [x] T007 Mettre à jour `app/models/types/tutor_state_type.rb` : assurer la désérialisation JSONB avec les nouveaux champs (`phase` dans `QuestionState`, `last_activity_at` dans `TutorState`) et valeurs par défaut

**Checkpoint** : `bundle exec rspec spec/models/tutor_state_spec.rb spec/models/question_spec.rb` vert

---

## Phase 3: User Story 1 — Phases adaptées au type de question (P1) 🎯 MVP

**Goal**: Le tuteur adapte son parcours de phases selon le type de question (QCM skip spotting, etc.)

**Independent Test**: Ouvrir le tuteur sur une question `calcul` → phases `enonce→spotting_type→spotting_data→guiding` ; sur une question `qcm` → `enonce→guiding` direct

### Specs (TDD — écrire avant le code)

- [x] T008 Écrire `spec/services/tutor/apply_tool_calls_spec.rb` — tester :
  - Nouvelle `TRANSITION_MATRIX` complète (9 états)
  - Transition `enonce→guiding` valide (skip spotting pour qcm)
  - Transition `enonce→spotting_type` valide (autres types)
  - Transition `spotting_type→guiding` valide (skip spotting_data si pas DT/DR)
  - Transition `spotting_type→spotting_data` valide
  - Transition interdite `enonce→reading` → erreur
  - `guiding→enonce` valide (passage question suivante)
  - `validating→ended` valide (skip feedback)
  - `QUESTION_REQUIRED_PHASES` mis à jour (inclure `enonce`, `spotting_type`, `spotting_data`)

- [x] T009 [P] Écrire `spec/services/tutor/build_context_spec.rb` — tester :
  - Section `[PHASE SPOTTING_TYPE]` présente dans le prompt quand `current_phase == "spotting_type"`
  - Section `[PHASE SPOTTING_DATA]` présente quand `current_phase == "spotting_data"`
  - Section `[PHASE SPOTTING_TYPE]` absente pour `qcm` (skip garanti par prompt)
  - Style de guidage `calcul` présent dans le prompt quand `answer_type == "calcul"` et `current_phase == "guiding"`
  - Style de guidage `qcm` (élimination distracteurs) présent quand `answer_type == "qcm"`

### Implémentation

- [x] T010 Mettre à jour `app/services/tutor/apply_tool_calls.rb` :
  - `ALLOWED_PHASES` : 9 états complets
  - `TRANSITION_MATRIX` : nouvelle matrice (voir plan.md R-003)
  - `QUESTION_REQUIRED_PHASES` : inclure `enonce`, `spotting_type`, `spotting_data`, `guiding`, `validating`, `feedback`, `ended`
  - Faire passer T008

- [x] T011 Mettre à jour `app/services/tutor/tools/transition_tool.rb` :
  - `description` mise à jour avec les nouvelles transitions autorisées
  - `param :phase` : liste des phases valides mise à jour

- [x] T012 Mettre à jour `app/services/tutor/build_context.rb` :
  - Ajouter `SPOTTING_TYPE_SECTION` (prompt spécifique phase `spotting_type`)
  - Ajouter `SPOTTING_DATA_SECTION` (prompt spécifique phase `spotting_data`)
  - Ajouter section `[STYLE DE GUIDAGE]` dans `SYSTEM_TEMPLATE` selon `answer_type` (styles : localisation DT pour `identification`, étapes numériques pour `calcul`, élimination distracteurs pour `qcm`, reformulation conceptuelle pour `justification`, accompagnement tracé pour `representation`, méthode de contrôle pour `verification`, synthèse guidée pour `conclusion`)
  - Injecter les sections conditionnellement selon `current_phase`
  - Injecter les règles de skip dans le prompt (`[RÈGLES DE PROGRESSION]`)
  - Faire passer T009

- [x] T013 Mettre à jour `app/services/tutor/tools/evaluate_spotting_tool.rb` et `apply_tool_calls.rb#apply_evaluate_spotting` : adapter à `spotting_type` et `spotting_data` séparément via param `step: "type" | "data"` (un seul outil, deux étapes — évite la prolifération d'outils LLM)

- [ ] T013b [US1] Couvrir FR-013 — réponse anticipée sans régression de phase :
  - Ajouter spec dans `spec/services/tutor/build_context_spec.rb` : quand `current_phase == "enonce"` et le message élève contient une réponse complète, le prompt contient une section `[RÉPONSE ANTICIPÉE]` indiquant au LLM de ne pas régresser vers `enonce`
  - Ajouter section `ANTICIPATED_ANSWER_SECTION` dans `app/services/tutor/build_context.rb` : détectée si `current_phase` est `enonce` ou `spotting_type`, injectée conditionnellement
  - Le LLM peut transitionner vers `guiding` directement depuis `enonce` si l'élève anticipe — déjà autorisé par la TRANSITION_MATRIX (`enonce → guiding`)

**Checkpoint** : `bundle exec rspec spec/services/tutor/apply_tool_calls_spec.rb spec/services/tutor/build_context_spec.rb` vert

---

## Phase 4: User Story 2 — Reprise à la phase sauvegardée (P2)

**Goal**: Un élève qui revient sur une question interrompue reprend exactement à la phase sauvegardée

**Independent Test**: Interrompre en `guiding`, revenir → phase `guiding` restaurée, pas de régression vers `enonce`

### Specs (TDD)

- [x] T014 Écrire `spec/services/tutor/process_message_spec.rb` (ou compléter) — tester :
  - Reprise à `question_states[question_id].phase` si présent
  - Démarrage à `enonce` si `question_states[question_id]` absent
  - Mise à jour de `last_activity_at` à chaque message
  - Phase `ended` : pas de cycle repris (correction affichée)

- [ ] T015 [P] Écrire specs feature `spec/features/student_tutor_full_flow_spec.rb` — mettre à jour les scénarios existants avec les nouvelles phases, ajouter scénario reprise (`guiding` → déconnexion → retour → `guiding`)

### Implémentation

- [x] T016 Mettre à jour `app/services/tutor/process_message.rb` (ou équivalent d'entrée) :
  - Résoudre la phase courante depuis `question_states[current_question_id.to_s]&.phase` avant de construire le contexte
  - Si `question_states` absent pour cette question → initialiser à `phase: "enonce"`
  - Mettre à jour `last_activity_at` dans `TutorState` à chaque appel via `UpdateTutorState`

- [x] T017 Mettre à jour `app/services/tutor/apply_tool_calls.rb#apply_transition` :
  - Lors d'une transition, persister la nouvelle phase dans `question_states[question_id].phase` (en plus de `current_phase`)
  - Synchroniser `current_phase` (global) et `question_states[qid].phase` (par question)

**Checkpoint** : `bundle exec rspec spec/services/tutor/process_message_spec.rb spec/features/student_tutor_full_flow_spec.rb` vert

---

## Phase 5: User Story 3 — Greeting unique, re-greeting conditionnel (P3)

**Goal**: Greeting émis une seule fois par sujet ; re-greeting si reconnexion ou > 12h d'inactivité

**Independent Test**: Naviguer entre 3 questions → 1 seul greeting ; simuler reconnexion → re-greeting

### Specs (TDD)

- [x] T018 Écrire `spec/services/tutor/build_welcome_message_spec.rb` (ou compléter) — tester :
  - `welcome_sent == false` → greeting émis, `welcome_sent` devient `true`
  - `welcome_sent == true` ET `last_activity_at` < 12h → pas de greeting
  - `welcome_sent == true` ET `last_activity_at` > 12h → re-greeting
  - Nouvelle `StudentSession` (reconnexion) → re-greeting

- [ ] T019 [P] Compléter `spec/features/student_tutor_activation_spec.rb` : ajouter scénario navigation inter-questions (pas de double greeting) et scénario reconnexion (re-greeting)

### Implémentation

- [x] T020 Mettre à jour `app/services/tutor/build_welcome_message.rb` :
  - Condition re-greeting : `!welcome_sent` OU `last_activity_at.nil?` OU `Time.current - last_activity_at.to_datetime > 12.hours`
  - Détecter reconnexion : comparer `student_session.created_at` avec `last_activity_at` (nouvelle session = reconnexion)
  - Mettre à jour `welcome_sent: true` et `last_activity_at` après emission

**Checkpoint** : `bundle exec rspec spec/services/tutor/build_welcome_message_spec.rb spec/features/student_tutor_activation_spec.rb` vert

---

## Phase 6: User Story 4 — Migration answer_type (P2)

**Goal**: Toutes les questions existantes migrées vers les 7 nouveaux types, pipeline extraction mis à jour

**Independent Test**: `Question.where(answer_type: nil).count == 0` après migration ; extraction PDF produit les nouveaux libellés

### Specs (TDD)

- [ ] T021 Écrire `spec/migrations/rename_answer_types_spec.rb` — tester : migration up (mapping correct pour chaque ancien type), migration down (rollback propre), 0 questions avec `answer_type: nil` après up

- [ ] T022 [P] Écrire `spec/services/build_extraction_prompt_spec.rb` — tester : le prompt contient les 7 nouveaux libellés, aucune mention des anciens (`text`, `calculation`, `dr_reference`, etc.)

### Implémentation

- [ ] T023 Appliquer la migration T001 et vérifier avec `bundle exec rails db:migrate` puis `bundle exec rails db:rollback`
- [x] T024 [P] Mettre à jour les factories `spec/factories/questions.rb` : `answer_type` utilise les nouvelles valeurs

**Checkpoint** : `bundle exec rails db:migrate && bundle exec rspec spec/migrations/` vert

---

## Phase 7: Spotting spec mise à jour + Polish

**Purpose**: Mise à jour des specs feature spotting et nettoyage global

- [x] T025 Mettre à jour `spec/features/student_tutor_spotting_spec.rb` : remplacer références à `spotting` par `spotting_type` et `spotting_data` selon le nouveau flow
- [x] T026 [P] Supprimer ou mettre à jour les `pending: "UI gap"` dans `spec/features/student_tutor_full_flow_spec.rb` qui ne sont plus valides avec les nouvelles phases
- [ ] T027 [P] Mettre à jour le prompt d'extraction (`build_extraction_prompt.rb`) pour documenter les 7 types dans les instructions au LLM avec des exemples concrets
- [x] T028 Vérifier que `TutorState#to_prompt` est mis à jour pour mentionner la phase par question dans le contexte LLM
- [x] T029 Run complet CI : `bundle exec rspec spec/` — zéro échec attendu

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** : démarrage immédiat
- **Phase 2 (Foundational)** : après Phase 1 — bloque tout
- **Phase 3 (US1)** : après Phase 2 — cœur de la refonte
- **Phase 4 (US2)** : après Phase 3 (dépend de la nouvelle TRANSITION_MATRIX)
- **Phase 5 (US3)** : après Phase 2 — indépendant de US1/US2 sur le greeting
- **Phase 6 (US4)** : après Phase 2 — indépendant, peut avancer en parallèle de US1
- **Phase 7 (Polish)** : après toutes les phases

### Opportunités parallèles

- T005 + T006 (question enum) en parallèle de T003 + T004 (TutorState)
- T008 + T009 (specs US1) en parallèle
- T015 + T019 (specs feature) en parallèle de T014 + T018 (unit specs)
- T021 + T022 (specs US4) en parallèle
- Phase 5 (US3 greeting) en parallèle de Phase 3 (US1 phases)

---

## Implementation Strategy

### MVP (US1 seul — phases adaptées)

1. Phase 1 : migration enum
2. Phase 2 : TutorState + QuestionState + Question enum
3. Phase 3 : apply_tool_calls + build_context (TRANSITION_MATRIX + prompts adaptatifs)
4. **STOP et VALIDER** : sim tuteur sur 5 conversations, vérifier `respect_process`

### Livraison complète

1. Setup + Foundational → US1 (phases) → US2 (reprise) → US3 (greeting) + US4 (migration) → Polish
2. Simulation complète (15 conversations) → mesure SC-004

---

## Notes

- TDD strict : specs en échec AVANT le code de production (constitution IV)
- Commits : un concern par commit (feedback `feedback_commit_scope.md`)
- `evaluate_spotting_tool` : à adapter ou scinder en `evaluate_spotting_type` + `evaluate_spotting_data` (T013 — décider à l'implémentation)
- Compatibilité ascendante JSONB critique : les conversations en prod ne doivent pas casser après déploiement

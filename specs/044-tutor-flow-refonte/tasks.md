# Tasks: Refonte Flow Tuteur (044)

**Input**: Design documents from `/specs/044-tutor-flow-refonte/`
**Branch**: `044-tutor-flow-refonte`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut tourner en parallèle (fichiers distincts, pas de dépendance incomplète)
- **[Story]**: User story associée (US1, US2, US3)
- Constitution IV : specs RSpec écrites et failing AVANT le code

---

## Phase 1 : Setup — Fondation (bloquant)

**Purpose**: Migration + extensions modèles — bloque tout le reste.

- [x] T001 Créer migration `db/migrate/YYYYMMDD_add_kind_to_messages.rb` — `add_column :messages, :kind, :integer, default: 0, null: false` (réversible)
- [x] T002 Étendre `TutorState` dans `app/models/tutor_state.rb` — ajouter `welcome_sent` (default: false) au `Data.define` et mettre à jour `TutorState.default`
- [x] T003 Étendre `QuestionState` dans `app/models/tutor_state.rb` — ajouter `intro_seen` (default: false) au `Data.define`
- [x] T004 Ajouter `enum :kind, { normal: 0, welcome: 1, intro: 2 }` dans `app/models/message.rb`
- [x] T005 Rétrocompatibilité `TutorStateType` dans `app/models/types/tutor_state_type.rb` — vérifier que `welcome_sent` et `intro_seen` sont lus avec `fetch(:welcome_sent, false)` / `fetch(:intro_seen, false)` pour les enregistrements existants

**Specs Phase 1** (écrire failing AVANT T002-T005) :

- [x] T006 [P] Spec `spec/models/tutor_state_spec.rb` — `welcome_sent` default false, `TutorState.default` valide, rétrocompatibilité JSONB sans la clé
- [x] T007 [P] Spec `spec/models/message_spec.rb` — enum kind présent, default `:normal`, valeurs `:welcome` et `:intro` valides

**Checkpoint** : `db:migrate` + `db:rollback` propres, modèles chargent sans erreur, specs T006-T007 passent.

---

## Phase 2 : User Story 1 — Activation et accueil automatique (P1) 🎯 MVP

**Goal**: Clic sur "Activer le tuteur" → drawer s'ouvre automatiquement + message d'accueil dans le drawer. Si tuteur déjà actif au chargement : idem.

**Independent Test**: Activer le tuteur sur un sujet → vérifier que le drawer s'ouvre et qu'un message d'accueil (contenant le titre du sujet) est visible.

### Specs US1 (écrire failing AVANT implémentation)

- [x] T008 [P] [US1] Spec `spec/services/tutor/build_welcome_message_spec.rb` — 4 cas : LLM success (content contient title + n_questions), LLM failure (fallback statique sans exception), message persisté avec `kind: :welcome`, `welcome_sent` mis à true dans TutorState
- [x] T009 [P] [US1] Spec `spec/requests/student/conversations_spec.rb` — `POST #create` avec tuteur non activé : welcome message créé, Turbo Stream replace banner, Turbo Stream dispatch drawer-open ; `POST #create` avec welcome déjà envoyé : pas de doublon

### Implémentation US1

- [ ] T010 [US1] Créer `app/services/tutor/build_welcome_message.rb` — appel LLM RubyLLM (1 phrase, temperature 0.7, max_tokens 30, timeout 8s), template slot-fill, fallback statique `"Lance-toi quand tu es prêt !"`, persist `Message(kind: :welcome)`, update `TutorState#welcome_sent = true` via `UpdateTutorState`
- [ ] T011 [US1] Modifier `app/controllers/student/conversations_controller.rb#create` — après `activate!`, appeler `Tutor::BuildWelcomeMessage` si `!session_record.tutor_state.welcome_sent` ; ajouter second Turbo Stream dispatch `tutor:drawer-open` ; gérer erreur LLM sans bloquer le flow
- [ ] T012 [US1] Modifier `app/views/student/tutor/_tutor_activated.html.erb` — supprimer le bouton "Commencer" (garder uniquement la confirmation visuelle "Tuteur activé ✓")
- [ ] T013 [US1] Modifier `app/views/student/subjects/show.html.erb` — ajouter auto-open conditionnel via attribut Stimulus si `@conversation && !@session_record.tutor_state.welcome_sent` (cas tuteur déjà actif au chargement de page)
- [ ] T014 [US1] Modifier `app/javascript/controllers/chat_drawer_controller.js` — ajouter handler pour l'événement custom `tutor:drawer-open` (écoute `window` ou élément parent, appelle `this.open()`)

**Checkpoint US1** : Feature Capybara scenario 1 passe — activation → drawer ouvert → message d'accueil visible. Scenario 4 passe — retour sur page sujet avec welcome déjà envoyé → drawer reste fermé.

---

## Phase 3 : User Story 2 — Bouton "Commencer" unique et navigation (P1)

**Goal**: Un seul bouton "Commencer" en bas de la page sujet, pointant vers la première question non traitée.

**Independent Test**: Vérifier page sujet — un seul bouton "Commencer" visible. Cliquer → redirige vers Q1.1 (ou première non traitée si progression partielle).

> Note: T012 (suppression bouton dans `_tutor_activated`) est déjà réalisé en Phase 2. Cette phase valide et teste le comportement de navigation.

### Specs US2 (écrire failing AVANT implémentation)

- [ ] T015 [US2] Spec `spec/requests/student/subjects_spec.rb` (ou feature spec) — `GET #show` avec tuteur activé : un seul bouton "Commencer" dans le DOM ; lien pointe vers Q1.1 quand aucune question traitée ; lien pointe vers Q1.3 quand Q1.1 et Q1.2 traitées ; pour sujet spécifique seul, lien pointe vers A.1

### Implémentation US2

- [ ] T016a [US2] Lire `app/views/student/subjects/show.html.erb` et `app/controllers/student/subjects_controller.rb` — vérifier que `@first_question` est bien la première question **non traitée** (via `StudentSession#progression`) et non systématiquement Q1.1
- [ ] T016b [US2] Si la spec T015 échoue sur le cas "progression partielle" : corriger la logique dans `app/controllers/student/subjects_controller.rb` pour utiliser `session_record.first_undone_question` ou équivalent ; sinon, T016b est no-op

**Checkpoint US2** : Un seul bouton "Commencer" sur la page sujet dans tous les états (tuteur actif ou non). Navigation correcte selon progression.

---

## Phase 4 : User Story 3 — Badge intro-question et message contextuel (P2)

**Goal**: Sur la page question avec tuteur actif, badge visible → ouverture drawer → message intro-question déjà présent (avec hint ou concept).

**Independent Test**: Charger page question avec tuteur actif → badge visible sur bouton "Tutorat" → ouvrir drawer → message intro présent et contient hint/concept sans valeur finale.

### Specs US3 (écrire failing AVANT implémentation)

- [ ] T017 [P] [US3] Spec `spec/services/tutor/build_intro_message_spec.rb` — 5 cas : avec `data_hints` (slot data_hint rempli), avec `structured_correction.input_data` sans data_hints (slot concept rempli), avec `correction_text` uniquement (ni data_hints ni structured_correction — edge case spec.md), sans aucune donnée (formulation générique), message persisté avec `kind: :intro` et `role: :assistant`
- [ ] T018 [P] [US3] Spec `spec/requests/student/questions_spec.rb` — `GET #show` avec conversation active et intro absent : intro message créé ; `GET #show` avec intro déjà présent : pas de doublon ; `GET #show` sans conversation : pas d'intro, `@has_intro_badge` false
- [ ] T019 [P] [US3] Spec `spec/requests/student/conversations_spec.rb` — `PATCH #mark_intro_seen` : `intro_seen` mis à true dans TutorState pour la question, 200 OK

### Implémentation US3

- [ ] T020 [US3] Créer `app/services/tutor/build_intro_message.rb` — template slot-fill déterministe (zéro LLM) : sélection hint via `answer.data_hints.first` > `structured_correction["input_data"].first` > générique ; template : `"Question [N] — [label]. Pour progresser, cherche [hint_or_concept]. Je suis là si tu as besoin d'aide — sinon, lance-toi."` ; persist `Message(kind: :intro, role: :assistant)` ; vérifie doublon avant de créer
- [ ] T021 [US3] Modifier `app/controllers/student/questions_controller.rb#show` — si `@conversation` présent ET `!intro_message_exists?(@question)` : appeler `Tutor::BuildIntroMessage` ; calculer `@has_intro_badge = intro_pending?` (intro présent et `!intro_seen?`)
- [ ] T022 [US3] Ajouter action `mark_intro_seen` dans `app/controllers/student/conversations_controller.rb` — met à jour `TutorState` : `question_states[question_id].with(intro_seen: true)` via `UpdateTutorState` ; répond `head :ok`
- [ ] T023 [US3] Ajouter route `patch :mark_intro_seen` dans `config/routes.rb` sous la ressource `conversations`
- [ ] T024 [US3] Modifier `app/views/student/questions/show.html.erb` — ajouter badge/dot sur le bouton "Tutorat" si `@has_intro_badge` (ex: badge rouge ou indicateur "💬") ; aria-label mis à jour : `"Ouvrir le tutorat IA — message en attente"`
- [ ] T025 [US3] Modifier `app/javascript/controllers/chat_drawer_controller.js#open` — après ouverture, si `dataset.conversationId` et `dataset.questionId` présents : fetch `PATCH mark_intro_seen` avec `question_id` pour marquer intro vu

**Checkpoint US3** : Feature Capybara scenarios 3, 4, 5 passent — badge visible, intro dans drawer, badge absent au retour, élève peut répondre directement sans ouvrir drawer.

---

## Phase 5 : Feature Specs E2E et Polish

**Purpose**: Tests Capybara complets + nettoyage.

- [ ] T026 Créer `spec/features/student/tutor_flow_spec.rb` avec les 5 scenarios :
  - Scenario 1 : Activation → drawer ouvert → message d'accueil visible (contient titre sujet)
  - Scenario 2 : Retour page sujet après welcome → drawer reste fermé
  - Scenario 3 : Page question avec tuteur actif → badge visible → ouverture drawer → intro présent
  - Scenario 4 : Retour page question après ouverture drawer → badge absent
  - Scenario 5 : Élève tape réponse directement sans ouvrir drawer → envoi OK
- [ ] T027 [P] Vérifier `app/views/student/conversations/_drawer.html.erb` — les messages `kind: :welcome` et `kind: :intro` s'affichent correctement dans la boucle existante (aucune modification nécessaire si oui, sinon adapter le rendu)
- [ ] T028 [P] Vérifier `app/views/student/subjects/show.html.erb` — confirmer qu'aucun vestige du bouton "Commencer" de `_tutor_activated` n'est rendu dans aucun chemin de code
- [ ] T029 Lancer CI complet — vérifier 0 régression sur les specs existantes tuteur (process_message, build_context, E2E flow existant)
- [ ] T030 QA manuelle SC-002/SC-003 en navigateur — mesurer visuellement : drawer ouvert < 1s post-clic activation (hors LLM) ; message d'accueil visible < 5s (LLM inclus) ; documenter le résultat dans la PR description

---

## Dépendances et ordre d'exécution

### Dépendances entre phases

- **Phase 1** (Setup) : aucune dépendance — commencer immédiatement
- **Phase 2** (US1) : dépend de Phase 1 complète
- **Phase 3** (US2) : dépend de T012 (Phase 2) — peut démarrer dès T012 terminé
- **Phase 4** (US3) : dépend de Phase 1 — indépendante de US1/US2 côté services ; dépend de T011 pour le controller conversations
- **Phase 5** (Polish) : dépend de Phases 2, 3, 4

### Dans chaque phase

- Specs (T00X) : écrire AVANT l'implémentation, vérifier qu'elles FAIL
- Modèles avant services, services avant controllers, controllers avant vues
- Commit après chaque tâche ou groupe logique cohérent (constitution VI.6)

### Opportunités de parallélisme

- T006 et T007 (specs modèles) : parallèles entre eux
- T008 et T009 (specs US1) : parallèles entre eux
- T017, T018, T019 (specs US3) : parallèles entre eux
- T027 et T028 (polish vues) : parallèles entre eux

---

## Stratégie d'implémentation

### MVP (US1 + US2 uniquement)

1. Phase 1 complète (T001-T007)
2. Phase 2 US1 (T008-T014) → valider scenario 1 en navigateur
3. Phase 3 US2 (T015-T016) → valider bouton unique
4. **STOP** : PR partielle si MVP suffisant

### Livraison complète

1. Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
2. Sim validation (SC-004/SC-005) après merge

---

## Résumé

| Phase | Tâches | Parallelisables |
|---|---|---|
| Phase 1 — Setup | T001-T007 | T006, T007 |
| Phase 2 — US1 Activation | T008-T014 | T008, T009 |
| Phase 3 — US2 Bouton | T015-T016 | — |
| Phase 4 — US3 Intro-question | T017-T025 | T017, T018, T019 |
| Phase 5 — Polish/E2E | T026-T029 | T027, T028 |
| **Total** | **29 tâches** | **9 parallèles** |

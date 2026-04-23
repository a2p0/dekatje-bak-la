# Tasks: Refonte Flow Tuteur (044)

**Input**: Design documents from `/specs/044-tutor-flow-refonte/`
**Branch**: `044-tutor-flow-refonte`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut tourner en parallèle (fichiers distincts, pas de dépendance incomplète)
- **[Story]**: User story associée (US1, US2, US3)
- Constitution IV : specs RSpec écrites et failing AVANT le code

---

## Phase 1 : Setup — Fondation (bloquant) ✅ DONE

- [x] T001 Créer migration `add_kind_to_messages`
- [x] T002 Étendre `TutorState` — `welcome_sent`
- [x] T003 Étendre `QuestionState` — `intro_seen`
- [x] T004 Ajouter `enum :kind` dans `Message`
- [x] T005 Rétrocompatibilité `TutorStateType`
- [x] T006 [P] Spec `tutor_state_spec.rb`
- [x] T007 [P] Spec `message_spec.rb`

---

## Phase 2 : Nettoyage page sujet (US1) ✅ DONE (partiel — pivot appliqué)

- [x] T012 Supprimer bouton "Commencer" dans `_tutor_activated.html.erb`

**Pivot 2026-04-23** : T008-T011, T013-T014 remplacés par Phase 3 ci-dessous.
`conversations#create` ne génère plus le welcome depuis la page sujet.
Le `turbo_stream.append(auto-dispatch)` ajouté en Phase 2 est à supprimer (voir T101).

---

## Phase 3 : Indicateur tuteur page sujet (US1 — nouveau) 🎯 MVP

**Goal**: Remplacer le bloc d'activation par un indicateur d'état statique : "Tuteur actif / disponible / indisponible — [Paramétrer]". Aucun bouton d'activation.

### Specs (écrire failing AVANT implémentation)

- [ ] T100 [P] [US1] Spec `spec/requests/student/subjects_spec.rb` — `GET #show` : état "indisponible" (pas de clé, pas de free mode) ; état "disponible" (clé présente, pas de conversation) ; état "actif" (conversation active OU `use_personal_key`) ; aucun bouton "Activer le tuteur" dans le DOM.

### Implémentation US1

- [ ] T101 [US1] Nettoyer `app/controllers/student/conversations_controller.rb#create` — supprimer le `turbo_stream.append` auto-dispatch ; la méthode reste mais ne dispatche plus d'événement drawer depuis ce point.
- [ ] T102 [US1] Modifier `app/views/student/tutor/_tutor_banner.html.erb` — remplacer le contenu par l'indicateur tri-état : "Tuteur indisponible — [Paramétrer]" / "Tuteur disponible" / "Tuteur actif". Supprimer le formulaire d'activation.
- [ ] T103 [US1] Adapter `app/controllers/student/subjects_controller.rb` — calculer `@tutor_status` (`:unavailable`, `:available`, `:active`) et l'exposer à la vue. Condition "actif" : conversation active sur ce sujet OU `current_student.use_personal_key?`.

**Checkpoint US1** : Page sujet affiche le bon état tuteur sans bouton d'activation. T100 passe.

---

## Phase 4 : Bouton "Commencer" unique (US2) 🎯 MVP

**Goal**: Un seul bouton "Commencer" sur la page sujet, navigation vers la première question non traitée.

> Note: T012 (suppression bouton dans `_tutor_activated`) déjà fait. Cette phase valide et corrige si nécessaire.

### Specs

- [ ] T015 [US2] Spec `spec/requests/student/subjects_spec.rb` (ajouter cas) — `GET #show` : un seul bouton "Commencer" dans le DOM ; lien vers Q1.1 sans progression ; lien vers Q1.3 si Q1.1+Q1.2 traitées ; lien vers A.1 pour sujet spécifique seul.

### Implémentation US2

- [ ] T016a [US2] Lire `app/views/student/subjects/show.html.erb` et `subjects_controller.rb` — vérifier que `@first_question` est la première question **non traitée** (via `StudentSession#progression`).
- [ ] T016b [US2] Si T015 échoue sur le cas "progression partielle" : corriger `subjects_controller.rb` pour utiliser la bonne logique ; sinon no-op.

**Checkpoint US2** : Un seul bouton "Commencer", navigation correcte selon progression.

---

## Phase 5 : Activation depuis page question + messages (US3) 🎯 MVP

**Goal**: Clic sur [Tutorat] → drawer s'ouvre immédiatement (spinner) → conversation créée si besoin → welcome (si nouveau) → intro-question (si première visite) → badge si intro non vue.

### Specs (écrire failing AVANT implémentation)

- [ ] T200 [P] [US3] Spec `spec/services/tutor/build_welcome_message_spec.rb` — 4 cas : LLM success, LLM failure (fallback), message persisté `kind: :welcome`, `welcome_sent = true`.
- [ ] T201 [P] [US3] Spec `spec/services/tutor/build_intro_message_spec.rb` — 5 cas : avec `data_hints`, avec `structured_correction.input_data`, avec `correction_text` seul, sans aucune donnée (générique), message persisté `kind: :intro`.
- [ ] T202 [P] [US3] Spec `spec/requests/student/questions_spec.rb` — `GET #show` avec conversation et intro absent : intro créé ; avec intro présent : pas de doublon ; sans conversation : `@has_intro_badge` false.
- [ ] T203 [P] [US3] Spec `spec/requests/student/conversations_spec.rb` — `POST #create` depuis page question : conversation créée, welcome généré, Turbo Stream ouvre drawer ; `POST #create` avec welcome déjà envoyé : pas de doublon.

### Implémentation US3

- [ ] T210 [US3] Créer `app/services/tutor/build_welcome_message.rb` — appel LLM (1 phrase, temperature 0.7, max_tokens 30, timeout 8s), template slot-fill, fallback statique, persist `Message(kind: :welcome)`, `UpdateTutorState` avec `welcome_sent: true`.
- [ ] T211 [US3] Créer `app/services/tutor/build_intro_message.rb` — déterministe (zéro LLM), template slot-fill, priorité hint : `data_hints.first` > `structured_correction["input_data"].first` > générique ; persist `Message(kind: :intro, role: :assistant)` ; idempotent (vérifie doublon avant création).
- [ ] T212 [US3] Modifier `app/controllers/student/conversations_controller.rb#create` — répondre immédiatement en Turbo Stream (ouvrir drawer), appeler `BuildWelcomeMessage` si `!welcome_sent`, appeler `BuildIntroMessage` si `question_id` présent et `!intro_seen`.
- [ ] T213 [US3] Modifier `app/controllers/student/questions_controller.rb#show` — si conversation active et `!intro_message_exists?` : appeler `BuildIntroMessage` ; calculer `@has_intro_badge` (`intro généré ET !intro_seen`).
- [ ] T214 [US3] Ajouter action `mark_intro_seen` dans `conversations_controller.rb` — met à jour `TutorState` : `question_states[question_id].intro_seen = true` via `UpdateTutorState` ; `head :ok`.
- [ ] T215 [US3] Ajouter route `patch :mark_intro_seen` dans `config/routes.rb`.
- [ ] T216 [US3] Modifier `app/views/student/questions/show.html.erb` — wirer le clic [Tutorat] pour appeler `conversations#create` (si pas de conversation) ou simplement ouvrir le drawer (si déjà active) ; afficher spinner pendant la création ; badge sur bouton si `@has_intro_badge`.
- [ ] T217 [US3] Modifier `app/javascript/controllers/chat_drawer_controller.js` — après ouverture, si `dataset.questionId` : fetch `PATCH mark_intro_seen` pour marquer intro vue.

**Checkpoint US3** : Clic [Tutorat] → drawer ouvert < 1s → messages visibles < 5s → badge disparaît après ouverture.

---

## Phase 6 : Feature Specs E2E et Polish

- [ ] T300 Créer `spec/features/student/tutor_flow_spec.rb` avec 5 scenarios :
  - Scenario 1 : première activation → drawer ouvert → welcome + intro visible
  - Scenario 2 : retour sur même question → drawer ouvert → pas de doublon
  - Scenario 3 : navigation vers autre question → intro nouvelle question visible
  - Scenario 4 : élève sans clé → bouton "Tutorat" absent
  - Scenario 5 : élève poste réponse directement sans ouvrir drawer → envoi OK
- [ ] T301 [P] Vérifier `_drawer.html.erb` — messages `kind: :welcome` et `kind: :intro` s'affichent correctement dans la boucle existante.
- [ ] T302 [P] Vérifier `subjects/show.html.erb` — aucun vestige de l'ancien bouton "Activer".
- [ ] T303 Lancer CI complet — 0 régression sur specs tuteur existantes.
- [ ] T304 QA manuelle SC-002/SC-003 en navigateur.

---

## Dépendances

- Phase 3 : aucune dépendance (nettoyage)
- Phase 4 : indépendante de Phase 3
- Phase 5 : dépend de Phase 1 (done) ; T212 dépend de T210
- Phase 6 : dépend de Phases 3, 4, 5

## Résumé

| Phase | Tâches | Status |
|---|---|---|
| Phase 1 — Setup | T001-T007 | ✅ DONE |
| Phase 2 — Nettoyage partiel | T012 | ✅ DONE |
| Phase 3 — Indicateur sujet | T100-T103 | ⏳ |
| Phase 4 — Bouton Commencer | T015-T016b | ⏳ |
| Phase 5 — Activation question | T200-T217 | ⏳ |
| Phase 6 — E2E Polish | T300-T304 | ⏳ |
| **Total restant** | **~22 tâches** | |

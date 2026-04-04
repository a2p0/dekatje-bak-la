# Tasks: Consolidation de l'extraction PDF

**Input**: Design documents from `/specs/015-extraction-consolidation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: TDD obligatoire (constitution IV). Tests écrits et en échec AVANT le code de production.

**Organization**: Tasks groupées par user story pour permettre l'implémentation et le test indépendant de chaque story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Migrations et modèles fondamentaux nécessaires à toutes les user stories

- [x] T001 Migration : renommer EC → EE dans les données existantes `db/migrate/20260404161108_rename_ec_to_ee.rb`
- [x] T002 Migration : créer la table `exam_sessions` `db/migrate/20260404161110_create_exam_sessions.rb`
- [x] T003 Migration : ajouter `exam_session_id` et nouveaux attachments sur `subjects` `db/migrate/20260404161111_add_exam_session_to_subjects.rb`
- [x] T004 Migration : modifier `parts` — ajouter `exam_session_id`, rendre `subject_id` nullable, ajouter `specialty`, `document_references`, check constraint `db/migrate/20260404161112_add_shared_parts_support.rb`
- [x] T005 Migration : ajouter `dt_references`, `dr_references` sur `questions` `db/migrate/20260404161113_add_dt_dr_references_to_questions.rb`
- [x] T006 Migration : ajouter `specialty` sur `students` `db/migrate/20260404161114_add_specialty_to_students.rb`
- [x] T007 Migration : ajouter `part_filter` sur `student_sessions` `db/migrate/20260404161115_add_part_filter_to_student_sessions.rb`
- [x] T008 Migration : ajouter `exam_session_id` sur `extraction_jobs` `db/migrate/20260404161116_update_extraction_jobs.rb`

---

## Phase 2: Foundational (Modèles et associations)

**Purpose**: Modèles et associations qui DOIVENT être en place avant toute user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T009 Spec + modèle ExamSession : associations, validations, enum `app/models/exam_session.rb` + `spec/models/exam_session_spec.rb`
- [x] T010 Mettre à jour le modèle Subject : association `exam_session`, enum EE, nouveaux attachments, validation conditionnelle `app/models/subject.rb` + `spec/models/subject_spec.rb`
- [x] T011 Mettre à jour le modèle Part : dual FK (exam_session_id/subject_id), enum specialty, document_references, validation custom `app/models/part.rb` + `spec/models/part_spec.rb`
- [x] T012 [P] Mettre à jour le modèle Question : ajouter dt_references, dr_references `app/models/question.rb`
- [x] T013 [P] Mettre à jour le modèle Student : ajouter enum specialty `app/models/student.rb`
- [x] T014 [P] Mettre à jour le modèle StudentSession : ajouter enum part_filter `app/models/student_session.rb`
- [x] T015 [P] Mettre à jour le modèle ExtractionJob : ajouter association exam_session `app/models/extraction_job.rb`
- [x] T016 Mettre à jour les factories : exam_session, subject (nouveau format), part (dual FK), question, student, student_session `spec/factories/`

**Checkpoint**: Tous les modèles et associations en place. Migrations passent. Tests modèles verts.

---

## Phase 3: User Story 1 — Upload simplifié d'un sujet BAC (Priority: P1) 🎯 MVP

**Goal**: Un enseignant uploade 2 PDFs (sujet + corrigé) et le système extrait automatiquement la structure complète (parties communes + spécifiques + questions + corrections + DT/DR refs).

**Independent Test**: Uploader un sujet ITEC 2024, vérifier que l'extraction produit les bonnes parties avec questions et corrections.

### Tests US1

> **Write tests FIRST, ensure they FAIL before implementation**

- [x] T017 [P] [US1] Spec pour BuildExtractionPrompt (nouveau format dual-PDF) `spec/services/build_extraction_prompt_spec.rb`
- [x] T018 [P] [US1] Spec pour ExtractQuestionsFromPdf (lecture 2 PDFs, page markers) `spec/services/extract_questions_from_pdf_spec.rb`
- [x] T019 [P] [US1] Spec pour PersistExtractedData (nouveau JSON, common/specific, document_references) `spec/services/persist_extracted_data_spec.rb`
- [x] T020 [P] [US1] Spec pour ExtractQuestionsJob (ExamSession, Turbo broadcast) `spec/jobs/extract_questions_job_spec.rb`
- [x] T021 [US1] Feature spec : enseignant uploade 2 fichiers et voit l'extraction se lancer `spec/features/teacher_upload_new_format_spec.rb`

### Implementation US1

- [x] T022 [US1] Réécrire BuildExtractionPrompt : system prompt dual-PDF, nouveau schema JSON (common_parts, specific_parts, document_references) `app/services/build_extraction_prompt.rb`
- [x] T023 [US1] Modifier ExtractQuestionsFromPdf : lire subject_pdf + correction_pdf avec marqueurs de pages, passer les 2 textes, max_tokens 16384 `app/services/extract_questions_from_pdf.rb`
- [x] T024 [US1] Réécrire PersistExtractedData : créer ExamSession.common_parts + Subject.parts(specific), stocker document_references, dt/dr_references `app/services/persist_extracted_data.rb`
- [x] T025 [US1] Modifier ExtractQuestionsJob : créer ExamSession si nécessaire, broadcaster les updates Turbo `app/jobs/extract_questions_job.rb`
- [x] T026 [US1] Nouveau formulaire teacher : 2 fichiers + métadonnées + select session existante `app/views/teacher/subjects/new.html.erb`
- [x] T027 [US1] Modifier SubjectsController#create : ExamSession find_or_create, strong params, validation `app/controllers/teacher/subjects_controller.rb`
- [x] T028 [US1] Mettre à jour la vue show teacher : afficher structure ExamSession (communes + spé) + document_references `app/views/teacher/subjects/show.html.erb`

**Checkpoint**: Un enseignant peut uploader 2 PDFs, l'extraction produit des parties communes et spécifiques avec questions, corrections et refs DT/DR. Feature spec verte.

---

## Phase 4: User Story 2 — Déduplication parties communes (Priority: P1)

**Goal**: Quand un 2e sujet (autre spé) est uploadé pour la même session, les parties communes sont réutilisées sans duplication.

**Independent Test**: Uploader le sujet AC après le sujet ITEC de la même session, vérifier que les parties communes ne sont pas recréées.

### Tests US2

- [x] T029 [US2] Spec pour PersistExtractedData : cas "session existante avec common_parts" — skip création communes `spec/services/persist_extracted_data_spec.rb`
- [x] T030 [US2] Spec pour ExtractQuestionsJob : prompt allégé quand communes existent `spec/jobs/extract_questions_job_spec.rb`
- [x] T031 [US2] Feature spec : enseignant uploade un 2e sujet en sélectionnant la session existante `spec/features/teacher_session_dedup_spec.rb`

### Implementation US2

- [x] T032 [US2] Modifier PersistExtractedData : détecter si ExamSession a déjà des common_parts, skip la création communes, créer uniquement les spécifiques `app/services/persist_extracted_data.rb`
- [x] T033 [US2] Modifier BuildExtractionPrompt : variante allégée quand session existante (extraire uniquement spécifique + corrections) `app/services/build_extraction_prompt.rb`
- [x] T034 [US2] Modifier ExtractQuestionsJob : passer un flag "skip_common" quand ExamSession.common_parts.any? `app/jobs/extract_questions_job.rb`
- [x] T035 [US2] Mettre à jour le formulaire teacher : peupler le select "Session existante" avec les ExamSessions du prof `app/views/teacher/subjects/new.html.erb` + `app/controllers/teacher/subjects_controller.rb`

**Checkpoint**: 2 sujets de spécialités différentes partagent les mêmes parties communes. Feature spec verte.

---

## Phase 5: User Story 3 — Spécialité sur profil élève (Priority: P2)

**Goal**: Un élève peut indiquer sa spécialité dans ses paramètres.

**Independent Test**: Se connecter comme élève, configurer sa spécialité, vérifier la persistance.

### Tests US3

- [x] T036 [US3] Feature spec : élève configure sa spécialité dans settings `spec/features/student_specialty_spec.rb`

### Implementation US3

- [x] T037 [US3] Modifier la vue settings élève : ajouter sélecteur spécialité (SIN, ITEC, EE, AC) `app/views/student/settings/show.html.erb`
- [x] T038 [US3] Modifier SettingsController#update : accepter le param specialty `app/controllers/student/settings_controller.rb`

**Checkpoint**: L'élève peut choisir et sauvegarder sa spécialité. Feature spec verte.

---

## Phase 6: User Story 4 — Navigation élève : choix du périmètre (Priority: P2)

**Goal**: L'élève choisit commune/spé/complet quand il commence un sujet. Le filtrage s'applique à la navigation.

**Independent Test**: Choisir un périmètre, vérifier que seules les bonnes questions sont affichées. Changer de périmètre, vérifier que la progression est conservée.

### Tests US4

- [x] T039 [US4] Feature spec : élève choisit le périmètre et navigue les questions filtrées `spec/features/student_scope_selection_spec.rb`

### Implementation US4

- [x] T040 [US4] Modifier SubjectsController#show (student) : afficher l'écran de choix périmètre (commune 12pts / spé 8pts / complet 20pts) `app/controllers/student/subjects_controller.rb` + `app/views/student/subjects/show.html.erb`
- [x] T041 [US4] Ajouter action pour sauvegarder le choix de périmètre dans StudentSession#part_filter `app/controllers/student/subjects_controller.rb`
- [x] T042 [US4] Modifier QuestionsController : filtrer les parts selon part_filter (full → toutes, common_only → ExamSession.common_parts, specific_only → Subject.parts.specific) `app/controllers/student/questions_controller.rb`
- [x] T043 [US4] Modifier la vue index sujets élève : afficher les spécialités disponibles par session, filtrage par spé de l'élève `app/views/student/subjects/index.html.erb` + `app/controllers/student/subjects_controller.rb`

**Checkpoint**: L'élève peut choisir son périmètre et ne voit que les questions correspondantes. Progression cumulée lors du changement. Feature spec verte.

---

## Phase 7: User Story 5 — Rétrocompatibilité (Priority: P3)

**Goal**: Les anciens sujets (5 fichiers) continuent de fonctionner sans modification.

**Independent Test**: Accéder à un ancien sujet en tant qu'enseignant et élève, vérifier que tout fonctionne.

- [x] T044 [US5] Vérifier que la validation conditionnelle Subject accepte les 2 formats (ancien 5 fichiers et nouveau 2 fichiers) `spec/models/subject_spec.rb`
- [x] T045 [US5] Vérifier que les vues teacher/show gèrent les 2 formats (anciens attachments et nouveaux) `app/views/teacher/subjects/show.html.erb`
- [x] T046 [US5] Vérifier que la navigation élève fonctionne sans écran de choix périmètre pour les anciens sujets (pas d'ExamSession) `app/controllers/student/subjects_controller.rb`

**Checkpoint**: Les anciens sujets s'affichent et fonctionnent normalement. Aucune régression.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Nettoyage et vérifications finales

- [x] T047 [P] Implémenter l'action destroy ExamSession (FR-023) : route, controller action, confirmation UI, suppression cascade (common_parts + session) `app/controllers/teacher/exam_sessions_controller.rb` + `config/routes.rb`
- [x] T048-a [P] Vérifier que les suppressions respectent FR-022 : supprimer un sujet ne supprime que les parties spécifiques `app/models/subject.rb` + `spec/models/subject_spec.rb`
- [x] T049 [P] Vérifier la conformité RGPD : pas de collecte de données sensibles supplémentaires
- [ ] T050 Exécuter quickstart.md : test end-to-end complet (upload, dédup, profil élève, navigation)
- [x] T051 Nettoyage : supprimer le code mort, vérifier que tous les specs passent `bundle exec rspec`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (migrations) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — MVP, doit être fait en premier
- **US2 (Phase 4)**: Depends on Phase 3 (US1 doit exister pour tester la dédup)
- **US3 (Phase 5)**: Depends on Phase 2 only — peut être fait en parallèle de US1
- **US4 (Phase 6)**: Depends on Phase 3 (US1, pour avoir des sujets avec ExamSession)
- **US5 (Phase 7)**: Depends on Phase 2 only — peut être fait en parallèle
- **Polish (Phase 8)**: Depends on all user stories

### User Story Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational)
                     ├─→ Phase 3 (US1: Upload) → Phase 4 (US2: Dédup) → Phase 6 (US4: Navigation)
                     ├─→ Phase 5 (US3: Spé élève) [parallèle]
                     └─→ Phase 7 (US5: Rétrocompat) [parallèle]
                                                                        → Phase 8 (Polish)
```

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Migrations before models
- Models before services
- Services before controllers/views
- Commit after each task

### Parallel Opportunities

- T012, T013, T014, T015 (modèles indépendants) en parallèle
- T017, T018, T019, T020 (specs US1 indépendantes) en parallèle
- US3 et US5 peuvent être faites en parallèle de US1
- T047, T048 (polish) en parallèle

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Modèles indépendants en parallèle :
Task: "Mettre à jour Question: dt_references, dr_references" (T012)
Task: "Mettre à jour Student: specialty enum" (T013)
Task: "Mettre à jour StudentSession: part_filter enum" (T014)
Task: "Mettre à jour ExtractionJob: exam_session association" (T015)
```

## Parallel Example: US1 Tests

```bash
# Tests US1 en parallèle :
Task: "Spec BuildExtractionPrompt" (T017)
Task: "Spec ExtractQuestionsFromPdf" (T018)
Task: "Spec PersistExtractedData" (T019)
Task: "Spec ExtractQuestionsJob" (T020)
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (migrations)
2. Complete Phase 2: Foundational (modèles)
3. Complete Phase 3: US1 (upload + extraction)
4. **STOP and VALIDATE**: Upload un vrai sujet BAC, vérifier l'extraction
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Base prête
2. US1 → Upload 2 fichiers fonctionne → **MVP!**
3. US2 → Dédup parties communes fonctionne
4. US3 + US5 → Spé élève + rétrocompat (en parallèle)
5. US4 → Navigation élève avec périmètre
6. Polish → Nettoyage final

---

## Notes

- [P] tasks = fichiers différents, pas de dépendances
- [Story] label associe chaque tâche à sa user story
- TDD obligatoire (constitution IV) : test en échec avant implémentation
- Commit après chaque tâche (convention : une préoccupation par commit)
- Ne pas pousser localement les feature specs (CI GitHub)

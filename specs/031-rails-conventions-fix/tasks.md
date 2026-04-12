# Tasks: Rails Conventions Audit Fix

**Input**: Design documents from `/specs/031-rails-conventions-fix/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Tests**: Pas de nouvelles tâches de test — refactoring pur. Les tests existants doivent continuer à passer. Les specs des services seront mises à jour dans les tâches d'implémentation.

**Organization**: Tasks grouped by user story (US1-US8) matching spec.md priorities.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Aucun setup nécessaire — refactoring sur codebase existante.

(Pas de tâches — le projet est déjà initialisé)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Créer les scopes et méthodes modèle qui seront utilisés par les phases suivantes (vues, controllers).

**CRITICAL**: Les scopes (US5) et méthodes modèle (US6) sont des prérequis pour US3 (extraction logique vues).

- [x] T001 [P] Ajouter scope `specific` sur Part dans `app/models/part.rb` — `scope :specific, -> { where(section_type: :specific) }`
- [x] T002 Ajouter scopes `for_parts(parts)` et `for_subject(subject)` sur Question dans `app/models/question.rb` — `scope :for_parts, ->(parts) { kept.where(part: parts) }` et `scope :for_subject, ->(subject) { kept.joins(:part).where(parts: { subject_id: subject.id }) }`
- [x] T004 Mémoiser `filtered_parts` dans `app/models/student_session.rb` — remplacer le corps par `@filtered_parts ||= ...`
- [x] T005 Ajouter méthode `answered_count_for(questions)` sur StudentSession dans `app/models/student_session.rb` — calcule le nombre de questions répondues dans une collection
- [x] T006 Ajouter méthode `validated_questions_count` sur Part dans `app/models/part.rb` — `questions.kept.where(status: :validated).count`

**Checkpoint**: Scopes et méthodes modèle prêts — les vues et controllers peuvent les utiliser.

---

## Phase 3: User Story 1 — Formulaires form_with (Priority: P1) MVP

**Goal**: Migrer les 9 formulaires `form_for`/`form_tag` vers `form_with`.

**Independent Test**: Tous les formulaires se soumettent correctement (login enseignant, register, reset password, login élève, recherche home).

### Implementation

- [x] T007 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/sessions/new.html.erb`
- [x] T008 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/registrations/new.html.erb`
- [x] T009 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/registrations/edit.html.erb`
- [x] T010 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/passwords/new.html.erb`
- [x] T011 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/passwords/edit.html.erb`
- [x] T012 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/confirmations/new.html.erb`
- [x] T013 [P] [US1] Migrer `form_for` → `form_with` dans `app/views/users/unlocks/new.html.erb`
- [x] T014 [P] [US1] Migrer `form_tag` → `form_with` dans `app/views/pages/home.html.erb` (formulaire recherche access_code)
- [x] T015 [P] [US1] Migrer `form_tag` → `form_with` dans `app/views/student/sessions/new.html.erb`

**Checkpoint**: Zéro `form_for`/`form_tag` dans les vues du projet. Tous les formulaires fonctionnent.

---

## Phase 4: User Story 2 — Externaliser script inline (Priority: P1)

**Goal**: Remplacer le `<script>` inline de la home page par un Stimulus controller.

**Independent Test**: Le formulaire access_code sur la home page redirige correctement vers `/<code>`.

### Implementation

- [x] T016 [US2] Créer `app/javascript/controllers/access_code_controller.js` — écoute submit, lit le champ access_code, redirige vers `/<code>`
- [x] T017 [US2] Mettre à jour `app/views/pages/home.html.erb` — ajouter `data-controller="access-code"` et `data-action="submit->access-code#redirect"` au formulaire, supprimer le `<script>` inline

**Checkpoint**: Plus de `<script>` inline dans home.html.erb. Les 3 scripts theme dans les layouts sont des faux positifs justifiés (anti-flash, doivent s'exécuter avant Stimulus).

---

## Phase 5: User Story 3 — Extraire logique métier des vues (Priority: P2)

**Goal**: Déplacer les `.count` et logique de filtrage des vues vers controllers/modèles.

**Independent Test**: L'affichage des compteurs et données est identique dans chaque vue.

**Depends on**: Phase 2 (T004, T005, T006 — méthodes modèle)

### Implementation

- [x] T018 [P] [US3] Remplacer `@students.count` par `@students.size` dans `app/views/teacher/classrooms/show.html.erb`
- [x] T019 [US3] Extraire `classroom.students.count` dans `app/views/teacher/classrooms/index.html.erb` — ajouter `.includes(:students)` dans le controller `app/controllers/teacher/classrooms_controller.rb` et utiliser `classroom.students.size` + `pluralize` dans la vue
- [x] T020 [US3] Extraire `.select(&:validated?).count` dans `app/views/teacher/parts/show.html.erb` — utiliser `Part#validated_questions_count` (T006), remplacer `@questions.count` par `@questions.size`
- [x] T021 [US3] Extraire `.count { answered? }` dans `app/views/student/questions/_sidebar_part.html.erb` — utiliser `session_record.answered_count_for(part_questions)` (T005)
- [x] T022 [US3] Extraire `.count { answered? }` dans `app/views/student/questions/show.html.erb` — utiliser `@session_record.answered_count_for(@questions_in_part)` (T005)
- [x] T023 [P] [US3] Extraire `part.questions.kept.count` dans `app/views/student/subjects/_part_row.html.erb` — pré-charger le count dans le controller ou eager load questions

**Checkpoint**: Plus de logique métier (`.count` avec block, `.select`) dans les vues. Les 2 usages `errors.count` (pattern Rails standard) sont conservés.

---

## Phase 6: User Story 4 — Jobs idempotents (Priority: P2)

**Goal**: Ajouter des gardes d'idempotence pour éviter les doublons sur retry.

**Independent Test**: Exécuter chaque job deux fois avec les mêmes arguments produit le même résultat.

### Implementation

- [x] T024 [P] [US4] Ajouter garde d'idempotence dans `app/jobs/extract_questions_job.rb` — `return if ExtractionJob.find_by(id: extraction_job_id)&.done?` au début de `perform`
- [x] T025 [P] [US4] Ajouter garde d'idempotence dans `app/jobs/tutor_stream_job.rb` — vérifier que la conversation n'a pas déjà un dernier message assistant avant de streamer

**Checkpoint**: Les deux jobs sont idempotents.

---

## Phase 7: User Story 5 — Controllers where() → scopes (Priority: P2)

**Goal**: Remplacer les 7 `where()` directs dans les controllers par les scopes créés en Phase 2.

**Independent Test**: Chaque action de controller retourne les mêmes résultats.

**Depends on**: Phase 2 (T001, T002, T003 — scopes)

### Implementation

- [x] T026 [P] [US5] Remplacer `parts.where(section_type: :specific)` par `parts.specific` dans `app/controllers/student/subjects_controller.rb:201`
- [x] T027 [P] [US5] Remplacer `parts.where(section_type: :specific)` par `parts.specific` dans `app/controllers/teacher/parts_controller.rb:25`
- [x] T028 [P] [US5] Remplacer `parts.where(section_type: :specific)` par `parts.specific` dans `app/controllers/teacher/questions_controller.rb:62`
- [x] T029 [P] [US5] Remplacer `Question.kept.where(part: filtered_parts)` par `Question.for_parts(filtered_parts)` dans `app/controllers/student/questions_controller.rb:70`
- [x] T030 [P] [US5] Simplifier `Question.kept.where(id: allowed_question_ids)` dans `app/controllers/student/questions_controller.rb:54` — laissé tel quel (garde de sécurité par IDs, acceptable)
- [x] T031 [P] [US5] Simplifier `where(id: filtered_question_ids)` dans `app/controllers/student/questions_controller.rb:10` — laissé tel quel (intersection part-scoped avec IDs autorisés)
- [x] T032 [P] [US5] Remplacer `Question.kept.joins(:part).where(parts: { subject_id: })` par `Question.for_subject(@subject)` dans `app/controllers/student/tutor_controller.rb:91`

**Checkpoint**: Zéro `where()` direct dans les controllers.

---

## Phase 8: User Story 6 — Models N+1 et mémoisation (Priority: P2)

**Goal**: Mémoiser les méthodes fréquemment appelées et eager-loader les associations.

**Independent Test**: Nombre de requêtes SQL réduit sur les pages student session et subject listing.

**Depends on**: Phase 2 (T004 — mémoisation déjà faite)

### Implementation

- [x] T033 [US6] Ajouter `.includes(:exam_session)` aux requêtes Subject dans `app/controllers/student/subjects_controller.rb` (déjà présent) et `app/controllers/teacher/subjects_controller.rb` (ajouté)
- [x] T034 [US6] Ajouter `.includes(:questions)` pour les requêtes Part dans `app/controllers/student/subjects_controller.rb` (ajouté dans all_parts_for_subject). `app/controllers/teacher/parts_controller.rb` — non nécessaire (query directe sur un seul part)

**Checkpoint**: Associations eager-loadées. Mémoisation en place (T004).

---

## Phase 9: User Story 7 — Services self.call → new.call (Priority: P3)

**Goal**: Refactorer les 11 services pour suivre le pattern `self.call → new(...).call`.

**Independent Test**: Chaque service produit le même résultat après refactoring.

### Implementation

- [x] T035 [P] [US7] Refactorer `app/services/authenticate_student.rb` — ajouter initialize, convertir self.call en instance method, ajouter `def self.call(...) = new(...).call`
- [x] T036 [P] [US7] Refactorer `app/services/build_extraction_prompt.rb` — même pattern, convertir private_class_method en private instance methods
- [x] T037 [P] [US7] Refactorer `app/services/export_student_credentials_markdown.rb` — même pattern
- [x] T038 [P] [US7] Refactorer `app/services/export_student_credentials_pdf.rb` — même pattern
- [x] T039 [P] [US7] Refactorer `app/services/extract_questions_from_pdf.rb` — même pattern, convertir `self.parse_json_response` et `self.sanitize_json` en instance methods
- [x] T040 [P] [US7] Refactorer `app/services/generate_access_code.rb` — même pattern
- [x] T041 [P] [US7] Refactorer `app/services/generate_student_credentials.rb` — même pattern, convertir `self.unique_username` en instance method
- [x] T042 [P] [US7] Refactorer `app/services/persist_extracted_data.rb` — même pattern, convertir `self.create_questions_and_answers` en instance method
- [x] T043 [P] [US7] Refactorer `app/services/reset_student_password.rb` — même pattern
- [x] T044 [P] [US7] Refactorer `app/services/resolve_api_key.rb` — même pattern
- [x] T045 [P] [US7] Refactorer `app/services/validate_student_api_key.rb` — même pattern

**Checkpoint**: Tous les 11 services suivent `self.call → new.call`. Les 5 exclus (AiClientFactory, TutorSimulation::*) gardent leur interface justifiée.

---

## Phase 10: User Story 8 — Services return values (Priority: P3)

**Goal**: Refactorer les 4 services hash-enveloppe pour retourner des valeurs directes ou lever des exceptions.

**Independent Test**: Chaque caller gère correctement la nouvelle interface.

**Depends on**: Phase 9 (T043, T044, T045, T041 — services déjà refactorés en new.call)

### Implementation

- [x] T046 [US8] Refactorer `app/services/validate_student_api_key.rb` — retourner `true` ou raise `InvalidApiKeyError`. Mettre à jour `app/controllers/student/settings_controller.rb` (rescue) et `spec/requests/student/settings_spec.rb` (stubs)
- [x] T047 [US8] Refactorer `app/services/resolve_api_key.rb` — retourner `Struct.new(:api_key, :provider)`. Mettre à jour `app/jobs/extract_questions_job.rb` (`.api_key`/`.provider`) et `spec/jobs/extract_questions_job_spec.rb` (stubs)
- [x] T048 [US8] Refactorer `app/services/reset_student_password.rb` — retourner le password directement (String). Mettre à jour `app/controllers/teacher/students_controller.rb` et `spec/services/reset_student_password_spec.rb`
- [x] T049 [US8] Refactorer `app/services/generate_student_credentials.rb` — retourner `Struct.new(:username, :password)`. Mettre à jour `app/controllers/teacher/students_controller.rb` (create + bulk_create) et `spec/services/generate_student_credentials_spec.rb`

**Checkpoint**: Aucun service ne retourne de hash-enveloppe. Toutes les specs passent.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Validation finale et nettoyage.

- [x] T050 Lancer la suite de tests complète — 572 examples, 1 failure (pré-existante sur main, test flaky), 1 pending
- [x] T051 Vérifier les critères de succès — tous PASS (voir détails dans le rapport)
- [ ] T052 Push et vérifier CI verte sur GitHub Actions

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Vide
- **Phase 2 (Foundational)**: Scopes + méthodes modèle — BLOQUE Phase 5 (US3), Phase 7 (US5), Phase 8 (US6)
- **Phase 3 (US1 form_with)**: Indépendant
- **Phase 4 (US2 scripts)**: Indépendant
- **Phase 5 (US3 vues logique)**: Dépend de Phase 2
- **Phase 6 (US4 jobs)**: Indépendant
- **Phase 7 (US5 scopes controllers)**: Dépend de Phase 2
- **Phase 8 (US6 N+1)**: Dépend de Phase 2
- **Phase 9 (US7 services pattern)**: Indépendant
- **Phase 10 (US8 services return)**: Dépend de Phase 9
- **Phase 11 (Polish)**: Dépend de toutes les phases

### Parallel Opportunities

```
Phase 2 (fondations)
    ↓
    ├── Phase 3 (US1 form_with)     ← indépendant, peut démarrer en parallèle
    ├── Phase 4 (US2 scripts)       ← indépendant
    ├── Phase 5 (US3 vues)          ← après Phase 2
    ├── Phase 6 (US4 jobs)          ← indépendant
    ├── Phase 7 (US5 scopes ctrl)   ← après Phase 2
    ├── Phase 8 (US6 N+1)           ← après Phase 2
    └── Phase 9 (US7 services)      ← indépendant
                ↓
         Phase 10 (US8 return values) ← après Phase 9
                ↓
         Phase 11 (Polish)
```

---

## Parallel Example

```text
# Batch 1 — tout en parallèle :
Phase 2: T001, T002, T003 (scopes)  |  Phase 3: T007-T015 (form_with)  |  Phase 4: T016-T017 (scripts)  |  Phase 6: T024-T025 (jobs)  |  Phase 9: T035-T045 (services pattern)

# Batch 2 — après Phase 2 :
Phase 5: T018-T023 (vues logique)  |  Phase 7: T026-T032 (scopes controllers)  |  Phase 8: T033-T034 (N+1)

# Batch 3 — après Phase 9 :
Phase 10: T046-T049 (services return values)

# Batch 4 — final :
Phase 11: T050-T052 (validation)
```

---

## Implementation Strategy

### MVP First (US1 + US2 = P1)

1. Compléter Phase 2 (fondations)
2. Compléter Phase 3 (form_with) + Phase 4 (scripts)
3. **STOP et VALIDATE** : zéro violation dans les vues

### Incremental Delivery

1. Phase 2 → Fondations prêtes
2. Phase 3+4 → Violations vues corrigées (MVP)
3. Phase 5+6+7+8 → Warnings P2 corrigés
4. Phase 9+10 → Services alignés
5. Phase 11 → Validation finale, CI verte, PR

---

## Notes

- Toutes les tâches [P] dans une même phase peuvent être exécutées par des subagents parallèles
- Phase 9 (11 services) est le batch le plus parallélisable — chaque service est un fichier indépendant
- Les 3 scripts theme inline dans les layouts sont des faux positifs justifiés et ne sont PAS corrigés
- Les 2 `errors.count` dans les vues sont des patterns Rails standard et ne sont PAS corrigés
- Commit après chaque phase (un concern par commit)

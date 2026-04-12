# Tasks: REST Doctrine Wave 3 — Extraction Retry, Assignment, Exports

**Input**: Design documents from `/specs/034-rest-extraction-assign-export/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: Request specs + service spec (idempotence) + vérification feature specs existants.

**Organization**: 4 user stories. Phase 1 foundational (service idempotent + MIME type) bloque US1. Les 4 US sont indépendantes entre elles côté code.

---

## Phase 1: Setup

Aucun setup — branche créée, code existant.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: PersistExtractedData idempotent + MIME type markdown. Prérequis de US1 (retry extraction) et US3/US4 (exports).

- [ ] T001 Modifier `app/services/persist_extracted_data.rb` — ajouter `@subject.parts.specific.destroy_all` dans la transaction, juste avant la boucle `Array(@data["specific_parts"]).each` (ligne ~58). Cascade supprime questions + answers via `dependent: :destroy`.
- [ ] T002 [P] Ajouter test d'idempotence à `spec/services/persist_extracted_data_spec.rb` — scenarios :
  (a) exécuter `PersistExtractedData.call` deux fois sur le même subject avec les mêmes data, vérifier que le count des specific parts est le même après la 2e exécution (pas de doublons) ;
  (b) après 2e call, vérifier que les common parts (partagées via exam_session) sont toujours présentes et inchangées (non touchées par le cleanup).
- [ ] T003 Créer `config/initializers/mime_types.rb` avec `Mime::Type.register "text/markdown", :markdown`

**Checkpoint**: Service idempotent testé. MIME type markdown disponible pour `respond_to format.markdown`.

---

## Phase 3: User Story 1 — Relancer une extraction échouée (Priority: P1) 🎯

**Goal**: Exposer le retry via `POST /teacher/subjects/:subject_id/extraction`.

**Independent Test**: Créer un subject avec `ExtractionJob` en statut `failed` et des specific parts orphelines, POST sur la nouvelle URL, vérifier reset du job + cleanup des parts + nouveau job enqueued.

**Depends on**: Phase 2 (idempotence)

- [ ] T004 [US1] Créer `app/controllers/teacher/subjects/extractions_controller.rb` — `Teacher::Subjects::ExtractionsController < Teacher::BaseController`, `before_action :set_subject`, action `create` : guard `unless job&.failed?` → redirect+alert ; sinon `job.update!(status: :processing, error_message: nil)` + `ExtractQuestionsJob.perform_later(@subject.id)` + redirect+notice. Méthode privée `set_subject` avec `current_user.subjects.find(params[:subject_id])`.
- [ ] T005 [US1] Mettre à jour `app/views/teacher/subjects/_extraction_status.html.erb:29` — remplacer `retry_extraction_teacher_subject_path(@subject)` par `teacher_subject_extraction_path(@subject)`, method reste `:post`

**Checkpoint**: Retry extraction fonctionne via nouvelle URL. Bug de doublons fixé.

---

## Phase 4: User Story 2 — Assigner un sujet à des classes (Priority: P1)

**Goal**: Exposer le formulaire d'assignation via `GET /teacher/subjects/:subject_id/assignment/edit` + soumission via `PATCH .../assignment`.

**Independent Test**: Visiter la nouvelle URL edit, cocher des classes, soumettre, vérifier que classroom_ids est mis à jour.

**Depends on**: Phase 2 (routes OK)

- [ ] T006 [US2] Créer `app/controllers/teacher/subjects/assignments_controller.rb` — `Teacher::Subjects::AssignmentsController < Teacher::BaseController`, `before_action :set_subject`, actions `edit` (charge `@classrooms` et `@assigned_ids`) et `update` (affecte `@subject.classroom_ids = selected_ids` + redirect+notice).
- [ ] T007 [US2] Déplacer `app/views/teacher/subjects/assign.html.erb` → `app/views/teacher/subjects/assignments/edit.html.erb` via `git mv`. Dans la vue déplacée, remplacer uniquement l'URL du form_with : `form_with url: assign_teacher_subject_path(@subject), method: :patch` → `form_with url: teacher_subject_assignment_path(@subject), method: :patch`. `method: :patch` reste (c'est une update). Conserver tout le reste du contenu (checkboxes, boutons, layout).
- [ ] T008 [P] [US2] Mettre à jour `app/views/teacher/subjects/show.html.erb:45` — remplacer `assign_teacher_subject_path(subject)` par `edit_teacher_subject_assignment_path(subject)`
- [ ] T009 [P] [US2] Mettre à jour `app/views/teacher/subjects/_stats.html.erb:45` — même remplacement

**Checkpoint**: Formulaire d'assignation accessible et fonctionnel via nouvelles URLs.

---

## Phase 5: User Story 3+4 — Exports PDF et Markdown (Priority: P2)

**Goal**: Exposer les exports via `GET /teacher/classrooms/:classroom_id/export.pdf` et `.markdown`.

**Independent Test**: Demander un export PDF puis Markdown sur une classe, vérifier que les fichiers se téléchargent avec les bons Content-Type.

**Depends on**: Phase 2 (MIME type markdown)

- [ ] T010 [US3] Créer `app/controllers/teacher/classrooms/exports_controller.rb` — `Teacher::Classrooms::ExportsController < Teacher::BaseController`, `before_action :set_classroom` via `current_user.classrooms.find(params[:classroom_id])`, action `show` avec `respond_to do |format|` contenant `format.pdf` (appelle `ExportStudentCredentialsPdf.call + send_data pdf.render`) et `format.markdown` (appelle `ExportStudentCredentialsMarkdown.call + send_data md`)
- [ ] T011 [P] [US3] Mettre à jour `app/views/teacher/classrooms/show.html.erb:69` — remplacer `export_pdf_teacher_classroom_path(classroom)` par `teacher_classroom_export_path(classroom, format: :pdf)`
- [ ] T012 [P] [US4] Mettre à jour `app/views/teacher/classrooms/show.html.erb:74` — remplacer `export_markdown_teacher_classroom_path(classroom)` par `teacher_classroom_export_path(classroom, format: :markdown)`

**Checkpoint**: Les 2 exports fonctionnent via nouvelle URL unique avec format différent.

---

## Phase 6: Routes update

**Depends on**: Les 4 controllers créés (Phases 3, 4, 5)

- [ ] T013 Mettre à jour `config/routes.rb` — **ordre critique** : cette tâche s'exécute APRÈS que les 3 nouveaux controllers aient été créés (Phases 3-5) et AVANT la suppression des anciennes actions (Phase 8). Si on supprime les routes avant les nouveaux controllers, les helpers n'existent pas ; si on supprime les actions avant les routes, Rails crashe au démarrage.
  - Dans `resources :subjects do` : supprimer le bloc `member do post :retry_extraction; get :assign; patch :assign; end`. Ajouter `resource :extraction, only: [:create], module: "subjects"` et `resource :assignment, only: [:edit, :update], module: "subjects"`. Conserver `resource :publication` existant.
  - Dans `resources :classrooms do` : supprimer le bloc `member do get :export_pdf; get :export_markdown; end`. Ajouter `resource :export, only: [:show], module: "classrooms"`.

**Checkpoint**: `rails routes` montre les 4 nouvelles routes et zéro ancienne route member non-RESTful pour ces actions.

---

## Phase 7: Publications controller redirect (correction vague 1)

**Purpose**: Le controller de la vague 1 redirige vers `assign_teacher_subject_path` (URL supprimée par cette vague).

- [ ] T014 Mettre à jour `app/controllers/teacher/subjects/publications_controller.rb` — action `create` : remplacer `redirect_to assign_teacher_subject_path(@subject)` par `redirect_to edit_teacher_subject_assignment_path(@subject)`. Effet de bord de US2 (l'URL `assign_teacher_subject_path` est remplacée par la resource Assignment).
- [ ] T015 Mettre à jour `spec/requests/teacher/subjects/publications_spec.rb:27` — remplacer `expect(response).to redirect_to(assign_teacher_subject_path(subject_obj))` par `expect(response).to redirect_to(edit_teacher_subject_assignment_path(subject_obj))`

**Checkpoint**: Publication redirige vers la nouvelle URL d'assignation.

---

## Phase 8: Suppression du code ancien

**Depends on**: Phases 3-6 complètes (tous les callers migrés)

- [ ] T016 Supprimer les actions `retry_extraction` et `assign` de `app/controllers/teacher/subjects_controller.rb`. Mettre à jour `before_action :set_subject, only: [...]` pour retirer `:retry_extraction` et `:assign`.
- [ ] T017 Supprimer les actions `export_pdf` et `export_markdown` de `app/controllers/teacher/classrooms_controller.rb`. Mettre à jour `before_action :set_classroom, only: [...]` pour retirer `:export_pdf` et `:export_markdown`.

**Checkpoint**: Zéro action non-RESTful dans les 2 controllers pour ces 4 actions.

---

## Phase 9: Tests

- [ ] T018 [P] Créer `spec/requests/teacher/subjects/extractions_spec.rb` — scenarios : POST happy path (failed → processing + job enqueued), POST refusé si `pending` (redirect+alert), POST refusé si `processing` (redirect+alert), POST refusé si `done` (redirect+alert), POST refusé si aucun ExtractionJob (edge case — job&.failed? = nil), 404 pour non-propriétaire
- [ ] T019 [P] Créer `spec/requests/teacher/subjects/assignments_spec.rb` — scenarios : GET edit happy path (200 + render), PATCH update avec classroom_ids → association mise à jour + redirect, PATCH sans classroom_ids → assignation vidée, 404 pour non-propriétaire
- [ ] T020 [P] Créer `spec/requests/teacher/classrooms/exports_spec.rb` — scenarios :
  (a) GET .pdf : 200, Content-Type `application/pdf`, Content-Disposition contient `attachment` et `filename=` avec `.pdf`
  (b) GET .markdown : 200, Content-Type `text/markdown`, Content-Disposition contient `attachment` et `filename=` avec `.md`
  (c) 404 pour classroom non-propriétaire
  (Scenario format inconnu non inclus — comportement Rails par défaut, non stable à tester)
- [ ] T021 Mettre à jour `spec/features/teacher_question_validation_spec.rb:147` — `visit assign_teacher_subject_path(subject_record)` → `visit edit_teacher_subject_assignment_path(subject_record)`
- [ ] T022 Mettre à jour `spec/features/teacher_classroom_management_spec.rb:162` — `have_link("Exporter fiches PDF", href: export_pdf_teacher_classroom_path(classroom))` → `have_link("Exporter fiches PDF", href: teacher_classroom_export_path(classroom, format: :pdf))`
- [ ] T023 Mettre à jour `spec/requests/teacher/subjects_spec.rb` — retirer les tests de `retry_extraction` et `assign` s'ils existent, ajouter commentaire pointant vers les nouveaux specs
- [ ] T024 Mettre à jour `spec/requests/teacher/classrooms_spec.rb` — retirer les tests de `export_pdf` et `export_markdown` s'ils existent, ajouter commentaire
- [ ] T025 Lancer `bundle exec rspec spec/features/teacher_subject_upload_spec.rb spec/features/teacher_question_validation_spec.rb spec/features/teacher_classroom_management_spec.rb` — doivent tous passer (labels stables)

**Checkpoint**: Couverture complète.

---

## Phase 10: Validation finale

- [ ] T026 Lancer la suite complète `bundle exec rspec` — vérifier 0 régression (modulo flakys pré-existants connus)
- [ ] T027 Vérifier les critères de succès :
  - `grep -r "retry_extraction_teacher_subject_path" app/ spec/` → 0 occurrence
  - `grep -r "assign_teacher_subject_path" app/ spec/` → 0 occurrence
  - `grep -r "export_pdf_teacher_classroom_path" app/ spec/` → 0 occurrence
  - `grep -r "export_markdown_teacher_classroom_path" app/ spec/` → 0 occurrence
  - `grep -n "def retry_extraction\|def assign\|def export_pdf\|def export_markdown" app/controllers/teacher/subjects_controller.rb app/controllers/teacher/classrooms_controller.rb` → 0 occurrence
- [ ] T028 `bin/rubocop` → 0 offense
- [ ] T029 Push + créer la PR vers main

---

## Dependencies & Execution Order

```
Phase 1 (Setup)              vide
    ↓
Phase 2 (Foundational)       T001 → T002 [P], T003 [P]
    ↓
Phase 3 (US1 Extraction)     T004 → T005
    ├── Phase 4 (US2 Assignment)   T006 → T007 → T008, T009 [P]
    └── Phase 5 (US3+4 Exports)    T010 → T011, T012 [P]
    ↓
Phase 6 (Routes)             T013
    ↓
Phase 7 (Publications fix)   T014 → T015
    ↓
Phase 8 (Nettoyage)          T016 [P], T017 [P]
    ↓
Phase 9 (Tests)              T018, T019, T020 [P] ; T021, T022, T023, T024 [P] ; T025
    ↓
Phase 10 (Validation)        T026 → T027 → T028 → T029
```

### Parallel Opportunities

- **Phase 2** : T002 et T003 indépendants (fichiers différents)
- **Phase 3/4/5** : peuvent être faits en parallèle après Phase 2 (controllers dans fichiers différents) — sauf Phase 6 qui dépend de tous les controllers existants
- **Phase 4/5 vues** : T008/T009 et T011/T012 parallélisables (fichiers différents)
- **Phase 8** : T016 et T017 sur différents controllers [P]
- **Phase 9** : T018/T019/T020 (3 request specs différents) [P], T021/T022/T023/T024 (différentes specs) [P]

---

## Implementation Strategy

### Incrémental par user story

Les 4 user stories peuvent être livrées indépendamment après Phase 2 + Phase 6 (routes) + nettoyage partiel. Mais en pratique, on les livre toutes dans la même PR (couplage logique fort : toutes les 4 retirent des member actions du même bloc routes).

### Défense en profondeur : idempotence au service

Le fix du bug de doublons est fait **au niveau service** (PersistExtractedData), pas controller. Avantage : tout caller du service (futur ou actuel) bénéficie de l'idempotence. Coût : zéro (destroy_all sur collection vide = no-op).

### MIME type markdown

Chargé au boot Rails via initializer. Une fois enregistré, disponible partout (controllers, views, routes avec `format:` param).

---

## Notes

- Pattern `respond_to` multi-format = **nouveauté vague 3** (vagues 1-2 n'avaient que du turbo_stream+html single)
- Pattern `edit`/`update` sur singular resource = **nouveauté vague 3** (vagues 1-2 n'avaient que `create`/`destroy`)
- Phase 7 corrige un couplage inter-vagues (publications vague 1 → assignment vague 3)
- Après cette vague : **reste 2-10 actions à migrer** (vagues 4-5, selon exceptions retenues)

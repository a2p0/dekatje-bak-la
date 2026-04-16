---

description: "Task list for Teacher P0 bug fixes (041)"
---

# Tasks: Teacher P0 bug fixes

**Input**: Design documents from `/specs/041-teacher-p0-bugs/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/routes.md, quickstart.md

**Tests**: Tests TDD systématiques (constitution IV NON-NEGOTIABLE + feedback `feature_tests.md`). Feature spec Capybara pour chaque story + request spec pour `destroy`.

**Organization**: Tasks groupés par user story (US1 P1, US2 P1, US3 P2). Chaque story est indépendamment implémentable, testable et déployable. Ordre recommandé : US1 → US2 → US3 (un commit par story).

## Format: `[ID] [P?] [Story] Description`

- **[P]** : parallelisable (fichier différent, pas de dépendance sur un task non-terminé)
- **[Story]** : US1 / US2 / US3 (mappe directement aux user stories de spec.md)
- Paths absolus depuis la racine du repo

## Path Conventions

Monolithe Rails 8. Structure standard :

- Controllers : `app/controllers/teacher/`
- Views : `app/views/teacher/`
- Routes : `config/routes.rb`
- Specs : `spec/features/teacher/`, `spec/requests/teacher/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Aucun setup nécessaire. Branche `041-teacher-p0-bugs` déjà créée, aucune gem, aucune migration, aucun composant à scaffold.

- [X] T001 Vérifier que la branche `041-teacher-p0-bugs` est bien checkout (`git branch --show-current` doit retourner `041-teacher-p0-bugs`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Aucun pré-requis foundational. La colonne `subjects.discarded_at` et le scope `kept` existent déjà. `ButtonComponent` existe déjà. Route d'export PDF existe déjà.

**⚠️ CRITICAL**: Phase vide — on peut démarrer les user stories directement après T001.

**Checkpoint**: Foundation ready (N/A — rien à faire).

---

## Phase 3: User Story 1 — Téléchargement PDF dans bandeau credentials (Priority: P1) 🎯 MVP

**Goal**: Permettre à l'enseignant de télécharger la fiche PDF des élèves inscrits directement depuis le bandeau "Identifiants générés", avant que les mots de passe en clair ne disparaissent.

**Independent Test**: après inscription d'un ou plusieurs élèves, la page `/teacher/classrooms/:id` affiche le bandeau ambre avec un bouton "Télécharger la fiche PDF" pointant sur l'export PDF de la classe.

### Tests for User Story 1 (TDD — écrire d'abord, vérifier qu'ils échouent)

- [X] T002 [P] [US1] Écrire feature spec Capybara dans `spec/features/teacher/classroom_credentials_download_spec.rb` vérifiant que le bouton "Télécharger la fiche PDF" est présent et pointe sur `teacher_classroom_export_path(classroom, format: :pdf)` quand `@generated_credentials` est injecté en session

### Implementation for User Story 1

- [X] T003 [US1] Modifier `app/views/teacher/classrooms/show.html.erb` : ajouter un `ButtonComponent` variant `:primary` size `:sm` texte "Télécharger la fiche PDF" lié à `teacher_classroom_export_path(@classroom, format: :pdf)` à l'intérieur du bloc `if @generated_credentials.present?` (juste après la table des credentials, avant la fermeture du `<div>` ambre)

- [X] T004 [US1] Vérifier que T002 passe maintenant en vert (run local + CI)

- [X] T005 [US1] Commit : `feat(teacher): add credentials PDF download button in generated banner` (un seul commit pour US1)

**Checkpoint**: US1 complète et déployable en MVP.

---

## Phase 4: User Story 2 — Archivage d'un sujet (Priority: P1)

**Goal**: Ajouter l'action destroy (soft-delete) sur `Teacher::SubjectsController` et le bouton "Archiver le sujet" sur la page de détail du sujet. Le sujet archivé disparaît de la liste active sans perte de données.

**Independent Test**: depuis `/teacher/subjects/:id`, clic sur "Archiver le sujet" + confirmation → redirect vers `/teacher/subjects` avec flash de succès et le sujet ne figure plus dans la liste.

### Tests for User Story 2 (TDD)

- [ ] T006 [P] [US2] Écrire request spec dans `spec/requests/teacher/subjects_controller_spec.rb` couvrant trois scénarios `DELETE /teacher/subjects/:id` : (a) owner archive avec succès (`discarded_at` mis à jour, redirect vers `teacher_subjects_path`, flash notice), (b) non-owner reçoit alert "Sujet introuvable." et `discarded_at` reste nil, (c) idempotence — un second DELETE sur un sujet déjà archivé retourne alert "Sujet introuvable."

- [ ] T007 [P] [US2] Écrire feature spec Capybara dans `spec/features/teacher/subject_archive_spec.rb` : enseignant visite `/teacher/subjects/:id`, clique sur "Archiver le sujet", accepte la confirmation, vérifie redirect vers `/teacher/subjects` + flash "archivé" + le titre du sujet n'apparaît plus dans la liste

### Implementation for User Story 2

- [ ] T008 [US2] Modifier `config/routes.rb` : ajouter `:destroy` à `resources :subjects` (ligne 17) dans le bloc `namespace :teacher`

- [ ] T009 [US2] Modifier `app/controllers/teacher/subjects_controller.rb` : (a) étendre `before_action :set_subject` avec `:destroy`, (b) ajouter action `destroy` qui appelle `@subject.update!(discarded_at: Time.current)` + redirect vers `teacher_subjects_path` avec notice "Sujet « #{@subject.exam_session&.title || 'sans titre'} » archivé.", (c) modifier `set_subject` pour utiliser `current_teacher.subjects.kept.find_by(id: params[:id])` (filtrer les sujets archivés aussi sur `show`)

- [ ] T010 [US2] Modifier `app/views/teacher/subjects/show.html.erb` : transformer le bloc "Back link" (ligne 106-110) en flex-between contenant le bouton "← Retour aux sujets" à gauche ET un `button_to "Archiver le sujet"` à droite, méthode `:delete`, avec `form: { data: { turbo_confirm: "Archiver ce sujet ? Il disparaîtra de votre liste." } }`, classes `text-sm text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 underline underline-offset-2`

- [ ] T011 [US2] Vérifier que T006 et T007 passent maintenant en vert (run local + CI)

- [ ] T012 [US2] Commit : `feat(teacher): add soft-delete archive action for subjects` (un seul commit couvrant route + controller + vue + specs)

**Checkpoint**: US2 complète. US1 + US2 opérationnelles ensemble, indépendamment testables.

---

## Phase 5: User Story 3 — Feedback extraction IA avec temps écoulé (Priority: P2)

**Goal**: Afficher le temps écoulé depuis le démarrage du job d'extraction quand il est en cours (`processing`), et annoncer les changements de statut aux technologies d'assistance via `aria-live`.

**Independent Test**: un job ExtractionJob en statut `processing` avec `updated_at = 45.seconds.ago` rendu sur `/teacher/subjects/:id` affiche "Extraction en cours… démarrée il y a X" et le wrapper a `aria-live="polite"`.

### Tests for User Story 3 (TDD)

- [ ] T013 [P] [US3] Écrire feature spec dans `spec/features/teacher/extraction_status_feedback_spec.rb` couvrant deux scénarios : (a) job processing avec `updated_at = 45.seconds.ago` → page contient `#extraction-status[aria-live="polite"]` et le texte `/démarrée il y a/`, (b) fallback gracieux — si `updated_at` est stubé à nil, la page affiche "Extraction en cours" sans la mention temporelle et ne lève aucune exception

### Implementation for User Story 3

- [ ] T014 [US3] Modifier `app/views/teacher/subjects/_extraction_status.html.erb` : (a) ajouter `aria-live="polite" aria-atomic="true"` sur le `<div id="extraction-status">` (ligne 2), (b) dans le bloc `if job.processing?` (ligne 34-44), ajouter après "Extraction en cours…" un `<% if job.updated_at %><span class="text-slate-500 dark:text-slate-400">démarrée il y a <%= time_ago_in_words(job.updated_at) %></span><% end %>` — veiller à conserver le span dans la phrase `<p>` existante

- [ ] T015 [US3] Vérifier que T013 passe maintenant en vert (run local + CI)

- [ ] T016 [US3] Commit : `feat(teacher): show elapsed time and aria-live for extraction status`

**Checkpoint**: US3 complète. Les 3 stories (US1 + US2 + US3) sont fonctionnelles indépendamment.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Vérifications transverses avant PR.

- [ ] T017 Run `bundle exec rubocop` en local et corriger d'éventuels warnings introduits par les commits de cette feature

- [ ] T018 Push `041-teacher-p0-bugs` sur origin et vérifier que la CI passe au vert (constitution IV : CI autoritative, pas local)

- [ ] T019 Créer la PR vers `main` via `gh pr create` avec titre `feat(teacher): P0 bug fixes — credentials download, subject archive, extraction feedback` et description listant les 3 user stories + leurs scénarios d'acceptance

- [ ] T020 Validation manuelle rapide post-merge : (a) inscrire un élève dans une classe, vérifier le bouton de téléchargement dans le bandeau ; (b) archiver un sujet et vérifier sa disparition de la liste ; (c) lancer une extraction et vérifier l'affichage du temps écoulé

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** : T001 seul, trivial.
- **Phase 2 (Foundational)** : vide, skip directement.
- **Phase 3-5 (User Stories)** : chaque phase est **indépendante** — US1, US2, US3 touchent des fichiers différents, pas de shared state entre elles. Elles peuvent s'exécuter en parallèle si besoin, mais l'ordre recommandé pour un commit atomique par story est US1 → US2 → US3.
- **Phase 6 (Polish)** : après US1+US2+US3 complètes.

### User Story Dependencies

- **US1 (P1)** : aucune dépendance. Peut démarrer après T001.
- **US2 (P1)** : aucune dépendance. Peut démarrer après T001.
- **US3 (P2)** : aucune dépendance. Peut démarrer après T001.

### Within Each User Story

- **TDD** : tests d'abord (T002 pour US1, T006+T007 pour US2, T013 pour US3). Vérifier qu'ils échouent avant d'implémenter.
- Ordre US2 : T008 (route) → T009 (controller) → T010 (vue) → T011 (verif tests). Route avant controller avant vue.
- US1 et US3 : une seule tâche d'implémentation, pas d'ordre interne.

### Parallel Opportunities

Les 3 user stories touchent des fichiers **entièrement disjoints**. Si un second développeur ou un subagent Frontend Developer est dispatché :

- Dev A : US1 (T002, T003, T004, T005)
- Dev B : US2 (T006, T007, T008, T009, T010, T011, T012)
- Dev C : US3 (T013, T014, T015, T016)

Les 3 peuvent merger sur la même branche en parallèle sans conflit (fichiers distincts).

Tests marqués [P] dans chaque phase peuvent se lancer en parallèle.

---

## Parallel Example: User Story 2

```bash
# Launch tests for US2 together (fichiers distincts) :
Task: "Écrire request spec dans spec/requests/teacher/subjects_controller_spec.rb"
Task: "Écrire feature spec dans spec/features/teacher/subject_archive_spec.rb"

# Implementation ensuite en séquence (dépendances) :
1. config/routes.rb (T008)
2. app/controllers/teacher/subjects_controller.rb (T009)
3. app/views/teacher/subjects/show.html.erb (T010)
```

---

## Implementation Strategy

### MVP First (User Story 1 seulement)

1. T001 : vérifier branche.
2. T002 : écrire feature spec US1 (échoue).
3. T003 : implémenter le bouton.
4. T004 : spec passe.
5. T005 : commit.
6. **STOP and VALIDATE** : le bandeau affiche bien le bouton. MVP livré.

### Incremental Delivery recommandée

1. MVP = US1 (5 tasks).
2. US2 = 7 tasks (y compris les 2 specs).
3. US3 = 4 tasks.
4. Polish (Phase 6) = 4 tasks.
5. Total = **20 tasks**, ~30 lignes de prod.

### Seul dev — approche séquentielle

Ordre recommandé pour 1 dev solo :

```
T001 → T002 → T003 → T004 → T005 (commit US1)
     → T006 → T007 → T008 → T009 → T010 → T011 → T012 (commit US2)
     → T013 → T014 → T015 → T016 (commit US3)
     → T017 → T018 → T019 → T020 (polish + PR)
```

Chaque commit passe la CI indépendamment.

---

## Notes

- **[P]** = fichiers différents, pas de dépendance → peuvent se lancer en parallèle.
- **[Story]** : US1/US2/US3 mappe aux user stories de `spec.md`.
- Chaque story est indépendamment complétable et testable (contrainte plan.md et constitution VI).
- **Feature tests systématiques** (`feedback_feature_tests.md`) : une feature spec Capybara par user-facing feature → respecté.
- **Conventional Commits** (`CLAUDE.md`) : un commit par concern (un par user story).
- **One concern per commit** (`feedback_commit_scope.md`) : respecté.
- **CI not local** (constitution IV) : T018 pousse et attend CI verte avant T019 (PR).
- **Never code without ask** (constitution VI) : la doctrine dit de présenter un plan d'abord. Ici le plan est validé, `/speckit.implement` peut enchaîner.
- Éviter les sauts dans l'ordre interne US2 (route avant controller avant vue) — Rails RESTful rejette un controller#destroy si la route n'existe pas.

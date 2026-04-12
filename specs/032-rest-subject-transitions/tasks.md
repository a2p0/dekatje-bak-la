# Tasks: REST Doctrine — Subject Publication

**Input**: Design documents from `/specs/032-rest-subject-transitions/`
**Prerequisites**: plan.md (required), spec.md (required), research.md

**Tests**: Request spec créé (nouveau controller) + specs modèle + vérification feature specs existants. Refactoring pur : pas de nouveaux scenarios utilisateur.

**Organization**: 2 user stories (publish, unpublish) qui partagent l'infrastructure. Phases structurées par couche technique pour minimiser les conflits de fichiers.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

**Purpose**: Aucun setup — branche déjà créée, code existant.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Méthodes métier sur le modèle Subject + exception. Prérequis pour toutes les US.

**CRITICAL**: Phase 2 bloque toutes les phases suivantes (controller dépend de `publish!`/`unpublish!`).

- [ ] T001 Ajouter `class InvalidTransition < StandardError` dans `app/models/subject.rb`
- [ ] T002 Ajouter méthode `Subject#publish!` dans `app/models/subject.rb` — raise InvalidTransition si déjà publié ou pas publishable, sinon `update!(status: :published)`
- [ ] T003 Ajouter méthode `Subject#unpublish!` dans `app/models/subject.rb` — raise InvalidTransition si pas publié, sinon `update!(status: :draft)`
- [ ] T004 [P] Créer ou étendre `spec/models/subject_spec.rb` — tests unitaires pour `publish!` (happy path, déjà publié, pas publishable) et `unpublish!` (happy path, pas publié)

**Checkpoint**: Méthodes métier et exception testées.

---

## Phase 3: User Story 1 — Publier un sujet validé (Priority: P1) 🎯 MVP

**Goal**: Exposer le `publish!` via `POST /teacher/subjects/:id/publication`.

**Independent Test**: Créer un sujet `pending_validation` avec 1 question validée, POST sur la nouvelle URL via request spec, vérifier status=published et redirect vers assign.

**Depends on**: Phase 2 (Subject#publish!)

### Implementation

- [ ] T005 [US1] Créer `app/controllers/teacher/subjects/publications_controller.rb` — classe `Teacher::Subjects::PublicationsController < Teacher::BaseController` avec before_action `:set_subject`, rescue_from `Subject::InvalidTransition`, actions `create` et `destroy` (structure complète voir plan.md Phase 2)
- [ ] T006 [US1] Mettre à jour `config/routes.rb` — dans `namespace :teacher`, supprimer les 3 routes member `patch :publish`, `patch :unpublish`, `patch :archive` (dernière = route orpheline, FR-008). Ajouter `resource :publication, only: [:create, :destroy], module: "subjects"` à l'intérieur du bloc `resources :subjects`
- [ ] T007 [US1] Inspecter `app/views/teacher/subjects/_stats.html.erb`. Si le partial n'a pas de wrapper racine avec id `subject_stats_<%= subject.id %>`, entourer le contenu du partial d'une `<div id="subject_stats_<%= subject.id %>">...</div>`. Vérifier aussi que `app/views/shared/_flash.html.erb` existe — sinon le créer avec un simple `<% if notice %><div class="flash"><%= notice %></div><% end %>` équivalent pour alert
- [ ] T008 [US1] Créer `app/views/teacher/subjects/publications/create.turbo_stream.erb` — replace `"subject_stats_#{@subject.id}"` avec partial `teacher/subjects/stats` locals `subject: @subject` + replace `"flash"` avec partial `shared/flash` locals `notice: "Sujet publié."`
- [ ] T009 [US1] Remplacer le `button_to "Publier le sujet"` dans `app/views/teacher/subjects/_stats.html.erb:25-29` — nouveau helper `teacher_subject_publication_path(subject)` method `:post`
- [ ] T010 [US1] Remplacer le `button_to "Publier le sujet"` dans `app/views/teacher/parts/show.html.erb:62-66` — nouveau helper `teacher_subject_publication_path(@subject)` method `:post`

**Checkpoint**: Publication fonctionne via nouvelle URL. L'ancienne `publish` action existe encore (nettoyée en Phase 5).

---

## Phase 4: User Story 2 — Dépublier un sujet publié (Priority: P1)

**Goal**: Exposer `unpublish!` via `DELETE /teacher/subjects/:id/publication`.

**Independent Test**: Créer un sujet `published`, DELETE sur la nouvelle URL, vérifier status=draft et redirect vers show.

**Depends on**: Phase 2 (Subject#unpublish!), Phase 3 (controller + routes + partial déjà créés)

### Implementation

- [ ] T011 [US2] Créer `app/views/teacher/subjects/publications/destroy.turbo_stream.erb` — replace `"subject_stats_#{@subject.id}"` avec partial `teacher/subjects/stats` + replace flash partial
- [ ] T012 [US2] Remplacer le `button_to "Dépublier"` dans `app/views/teacher/subjects/_stats.html.erb:40-44` — nouveau helper `teacher_subject_publication_path(subject)` method `:delete`

**Checkpoint**: Dépublication fonctionne via nouvelle URL.

---

## Phase 5: Suppression du code ancien

**Purpose**: Retirer les anciennes actions `publish`/`unpublish`/`archive` de `Teacher::SubjectsController` et routes orphelines.

**Depends on**: Phase 3 + Phase 4 (tous les callers migrés)

- [ ] T013 Supprimer les actions `publish`, `unpublish`, `archive` de `app/controllers/teacher/subjects_controller.rb`
- [ ] T014 Vérifier et nettoyer le `before_action :set_subject` dans `app/controllers/teacher/subjects_controller.rb` — retirer les action names supprimées si présentes dans `only:` / `except:`

**Checkpoint**: Zéro action non-RESTful dans `Teacher::SubjectsController` pour publish/unpublish/archive. Zéro route orpheline.

---

## Phase 6: Tests

**Purpose**: Request spec pour le nouveau controller + vérification feature specs existants.

- [ ] T015 Créer `spec/requests/teacher/subjects/publications_spec.rb` — scenarios : POST happy path (draft + question validée, puis pending_validation + question validée), POST déjà publié → redirect+alert, POST sans question validée → redirect+alert, DELETE happy path (published), DELETE pas publié → redirect+alert, non-propriétaire → 404
- [ ] T016 Lancer `bundle exec rspec spec/features/teacher_question_validation_spec.rb` — doit passer (labels "Publier le sujet" / "Dépublier" préservés)
- [ ] T017 Lancer `bundle exec rspec spec/models/subject_spec.rb spec/requests/teacher/subjects/publications_spec.rb` — tous passent

**Checkpoint**: Couverture complète. Tests passent.

---

## Phase 7: Polish & Validation

- [ ] T018 Lancer la suite complète `bundle exec rspec` — vérifier 0 régression (1 failure pré-existante flaky sur global_navigation_spec:90 est OK)
- [ ] T019 Vérifier les critères de succès : grep `publish_teacher_subject_path`, `unpublish_teacher_subject_path`, `archive_teacher_subject_path`, `def publish`, `def unpublish`, `def archive` dans `app/controllers/teacher/subjects_controller.rb` → 0 occurrences
- [ ] T020 Push et créer la PR vers main

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)                         vide
    ↓
Phase 2 (Foundational: modèle)          T001 → T002 → T003, T004 [P]
    ↓
Phase 3 (US1: publier)                  T005 → T006 → T007 → T008, T009, T010 [P partial]
    ↓
Phase 4 (US2: dépublier)                T011, T012 [P]
    ↓
Phase 5 (Nettoyage)                     T013 → T014
    ↓
Phase 6 (Tests)                         T015 [P], T016, T017 séquentiels
    ↓
Phase 7 (Validation)                    T018 → T019 → T020
```

### Parallel Opportunities

- **Phase 2** : T004 (spec modèle) peut être écrit en parallèle des implémentations T001-T003 (TDD-like)
- **Phase 3** : T009 et T010 (2 views différentes) peuvent être faits en parallèle après T005-T008
- **Phase 4** : T011 et T012 (2 fichiers différents) peuvent être faits en parallèle

---

## Implementation Strategy

### Incremental Delivery

1. Phase 2 → méthodes métier testées indépendamment du HTTP
2. Phase 3 + 4 → double surface (ancien + nouveau) coexistent. Les callers (vues) utilisent déjà le nouveau.
3. Phase 5 → suppression de l'ancien code maintenant qu'aucun caller ne l'utilise
4. Phase 6 + 7 → validation complète

### MVP minimal

Si on voulait livrer juste la publication (sans dépublication) :
- Phase 2 (publish! uniquement)
- Phase 3 (sauf DELETE)
- Phase 5 partiel (retirer seulement `publish` + `archive`)

Mais c'est artificiel — les 2 opérations sont symétriques et doivent être livrées ensemble.

### Sécurité du refactoring

Entre Phase 3 et Phase 5, l'ancien et le nouveau coexistent :
- Anciennes routes existent encore → OK, personne ne les appelle (vues migrées)
- Anciennes actions existent encore → OK, orphelines mais non accédées

Phase 5 est la suppression propre à la fin.

---

## Notes

- Tasks `[P]` peuvent être exécutées en parallèle (subagents ou séquentiellement rapide)
- La stratégie de coexistence (ancien + nouveau) évite de casser la nav en cours de migration
- La Phase 6 valide que les feature specs existants passent sans modification — critère de succès clé de la migration REST (ils testent par label, pas par URL helper)
- Pattern établi ici (`Model#transition!` + `rescue_from ... InvalidTransition`) sera réutilisé pour les 4 vagues suivantes

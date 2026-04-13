# REST Doctrine Migration — Plan global

**Date de lancement** : 2026-04-12
**Référence** : `~/.claude/skills/rails-conventions/references/rest-doctrine.md`
**Issue d'origine** : audit `/rails-conventions audit` post-PR #33 — 24 actions non-RESTful identifiées

## Objectif

Aligner tous les controllers du projet sur la doctrine CRUD-only :
chaque action mappe sur `index/show/new/create/edit/update/destroy`.
Les actions custom sont extraites en controllers dédiés pour des resources nommées.

## Approche

Migration par **vagues thématiques** plutôt qu'une mega-PR.
Chaque vague = 1 feature speckit indépendante = 1 PR.

Motivation :
- Mega-PR avec 24 renommages = touche 50+ fichiers = revue impossible
- Chaque vague permet d'apprendre et d'ajuster l'approche
- Risque localisé, rollback simple

## Décisions techniques (tranchées 2026-04-12)

1. **État machine** : enum Rails natif + méthodes métier (pas de gem AASM/state_machines)
2. **Exception custom** : `<Model>::InvalidTransition < StandardError` par modèle avec transitions
3. **Error handling** : `rescue_from` dans le controller de transition + `respond_to` html/turbo_stream
4. **Namespacing** : conserver `Teacher::` / `Student::` existants
5. **Tests** : request specs pour nouveaux controllers + feature specs existantes mises à jour

## Vagues

### Vague 1 — Subject state transitions (2 actions) — MERGÉE

**Controller** : `Teacher::SubjectsController`
**Actions migrées** : `publish`, `unpublish`
**Action supprimée** : `archive` (route orpheline, jamais exposée dans une vue)
**Nouveau controller** :
- `Teacher::Subjects::PublicationsController#create/destroy`
**Modèle** : `Subject#publish!/unpublish!` + `Subject::InvalidTransition`

**Routes finales** :
```ruby
namespace :teacher do
  resources :subjects do
    resource :publication, only: [:create, :destroy], module: "subjects"
  end
end
```

**PR** : #34 (mergée 2026-04-12)
**Statut** : **DONE** ✓

---

### Vague 2 — Validation workflow (3 actions) — MERGÉE

**Actions migrées** :
- `Teacher::QuestionsController#validate` → `Teacher::Questions::ValidationsController#create`
- `Teacher::QuestionsController#invalidate` → `Teacher::Questions::ValidationsController#destroy`
- `Teacher::StudentsController#reset_password` → `Teacher::Students::PasswordResetsController#create`

**Modèle** : `Question#validate!/invalidate!` + `Question::InvalidTransition`

**Nouveauté vague 2** : `shallow: true` appliqué sur `resources :questions` — les URLs CRUD questions passent de `/teacher/subjects/:s/parts/:p/questions/:id` à `/teacher/questions/:id`. Conceptuel aussi sur `resources :students` (prépare vagues futures).

**PR** : #35 (mergée 2026-04-12)
**Statut** : **DONE** ✓

---

### Vague 3 — Exports et retry (4 actions) — MERGÉE

**Actions migrées** :
- `Teacher::SubjectsController#retry_extraction` → `Teacher::Subjects::ExtractionsController#create`
- `Teacher::SubjectsController#assign` (GET + PATCH) → `Teacher::Subjects::AssignmentsController#edit + #update`
- `Teacher::ClassroomsController#export_pdf` + `#export_markdown` → `Teacher::Classrooms::ExportsController#show` (2 formats via respond_to)

**Patterns nouveaux (vs vagues 1-2)** :
- `edit`/`update` sur singular resource (Assignment)
- `show` avec `respond_to` multi-format (PDF + Markdown) — MIME type markdown enregistré dans `config/initializers/mime_types.rb`
- Idempotence au niveau service : `PersistExtractedData` fait `destroy_all` des specific parts avant recréation (fixe bug de doublons au retry)

**Effet de bord vague 1** : `Teacher::Subjects::PublicationsController#create` redirect mis à jour de `assign_teacher_subject_path` vers `edit_teacher_subject_assignment_path`

**PR** : #36 (mergée 2026-04-12)
**Statut** : **DONE** ✓

---

### Vague 4 — Student bulk operations (2 actions) — MERGÉE

**Actions migrées** :
- `Teacher::StudentsController#bulk_new` → `Teacher::Classrooms::StudentImportsController#new`
- `Teacher::StudentsController#bulk_create` → `Teacher::Classrooms::StudentImportsController#create`

**Nommage retenu** : `StudentImport` (plus évocateur que `StudentBatch`, prépare un potentiel import CSV post-MVP).

**Pas de nouveau pattern** : réutilisation pure des patterns vagues 1-3. Vague la plus courte de la migration.

**PR** : #37 (mergée 2026-04-12)
**Statut** : **DONE** ✓

---

### Vague 5a — Student actions (6 actions) — MERGÉE

**Actions migrées** :
- `Student::SubjectsController#set_scope` → `Student::Subjects::ScopeSelectionsController#update`
- `Student::SubjectsController#complete_part` → `Student::Subjects::PartCompletionsController#create`
- `Student::SubjectsController#complete` → `Student::Subjects::CompletionsController#create`
- `Student::QuestionsController#reveal` → `Student::Questions::CorrectionsController#create`
- `Student::SettingsController#test_key` → `Student::Settings::ApiKeyTestsController#create`
- `Student::TutorController#activate` → `Student::Subjects::TutorActivationsController#create`

**Particularités** :
- Scope `/:access_code` préservé avec `controller:` explicite dans routes.rb (le scope ne supporte pas `module:`)
- Réutilisation pure des patterns vagues 1-4 (pas de nouveauté technique)
- Bug fix : scoping CorrectionsController étendu aux common parts via exam_session

**PR** : #38 (mergée 2026-04-13)
**Statut** : **DONE** ✓

---

### Vague 5b — Student tuteur (3 actions) — REPORTÉE

**Actions non migrées** (reportées) :
- `Student::ConversationsController#message`
- `Student::TutorController#verify_spotting`
- `Student::TutorController#skip_spotting`

**Raison du report** : le tuteur sera repensé entièrement. Ces 3 actions font partie du workflow tuteur guidé (stateful, multi-étapes). Elles seront migrées au moment du refonte du tuteur, ou conservées comme exceptions légitimes selon le design retenu.

**Statut** : **REPORTÉE** ⏸

---

## Hors scope — exceptions légitimes

**Pages statiques** (`PagesController`) : `home`, `legal`, `privacy`
Pages de navigation, pas des ressources. Gardées custom.

---

## Suivi

| Vague | PR | Statut | Actions migrées |
|-------|----|----|----|
| 1 | #34 | DONE | 2 migrées + 1 supprimée (archive orpheline) |
| 2 | #35 | DONE | 3 migrées + shallow nesting sur questions |
| 3 | #36 | DONE | 4 migrées + 3 patterns nouveaux (edit/update singular, respond_to multi-format, service idempotent) |
| 4 | #37 | DONE | 2 migrées (StudentImport) |
| 5a | #38 | DONE | 6 migrées (student actions) |
| 5b | — | REPORTÉE | 3 (workflow tuteur, sera repensé) |

**Total : 17 actions migrées + 1 supprimée. 3 restantes reportées à la refonte du tuteur.**

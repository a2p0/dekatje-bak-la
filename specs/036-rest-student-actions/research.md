# Research: REST Doctrine Wave 5a — Student Actions

**Date**: 2026-04-13 | **Branch**: `036-rest-student-actions`

## R1 — Structure scope student préservée

**Decision**: Garder `scope "/:access_code", as: :student` dans `config/routes.rb`. Les nouvelles resources sont déclarées avec `controller:` explicite.

**Rationale**: 
- Les routes student sont spéciales (access_code en premier segment, pas de namespace Rails standard)
- Convertir en `namespace :student` casserait toutes les URLs existantes (login, session, etc.)
- Déclarer avec `controller:` est verbeux mais propre
- Pattern cohérent avec les routes student existantes (`resources :conversations, controller: "student/conversations"`)

**Exemple** :
```ruby
scope "/:access_code", as: :student do
  resources :subjects, only: [:index, :show], controller: "student/subjects" do
    resource :scope_selection, only: [:update], controller: "student/subjects/scope_selections"
    resource :completion, only: [:create], controller: "student/subjects/completions"
    resource :tutor_activation, only: [:create], controller: "student/subjects/tutor_activations"
    resources :parts, only: [] do
      resource :part_completion, only: [:create], controller: "student/subjects/part_completions"
    end
    resources :questions, only: [:show], controller: "student/questions" do
      resource :correction, only: [:create], controller: "student/questions/corrections"
    end
  end
  
  # settings reste non-resource à cause de la structure actuelle
  get  "/settings",          to: "student/settings#show",     as: :settings
  patch "/settings",         to: "student/settings#update"
  # test_key migré vers :
  resource :api_key_test, only: [:create], path: "settings/api_key_test",
    controller: "student/settings/api_key_tests"
end
```

**Note sur settings** : actuellement settings n'est pas une resource (c'est un singleton custom avec `get/patch`). Pour test_key on peut déclarer une resource imbriquée manuellement avec `path:`.

## R2 — Controllers : héritent tous de Student::BaseController

**Decision**: Tous les 6 nouveaux controllers héritent de `Student::BaseController`, qui fournit déjà :
- `current_student` (via session[:student_id])
- `@classroom` (via `set_classroom_from_url`)
- `require_student_auth` (before_action)

**Pattern type pour ScopeSelectionsController** :
```ruby
class Student::Subjects::ScopeSelectionsController < Student::BaseController
  before_action :set_subject

  def update
    session_record = current_student.student_sessions.find_by!(subject: @subject)
    session_record.update!(part_filter: params[:part_filter], scope_selected: true)
    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id)
  end

  private

  def set_subject
    @subject = @classroom.subjects.published.find(params[:subject_id])
  end
end
```

## R3 — Logique métier : préservée via copy-paste

**Decision**: Chaque nouveau controller reprend la logique exacte de l'action ancienne. Pas de refactoring profond.

**Rationale**:
- Cohérent avec vagues 1-4
- Le `complete_part` a une logique de redirection complexe (30+ lignes) — la copier verbatim évite les régressions
- Les méthodes modèle (`mark_answered!`, `mark_part_completed!`, etc.) sont déjà bien encapsulées

## R4 — Authorization : `classroom.subjects.published.find` strict

**Decision**: Utiliser `find` (qui raise `ActiveRecord::RecordNotFound` → 404) au lieu de `find_by` + redirect.

**Rationale**: Cohérent avec le pattern vagues 1-4. Rails gère le 404 globalement.

## R5 — Compat JS pour test_key

**Problème**: Le `settings_controller.js` construit l'URL manuellement :
```js
window.location.pathname.replace("/settings", "/settings/test_key")
```

**Decision**: Mettre à jour la ligne JS pour la nouvelle URL :
```js
window.location.pathname.replace("/settings", "/settings/api_key_test")
```

**Rationale**: Changement minimal. Pas de helper Rails côté JS dans ce projet.

## R6 — ScopeSelection : `update` (pas `create`)

**Decision**: `resource :scope_selection, only: [:update]` — une session a UNE scope_selection (pas une collection).

**Pattern** : `PATCH /:access_code/subjects/:subject_id/scope_selection`

**Rationale**:
- Sémantique correcte : on modifie le périmètre existant, on ne le crée pas
- Le `StudentSession.part_filter` existe déjà (default `:both`)
- Pas de `new`/`edit` séparé — le formulaire est déjà affiché inline dans `_scope_selection.html.erb`
- Pattern cohérent avec Assignment (vague 3 : `only: [:edit, :update]` mais ici pas de vue `edit` séparée)

## R7 — Reveal → Correction (create)

**Decision**: `POST /:access_code/subjects/:subject_id/questions/:id/correction` — création d'un événement "correction révélée".

**Rationale**:
- L'action ajoute un record dans `progression[question_id]["answered"] = true`
- Sémantiquement : création d'un événement (révélation = acte)
- Turbo Stream response conservée (pattern Hotwire existant)

## R8 — TutorActivation : idempotent

**Decision**: `POST /:access_code/subjects/:subject_id/tutor_activation`. Action idempotente : si déjà tutored, ne fait rien, retourne OK.

**Rationale**:
- Comportement actuel préservé : `unless session_record.tutored?`
- Sémantique REST : "je demande l'activation du tuteur" → OK même si déjà activé

## R9 — ApiKeyTest : ressource transitoire

**Decision**: `POST /:access_code/settings/api_key_test` — ressource sans persistence (validation en temps réel).

**Rationale**: 
- Pattern cohérent avec `Export#show` (vague 3) qui ne persiste rien non plus
- Turbo Stream response préservée
- Rescue `ValidateStudentApiKey::InvalidApiKeyError` reste dans le controller

**Note** : la route nécessite une déclaration manuelle car `settings` n'est pas une resource standard dans le scope student actuel.

## R10 — Migration des views (8 occurrences)

| Fichier | Ligne | Avant | Après |
|---------|-------|-------|-------|
| `_scope_selection.html.erb` | 10 | `student_set_scope_subject_path` | `student_subject_scope_selection_path` (method: :patch) |
| `_scope_selection.html.erb` | 28 | idem | idem |
| `_scope_selection.html.erb` | 46 | idem | idem |
| `questions/show.html.erb` | 154 | `student_reveal_question_path` | `student_subject_question_correction_path` (method: :post) |
| `questions/show.html.erb` | 188 | `student_complete_part_subject_path` | `student_subject_part_part_completion_path` (method: :post) |
| `questions/show.html.erb` | 228 | idem | idem |
| `_correction_button.html.erb` | 5 | `student_reveal_question_path` | `student_subject_question_correction_path` |
| `_unanswered_questions.html.erb` | 22 | `student_complete_subject_path` | `student_subject_completion_path` (method: :post) |
| `_tutor_banner.html.erb` | 16 | `student_tutor_activate_path` | `student_subject_tutor_activation_path` (method: :post) |
| `settings_controller.js` | 47 | `"/settings", "/settings/test_key"` | `"/settings", "/settings/api_key_test"` |

## R11 — Tests

**Decision**:
- 6 nouveaux request specs (un par controller) couvrant les scenarios happy path + authorization
- Feature specs existants : `student_subject_workflow_spec`, `student_scope_selection_spec`, `student_correction_reveal_spec`, `student_api_key_configuration_spec`, `student_tutor_activation_spec` — doivent passer sans modification (labels UI stables)

## Résumé

| Item | Décision |
|------|---------|
| Scope student | Préservé avec `controller:` explicite |
| BaseController | Inchangé, tous les nouveaux controllers en héritent |
| Logique métier | Copy-paste depuis actions actuelles |
| JS settings | 1 ligne modifiée |
| Tests | 6 nouveaux request specs + feature specs inchangés |
| Nouveaux patterns | Aucun (réutilisation pure vagues 1-4) |

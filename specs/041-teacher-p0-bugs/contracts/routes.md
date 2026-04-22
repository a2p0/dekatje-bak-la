# REST Contract — Routes modifiées

**Feature** : Teacher P0 bug fixes
**Branch** : `041-teacher-p0-bugs`
**Date** : 2026-04-16

## Une seule route modifiée

### `DELETE /teacher/subjects/:id` (NOUVEAU, US2)

**Doctrine REST** : soft-delete d'une ressource Subject via `destroy`, cohérent avec la doctrine REST du projet (cf. `project_rest_doctrine_migration.md`).

**Route Rails** (à ajouter dans `config/routes.rb:17`) :

```diff
- resources :subjects, only: [ :index, :new, :create, :show ] do
+ resources :subjects, only: [ :index, :new, :create, :show, :destroy ] do
```

**Controller action** (à ajouter dans `app/controllers/teacher/subjects_controller.rb`) :

```ruby
before_action :set_subject, only: [ :show, :destroy ]

def destroy
  @subject.update!(discarded_at: Time.current)
  redirect_to teacher_subjects_path,
              notice: "Sujet « #{@subject.exam_session&.title || 'sans titre'} » archivé."
end

private

def set_subject
  @subject = current_teacher.subjects.kept.find_by(id: params[:id])
  redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
end
```

**Note importante** : `set_subject` doit ajouter le scope `.kept` pour que toute tentative d'action sur un sujet déjà archivé retourne 404 (via redirect "Sujet introuvable"). Cela change le comportement de `show` aussi — à valider : un enseignant qui tape l'URL d'un sujet archivé ne peut plus le voir. **Décision** : acceptable dans le scope α. Si besoin ultérieur d'une vue "archivés", on enlèvera `.kept` sur `show` et on gèrera séparément dans une nouvelle feature.

**Réponses attendues** :

| Scénario | Status HTTP | Redirection | Flash |
|---|---|---|---|
| Sujet actif possédé par l'enseignant, confirmé | 303 See Other | `/teacher/subjects` | notice = "Sujet « … » archivé." |
| Sujet non trouvé (mauvais ID, déjà archivé, pas propriétaire) | 303 See Other | `/teacher/subjects` | alert = "Sujet introuvable." |
| Utilisateur non authentifié | 302 Found | `/users/sign_in` (Devise) | — |

**Idempotence** : oui. Un second `DELETE` sur le même sujet retourne "Sujet introuvable." (le scope `.kept` filtre).

**Autorisation** : via scope `current_teacher.subjects` (déjà en place dans le controller).

**CSRF** : via `protect_from_forgery` standard Rails (déjà actif).

**Format** : HTML uniquement (pas de JSON ni Turbo Stream). Turbo gère l'UX via `turbo_confirm`.

---

## Routes INCHANGÉES mais réutilisées

### `GET /teacher/classrooms/:classroom_id/export(.:format)` (US1)

**Pas de modification.** Route existante (`config/routes.rb:12`, `resource :export, only: [ :show ], module: "classrooms"`) réutilisée par le nouveau bouton dans le bandeau d'identifiants de `classrooms/show.html.erb`.

Helper path : `teacher_classroom_export_path(@classroom, format: :pdf)`.

---

## Routes non concernées

### Aucune route pour US3 (extraction feedback)

US3 modifie uniquement le partial `_extraction_status.html.erb`. Aucune nouvelle route, aucune modification du controller `Teacher::Subjects::ExtractionsController` (qui gère `POST /teacher/subjects/:subject_id/extraction` pour relancer une extraction).

---

## Résumé

| Route | Verbe | Status | Modification |
|---|---|---|---|
| `/teacher/subjects/:id` | `DELETE` | NOUVEAU | Ajout action `destroy` |
| `/teacher/classrooms/:classroom_id/export(.pdf)` | `GET` | EXISTANT | Réutilisation |
| `/teacher/subjects/:subject_id/extraction` | `POST` | EXISTANT | Inchangé |

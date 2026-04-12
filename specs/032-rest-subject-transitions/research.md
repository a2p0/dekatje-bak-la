# Research: REST Doctrine — Subject State Transitions

**Date**: 2026-04-12 | **Branch**: `032-rest-subject-transitions`

## R1 — Cible de la transition unpublish

**Decision**: Garder le comportement actuel — `unpublish` ramène le sujet en `:draft`, pas en `:pending_validation`.

**Rationale**: Le comportement existant est : `publish: draft → published`, `unpublish: published → draft`. L'enum `pending_validation` existe mais n'est setté nulle part dans le code actuel (dead code à auditer plus tard, pas dans le scope de cette vague). La spec initiale mentionnait `pending_validation` comme cible d'unpublish par erreur — à corriger.

**Alternatives considered**:
- Changer unpublish pour aller vers `pending_validation` : changement de comportement métier, hors scope REST migration
- Supprimer `pending_validation` de l'enum : hors scope, peut casser des données existantes

**Action**: Corriger le spec (scenarios user stories 2) pour refléter `:draft`.

## R2 — Archive : route fantôme

**Decision**: **Supprimer** l'action archive du scope de cette vague. Elle n'est pas exposée dans les vues actuelles, donc aucune valeur utilisateur immédiate.

**Rationale**: 
- La route `PATCH /teacher/subjects/:id/archive` existe
- Le controller action existe
- **Aucune vue ne l'appelle**
- Aucun feature spec ne la teste
- L'ajouter comme ressource REST sans l'exposer = code mort supplémentaire

**Alternatives considered**:
- **Inclure** : ajouter un bouton "Archiver" dans une vue → élargit le scope (UX design, feature spec à créer)
- **Supprimer complètement** : tentant mais hors scope REST migration, on le fera si vraiment pas utilisé

**Action**: 
1. Retirer User Story 3 (Archive) et FR-003 de la spec
2. Retirer la route `archive` de `config/routes.rb` (nettoyage au passage)
3. Retirer la méthode `archive` du controller
4. Mettre à jour SC-001 pour ne concerner que publication

Si l'archive redevient nécessaire plus tard, elle sera ajoutée directement en format REST (`Teacher::Subjects::ArchivesController#create`) dans une vague future ou une PR dédiée.

## R3 — Règle métier publication

**Decision**: Préserver la règle actuelle : publication nécessite `publishable?` (≥1 question validée). Ajouter aussi une garde d'état : on ne republie pas un sujet déjà publié.

**Rationale**: 
- Actuellement, `publish` ne check pas l'état courant — appeler publish sur un sujet déjà published succède silencieusement (bug latent)
- Le nouveau pattern avec méthode métier `Subject#publish!` doit lever `InvalidTransition` si déjà publié

**Règles finales** :
- `publish!` : requiert non-published ET `publishable?` → sinon raise `InvalidTransition`
- `unpublish!` : requiert published → sinon raise `InvalidTransition`

## R4 — Exception custom : où la placer

**Decision**: Définir `Subject::InvalidTransition < StandardError` dans `app/models/subject.rb` (classe imbriquée).

**Rationale**: Scope naturel : l'exception appartient au modèle qui définit les transitions. Accessible via `Subject::InvalidTransition` depuis le controller. Pattern cohérent avec `ResolveApiKey::NoApiKeyError` déjà en place dans le projet.

**Alternatives considered**:
- Classe top-level `InvalidTransitionError` : trop générique, conflit potentiel avec d'autres modèles ayant des transitions (Question en vague 2)
- Module dédié `StateTransitions` : overkill pour 1 modèle

## R5 — Controller pour Publication

**Decision**: `Teacher::Subjects::PublicationsController` dans `app/controllers/teacher/subjects/publications_controller.rb`.

**Rationale**: Namespace `Teacher::Subjects::` reflète le parent resource. Suit le pattern `teacher/subjects/publications_controller.rb` analogue aux routes Rails imbriquées. La doctrine rest-doctrine.md montre cet exemple : `PublicationsController#create/destroy`.

**Routes** :
```ruby
namespace :teacher do
  resources :subjects, only: [:index, :new, :create, :show] do
    member do
      post :retry_extraction
      get  :assign
      patch :assign
    end
    resource :publication, only: [:create, :destroy], module: "subjects"
  end
end
```

**Explication `module: "subjects"`** : sans ça, Rails chercherait `Teacher::PublicationsController`. Avec `module: "subjects"`, il cherche `Teacher::Subjects::PublicationsController`.

**URLs générées** :
- `POST /teacher/subjects/:subject_id/publication` → create (publish)
- `DELETE /teacher/subjects/:subject_id/publication` → destroy (unpublish)
- Helpers : `teacher_subject_publication_path(subject)` pour les 2 verbes

**Alternatives considered**:
- `Teacher::PublicationsController` top-level : moins descriptif, noms de helper moins clairs (`teacher_publication_path` au lieu de `teacher_subject_publication_path`)

## R6 — Pattern de réponse

**Decision**: `respond_to` avec HTML (redirect + flash) et Turbo Stream (partial replace). Le `rescue_from Subject::InvalidTransition` gère le cas d'erreur.

**Pattern** :
```ruby
class Teacher::Subjects::PublicationsController < Teacher::BaseController
  before_action :set_subject
  rescue_from Subject::InvalidTransition, with: :invalid_transition

  def create
    @subject.publish!
    respond_to do |format|
      format.html        { redirect_to assign_teacher_subject_path(@subject), notice: "Sujet publié. Assignez-le maintenant aux classes." }
      format.turbo_stream
    end
  end

  def destroy
    @subject.unpublish!
    respond_to do |format|
      format.html        { redirect_to teacher_subject_path(@subject), notice: "Sujet dépublié." }
      format.turbo_stream
    end
  end

  private

  def set_subject
    @subject = current_user.subjects.find(params[:subject_id])
  end

  def invalid_transition(exception)
    redirect_to teacher_subject_path(@subject), alert: exception.message
  end
end
```

**Rationale**: 
- `redirect_to assign_teacher_subject_path` après publish préserve le comportement actuel (guide l'enseignant vers l'assignation)
- Autorisation via `current_user.subjects.find(...)` : scope implicite, raise `RecordNotFound` si pas propriétaire (géré par ApplicationController)

## R7 — Turbo Stream views

**Decision**: Créer `create.turbo_stream.erb` et `destroy.turbo_stream.erb` qui remplacent le partial `teacher/subjects/_stats` (où les boutons publish/unpublish vivent).

**Rationale**: Le partial `_stats.html.erb` affiche les boutons d'action selon l'état. Le remplacer force le re-render avec le bon bouton visible. Alternative : remplacer plusieurs targets (bouton + statut + flash) mais c'est overkill pour cette phase.

**Fichiers** :
- `app/views/teacher/subjects/publications/create.turbo_stream.erb` : `turbo_stream.replace "subject_stats_#{@subject.id}"` + update flash
- `app/views/teacher/subjects/publications/destroy.turbo_stream.erb` : idem

## R8 — Feature specs existants à mettre à jour

**Decision**: Mettre à jour `spec/features/teacher_question_validation_spec.rb` (2 contextes concernés : publication + dépublication). Ajouter un nouveau request spec pour les nouveaux controllers.

**Rationale**: 
- Feature specs actuels testent par label de bouton ("Publier le sujet", "Dépublier") — pas par helper d'URL, donc **résilient au renommage des helpers**
- Un request spec couvrira les cas invalides (transitions impossibles, non-propriétaire) plus efficacement que feature spec

**Actions**:
1. `spec/features/teacher_question_validation_spec.rb` : faire passer après migration sans modification (si les labels restent)
2. Créer `spec/requests/teacher/subjects/publications_spec.rb` avec :
   - POST publish happy path
   - POST publish sans question validée → alert
   - POST publish sujet déjà publié → alert (nouveau comportement, bug latent fixé)
   - DELETE unpublish happy path
   - DELETE unpublish sujet non publié → alert
   - Non-propriétaire → 404

## R9 — Migration de boutons dans les vues

**Decision**: Remplacer les 2 `button_to publish_teacher_subject_path` et `button_to unpublish_teacher_subject_path` par des appels aux nouveaux helpers.

**Fichiers** :
- `app/views/teacher/subjects/_stats.html.erb` (lignes 25-29, 40-44)
- `app/views/teacher/parts/show.html.erb` (lignes 62-66)

**Avant** :
```erb
<%= button_to "Publier le sujet", publish_teacher_subject_path(subject), method: :patch, ... %>
<%= button_to "Dépublier", unpublish_teacher_subject_path(subject), method: :patch, ... %>
```

**Après** :
```erb
<%= button_to "Publier le sujet", teacher_subject_publication_path(subject), method: :post, ... %>
<%= button_to "Dépublier", teacher_subject_publication_path(subject), method: :delete, ... %>
```

## Résumé des corrections à apporter à la spec

| Item | Action |
|------|--------|
| US2 scenario 1 | Remplacer "pending_validation" par "draft" |
| US3 (Archive) | **Supprimer** — hors scope |
| FR-003 | **Supprimer** — hors scope archive |
| Edge cases archive | **Supprimer** |
| SC-001 | Simplifier : plus d'URL archive |
| Assumptions | Ajouter : nettoyage de la route `archive` orpheline |

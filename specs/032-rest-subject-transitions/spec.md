# Feature Specification: REST Doctrine — Subject Publication

**Feature Branch**: `032-rest-subject-transitions`  
**Created**: 2026-04-12  
**Status**: Draft (ajusté post-research)  
**Input**: Vague 1 de la migration vers la doctrine CRUD-only Rails. Migrer les 2 actions custom `publish`/`unpublish` de `Teacher::SubjectsController` vers un controller dédié `Publications`. Nettoyer au passage la route `archive` orpheline (jamais utilisée dans les vues).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Publier un sujet validé (Priority: P1)

En tant qu'enseignant, je veux publier un sujet prêt (au moins une question validée) afin qu'il devienne accessible aux élèves de mes classes.

**Why this priority**: La publication est l'action la plus fréquente du workflow. Sans elle, les sujets n'atteignent pas les élèves. C'est le chemin doré du teacher workflow.

**Independent Test**: Créer un sujet non publié (statut `draft` ou `pending_validation`) avec au moins 1 question validée, cliquer "Publier" depuis la page du sujet, vérifier que le statut passe à `published` et que la page est mise à jour.

**Acceptance Scenarios**:

1. **Given** un sujet non publié (`draft` ou `pending_validation`) avec ≥1 question validée, **When** l'enseignant clique "Publier", **Then** le statut passe à `published` et un message de confirmation s'affiche
2. **Given** un sujet non publié sans question validée, **When** l'enseignant tente de publier, **Then** la publication est refusée avec un message explicite
3. **Given** un sujet déjà publié, **When** l'enseignant recharge la page, **Then** le bouton "Publier" n'est plus affiché (remplacé par "Dépublier")

---

### User Story 2 — Dépublier un sujet publié (Priority: P1)

En tant qu'enseignant, je veux dépublier un sujet précédemment publié afin de le retirer temporairement de l'accès des élèves (pour correction, mise à jour, etc.).

**Why this priority**: La dépublication permet de corriger des erreurs constatées après publication sans perdre les questions. C'est l'inverse symétrique de la publication.

**Independent Test**: Dépublier un sujet en statut `published`, vérifier que le statut repasse à `draft` et que les élèves n'y ont plus accès.

**Acceptance Scenarios**:

1. **Given** un sujet en statut `published`, **When** l'enseignant clique "Dépublier", **Then** le statut repasse à `draft` et les élèves n'y ont plus accès
2. **Given** un sujet non publié (draft, pending_validation, archived), **When** l'enseignant tente de dépublier, **Then** l'action est refusée avec un message explicite

---

### Edge Cases

- Que se passe-t-il si une transition est demandée depuis un état invalide (ex: publier un sujet déjà publié, ou dépublier un draft) ? Un message d'erreur clair, sans exception serveur visible à l'utilisateur.
- Que se passe-t-il si deux utilisateurs publient simultanément le même sujet ? La deuxième tentative doit échouer proprement si l'état a déjà changé (race condition).
- Que se passe-t-il si l'enseignant n'est pas le propriétaire du sujet ? L'action doit être rejetée (autorisation existante préservée).
- Les URLs de l'ancien schéma (`/teacher/subjects/:id/publish`) doivent-elles être maintenues pendant une transition ? Non, renommage complet en une seule PR.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT permettre à un enseignant propriétaire de publier un sujet non publié (statut `draft` ou `pending_validation`) contenant au moins une question validée
- **FR-002**: Système DOIT permettre à un enseignant propriétaire de dépublier un sujet en statut `published`, ramenant le sujet à `draft`
- **FR-003**: Système DOIT refuser toute transition d'état invalide avec un message d'erreur utilisateur clair en français
- **FR-004**: Système DOIT afficher le bouton adapté au statut courant lors du rendu de la page (Publier si non publié, Dépublier si publié) et mettre à jour le bouton après transition via Turbo Stream
- **FR-005**: Système DOIT préserver l'autorisation actuelle : seul le propriétaire du sujet peut effectuer les transitions
- **FR-006**: Système DOIT mettre à jour l'affichage de la page sans rechargement complet après chaque transition
- **FR-007**: Système DOIT exposer la transition publish/unpublish comme une ressource unique `Publication` (création/suppression)
- **FR-008**: Système DOIT supprimer la route `archive` orpheline (non utilisée dans les vues) pour nettoyer le code mort

### Key Entities

- **Subject** : modèle existant avec champ `status` (enum: draft, pending_validation, published, archived)
- **Publication** : resource conceptuelle représentant l'état "publié" d'un sujet — création = publier, suppression = dépublier

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les URL exposées suivent le pattern REST : `POST /teacher/subjects/:id/publication` (publier), `DELETE /teacher/subjects/:id/publication` (dépublier)
- **SC-002**: Aucune action `publish`/`unpublish`/`archive` ne subsiste dans `Teacher::SubjectsController`
- **SC-003**: Les transitions invalides affichent un message utilisateur sans exception serveur (erreur 500)
- **SC-004**: Les feature specs existantes touchant la publication/dépublication passent après migration (aucun feature spec n'existe pour archive)
- **SC-005**: Le flow end-to-end enseignant (upload → validation → publication → consultation élève) reste fonctionnel
- **SC-006**: La logique métier des transitions est testable indépendamment du controller (méthodes de modèle avec tests unitaires)

## Assumptions

- Le modèle `Subject` conserve son enum `status` actuel (draft, pending_validation, published, archived)
- Les règles métier actuelles sont préservées : publication requiert ≥1 question validée, unpublish ramène à draft
- Nouvelle règle ajoutée : `publish!` refuse si sujet déjà publié (fixe un bug latent de l'implémentation actuelle)
- L'autorisation existante (propriétaire uniquement) est préservée
- Les routes student qui listent les sujets publiés continuent de fonctionner (`.published` scope)
- Aucune migration de données requise — seule la surface d'API change
- Les URLs anciennes ne sont pas maintenues (pas de compatibilité arrière, migration en une PR)
- L'enum `pending_validation` et `archived` ne sont pas utilisés dans cette vague (code mort potentiel, audit à part)

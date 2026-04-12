# Feature Specification: REST Doctrine — Question Validation + Student Password Reset

**Feature Branch**: `033-rest-validation-password`  
**Created**: 2026-04-12  
**Status**: Draft  
**Input**: Vague 2 de la migration vers la doctrine CRUD-only Rails. Migrer `validate`/`invalidate` de `Teacher::QuestionsController` vers `Teacher::Questions::ValidationsController#create/destroy`. Migrer `reset_password` de `Teacher::StudentsController` vers `Teacher::Students::PasswordResetsController#create`. Appliquer `shallow: true` sur les questions et students pour aplatir les routes profondes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Valider une question extraite (Priority: P1)

En tant qu'enseignant, je veux valider une question extraite d'un PDF afin de confirmer qu'elle est correcte et prête à être publiée aux élèves.

**Why this priority**: La validation est l'étape centrale du workflow enseignant — sans elle, aucune question n'atteint les élèves (la publication du sujet requiert ≥1 question validée). C'est l'action la plus fréquente de la phase d'édition.

**Independent Test**: Créer une question en statut `draft`, cliquer "Valider" depuis la page du part, vérifier que le statut passe à `validated` et que le bouton change d'apparence.

**Acceptance Scenarios**:

1. **Given** une question en statut `draft`, **When** l'enseignant clique "Valider", **Then** le statut passe à `validated` et le bouton "Valider" est remplacé par un bouton "Invalider"
2. **Given** une question déjà `validated`, **When** l'enseignant clique "Invalider", **Then** le statut repasse à `draft` et le bouton inverse s'affiche
3. **Given** une transition invalide (ex: invalider une question `draft`), **When** l'enseignant tente l'action, **Then** un message d'erreur clair s'affiche sans casser la page

---

### User Story 2 — Invalider une question validée (Priority: P1)

En tant qu'enseignant, je veux pouvoir invalider une question précédemment validée afin de la corriger ou la retirer du cycle de validation sans la supprimer.

**Why this priority**: Symétrique de la validation. Permet de corriger sans destruction — essentiel puisque les questions validées peuvent bloquer/débloquer la publication d'un sujet.

**Independent Test**: Invalider une question `validated`, vérifier que le statut repasse à `draft` et que le bouton "Valider" réapparaît.

**Acceptance Scenarios**:

1. **Given** une question en statut `validated`, **When** l'enseignant clique "Invalider", **Then** le statut repasse à `draft`
2. **Given** une question en statut `draft`, **When** l'enseignant tente d'invalider, **Then** l'action est refusée avec un message explicite

---

### User Story 3 — Réinitialiser le mot de passe d'un élève (Priority: P1)

En tant qu'enseignant, je veux pouvoir réinitialiser le mot de passe d'un élève afin de lui fournir un nouveau mot de passe quand il a perdu l'ancien (conformément au modèle RGPD : aucun email, reset par l'enseignant uniquement).

**Why this priority**: Action critique pour la continuité du service élève. Sans elle, un élève perdu reste bloqué hors de son espace. Conforme à la constitution : "Réinitialisation mot de passe par l'enseignant uniquement".

**Independent Test**: Cliquer "Réinitialiser le mot de passe" sur un élève, vérifier qu'un nouveau mot de passe est généré et affiché à l'enseignant pour qu'il le transmette.

**Acceptance Scenarios**:

1. **Given** un élève existant, **When** l'enseignant clique "Réinitialiser le mot de passe", **Then** un nouveau mot de passe est généré, stocké (hashé) et affiché à l'enseignant
2. **Given** l'enseignant n'est pas propriétaire de la classe de l'élève, **When** il tente la réinitialisation, **Then** l'action est rejetée (autorisation préservée)

---

### Edge Cases

- Que se passe-t-il si un utilisateur clique deux fois rapidement sur "Valider" ? La deuxième requête doit échouer proprement via le guard d'état (déjà validated).
- Que se passe-t-il si l'extraction IA change le statut entre l'affichage et l'action ? Le modèle vérifie l'état courant au moment de la transition.
- Que se passe-t-il si les URLs sont bookmarkées par un enseignant (ancien vs nouveau schéma) ? Pas de compatibilité arrière — migration en une seule PR.
- Pour le password reset : le nouveau mot de passe est visible une seule fois à l'écran (aucun stockage en clair). Si l'enseignant rafraîchit la page, il doit relancer la réinitialisation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT permettre à un enseignant propriétaire de valider une question en statut `draft` de ses sujets, amenant le statut à `validated`. Refuser si la question est déjà `validated` (nouvelle règle, fixe un bug latent de double-validation silencieuse).
- **FR-002**: Système DOIT permettre à un enseignant propriétaire d'invalider une question en statut `validated` de ses sujets, ramenant le statut à `draft`. Refuser si la question est déjà `draft` (nouvelle règle).
- **FR-003**: Système DOIT permettre à un enseignant propriétaire de réinitialiser le mot de passe d'un élève d'une de ses classes
- **FR-004**: Système DOIT refuser toute transition de question invalide avec un message utilisateur clair en français (ex: valider une question déjà validée, invalider une draft)
- **FR-005**: Système DOIT afficher dynamiquement le bouton adapté au statut courant de la question (Valider / Invalider)
- **FR-006**: Système DOIT préserver l'autorisation actuelle : seul le propriétaire du sujet peut valider/invalider ses questions, seul le propriétaire de la classe peut réinitialiser un mot de passe d'élève
- **FR-007**: Les transitions de question (valider/invalider) DOIVENT mettre à jour l'affichage sans rechargement complet (Turbo Stream). La réinitialisation de mot de passe utilise un redirect vers la page de la classe (comportement actuel préservé — les credentials générés s'affichent après le rechargement).
- **FR-008**: Système DOIT exposer la paire validate/invalidate comme une ressource unique `Validation` (création/suppression)
- **FR-009**: Système DOIT exposer la réinitialisation de mot de passe comme une ressource `PasswordReset` (création uniquement, car non réversible)
- **FR-010**: Système DOIT générer un nouveau mot de passe aléatoire stocké en forme hashée lors de la réinitialisation, et l'afficher en clair à l'enseignant une seule fois
- **FR-011**: Système DOIT aplatir les routes imbriquées profondes via `shallow: true` :
  - Sur `resources :parts` et `resources :questions` (sous subjects) pour que les URLs membre de parts et questions soient top-level
  - Sur `resources :students` (sous classrooms) pour cohérence doctrinale et préparation des futures vagues (show/edit/update/destroy students)
  - Les URLs collection (index, create, new) restent imbriquées sous leur parent

### Key Entities

- **Question** : modèle existant avec champ `status` (enum: draft, validated)
- **Student** : modèle existant avec `password_digest` (bcrypt, pas d'email)
- **Validation** : resource conceptuelle représentant l'état "validated" d'une question — création = valider, suppression = invalider
- **PasswordReset** : resource conceptuelle représentant l'événement de réinitialisation de mot de passe d'un élève — création uniquement (pas d'historique, le nouveau mot de passe écrase l'ancien)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les URL exposées suivent le pattern REST : `POST /teacher/questions/:id/validation` (valider), `DELETE /teacher/questions/:id/validation` (invalider), `POST /teacher/classrooms/:classroom_id/students/:student_id/password_reset` (reset) — avec shallow sur questions et students
- **SC-002**: Aucune action `validate`/`invalidate` ne subsiste dans `Teacher::QuestionsController`
- **SC-003**: Aucune action `reset_password` ne subsiste dans `Teacher::StudentsController`
- **SC-004**: Les transitions invalides (question déjà validée, question draft qu'on tente d'invalider) affichent un message utilisateur sans exception serveur (pas d'erreur 500)
- **SC-005**: Les feature specs existantes touchant la validation de questions et le reset password passent après migration
- **SC-006**: Le flow end-to-end enseignant (upload → extraction → validation → publication) reste fonctionnel
- **SC-007**: La logique métier de `Question#validate!/invalidate!` est testable indépendamment du controller (tests unitaires sur le modèle)
- **SC-008**: Les URLs pour les actions member de questions sont aplaties (2 niveaux max) grâce à `shallow: true`, tout en conservant les routes collection imbriquées (création sous le parent)

## Assumptions

- Le modèle `Question` conserve son enum `status` actuel (draft, validated)
- Les règles métier actuelles sont préservées : toggle simple entre draft et validated, sans validation supplémentaire
- Nouvelle règle ajoutée : `validate!` refuse si déjà validée, `invalidate!` refuse si déjà draft (cohérent avec pattern vague 1, évite doubles transitions silencieuses)
- L'autorisation existante est préservée (via scoping `current_user.subjects` et `current_user.classrooms`)
- Le service `ResetStudentPassword` existe déjà (vague 1 PR #32) et est réutilisé par `PasswordResetsController#create`
- Les URLs anciennes ne sont pas maintenues — migration en une PR
- Les `shallow: true` routes affectent aussi les actions CRUD de questions/students (update, destroy pour questions ; show, edit, update, destroy pour students) qui deviennent top-level — acceptable et même souhaitable

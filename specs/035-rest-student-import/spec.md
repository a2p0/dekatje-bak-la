# Feature Specification: REST Doctrine — Student Bulk Import

**Feature Branch**: `035-rest-student-import`  
**Created**: 2026-04-12  
**Status**: Draft  
**Input**: Vague 4 de la migration REST doctrine. Migrer les 2 actions `bulk_new` et `bulk_create` de `Teacher::StudentsController` vers un controller dédié `Teacher::Classrooms::StudentImportsController`, exposé sous la resource `:student_import`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Accéder au formulaire d'import en lot (Priority: P1)

En tant qu'enseignant, je veux accéder à un formulaire dédié pour importer plusieurs élèves à la fois afin d'ajouter rapidement toute une classe en début d'année plutôt que saisir chaque élève individuellement.

**Why this priority**: Action à haute valeur en début d'année scolaire (septembre). Sans elle, l'enseignant doit créer ~30 élèves un par un. C'est le chemin doré pour la constitution d'une classe.

**Independent Test**: Cliquer sur "Ajout en lot" depuis la page d'une classe, vérifier que le formulaire s'affiche avec un textarea pour saisir les élèves.

**Acceptance Scenarios**:

1. **Given** une classe existante, **When** l'enseignant clique "Ajout en lot", **Then** le formulaire d'import s'affiche avec un textarea
2. **Given** un enseignant non propriétaire de la classe, **When** il tente d'accéder au formulaire, **Then** l'accès est refusé (autorisation préservée)

---

### User Story 2 — Importer plusieurs élèves en une soumission (Priority: P1)

En tant qu'enseignant, je veux saisir une liste d'élèves (prénom + nom par ligne) dans un textarea et les créer tous d'un coup avec des identifiants générés automatiquement.

**Why this priority**: Action métier centrale. Sans elle, la création en lot ne serait pas possible.

**Independent Test**: Soumettre un textarea avec 3 lignes "Prénom Nom", vérifier que 3 élèves sont créés avec identifiants uniques et que la page redirige vers la classe avec les identifiants affichés.

**Acceptance Scenarios**:

1. **Given** un textarea rempli avec plusieurs lignes "Prénom Nom", **When** l'enseignant soumet, **Then** les élèves sont créés, leurs identifiants générés, et la page redirige vers la classe avec les nouveaux identifiants affichés
2. **Given** une ligne au format invalide (ex: "Prénom" sans nom), **When** soumission, **Then** un message d'erreur identifie la ligne problématique, les autres lignes valides sont traitées normalement
3. **Given** un textarea vide, **When** soumission, **Then** l'action est traitée comme une opération vide (zéro élève ajouté, pas d'erreur serveur)

---

### Edge Cases

- Que se passe-t-il si un élève avec le même prénom+nom existe déjà dans la classe ? Le service existant `GenerateStudentCredentials` gère les doublons en ajoutant un suffixe à l'username (ex: `marie.dupont2`).
- Que se passe-t-il si certaines lignes ont plus de 2 mots ? La logique existante parse "premier mot = prénom, reste = nom" (via `split(" ", 2)`).
- Que se passe-t-il si l'enseignant soumet 100+ élèves d'un coup ? Pas de limite imposée (workflow typique = une classe entière, ~30). Timeout serveur géré par les défauts Rails.
- Que se passe-t-il si les anciennes URLs (`/bulk_new`, `/bulk_create`) sont utilisées (bookmarks) ? Elles n'existent plus → 404 standard.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT permettre à un enseignant propriétaire d'accéder à un formulaire d'import en lot pour une de ses classes
- **FR-002**: Système DOIT traiter la soumission d'une liste d'élèves (un par ligne, format "Prénom Nom") en créant les enregistrements et générant les identifiants automatiquement
- **FR-003**: Système DOIT afficher les identifiants générés à l'enseignant après un import réussi, afin qu'il puisse les transmettre aux élèves
- **FR-004**: Système DOIT signaler les lignes au format invalide sans bloquer le traitement des lignes valides
- **FR-005**: Système DOIT préserver l'autorisation actuelle : seul le propriétaire de la classe peut importer des élèves
- **FR-006**: Système DOIT exposer l'import en lot comme une ressource REST dédiée `StudentImport` (actions `new` + `create`)
- **FR-007**: Système DOIT préserver la logique métier actuelle de parsing et de génération d'identifiants (via le service `GenerateStudentCredentials`)

### Key Entities

- **StudentImport** : resource conceptuelle représentant une opération d'import en lot d'élèves dans une classe (1 formulaire → 1 soumission → N élèves créés). Pas persistée en base — c'est un workflow, pas une entité.
- **Student** : modèle existant, créé par l'import

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les URLs exposées suivent le pattern REST : `GET /teacher/classrooms/:classroom_id/student_import/new` (formulaire) et `POST /teacher/classrooms/:classroom_id/student_import` (soumission)
- **SC-002**: Aucune action `bulk_new` ou `bulk_create` ne subsiste dans `Teacher::StudentsController`
- **SC-003**: Les feature specs existantes touchant l'ajout en lot passent après migration
- **SC-004**: Le flow end-to-end enseignant (création classe → ajout en lot → affichage identifiants → distribution) reste fonctionnel
- **SC-005**: Un import de 30 élèves complète en moins de 5 secondes (workflow classe standard)

## Assumptions

- La logique métier actuelle est préservée : parsing textarea, appel à `GenerateStudentCredentials`, stockage des credentials en session flash
- Le service `GenerateStudentCredentials` (refactoré vague 1 rails-conventions) retourne un Struct `Result(:username, :password)` — logique d'appel inchangée
- La vue existante `teacher/students/bulk_new.html.erb` contient un formulaire simple (textarea + bouton). Le déplacement vers `teacher/classrooms/student_imports/new.html.erb` ne change que l'URL du `form_with`.
- Les URLs anciennes ne sont pas maintenues (pas de compatibilité arrière, migration en une PR)
- Aucune nouveauté métier : c'est du renommage + repositionnement REST pur
- L'import CSV réel (post-MVP, backlog) n'est PAS dans le scope de cette vague

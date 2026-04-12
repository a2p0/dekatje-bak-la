# Feature Specification: REST Doctrine — Extraction Retry, Assignment, Classroom Exports

**Feature Branch**: `034-rest-extraction-assign-export`  
**Created**: 2026-04-12  
**Status**: Draft  
**Input**: Vague 3 de la migration REST doctrine. Migrer 4 actions custom vers des controllers RESTful dédiés : `retry_extraction` et `assign` de `Teacher::SubjectsController`, `export_pdf` et `export_markdown` de `Teacher::ClassroomsController`. Corriger au passage un bug latent : les specific parts orphelines créées lors d'un retry après échec partiel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Relancer une extraction échouée (Priority: P1)

En tant qu'enseignant, je veux relancer l'extraction IA d'un sujet dont l'extraction initiale a échoué afin de récupérer les questions sans devoir supprimer et recréer le sujet.

**Why this priority**: Action de récupération critique. Sans elle, un échec d'extraction (timeout API, JSON malformé, limite quota) oblige à recommencer depuis zéro. Fréquente en pratique avec les PDF complexes.

**Independent Test**: Créer un sujet avec `ExtractionJob` en statut `failed`, cliquer "Relancer l'extraction" depuis la page du sujet, vérifier que le job repart et que les specific parts orphelines (s'il y en avait eu de l'ancien échec) sont nettoyées avant la nouvelle extraction.

**Acceptance Scenarios**:

1. **Given** un sujet dont l'extraction a échoué, **When** l'enseignant clique "Relancer l'extraction", **Then** le job passe à `processing` et l'enseignant est redirigé vers la page du sujet avec un message de confirmation
2. **Given** un sujet avec extraction en cours (statut `processing`), **When** l'enseignant tente de relancer, **Then** l'action est refusée avec un message explicite
3. **Given** un sujet dont l'extraction a partiellement créé des specific parts avant d'échouer, **When** l'extraction est relancée, **Then** les anciennes specific parts sont supprimées avant la nouvelle extraction (pas de doublons)
4. **Given** un sujet où les common parts existent (partagées via exam_session), **When** l'extraction est relancée, **Then** les common parts sont préservées (non touchées par le cleanup)

---

### User Story 2 — Assigner un sujet publié à des classes (Priority: P1)

En tant qu'enseignant, je veux pouvoir cocher les classes auxquelles un sujet publié sera visible, afin de contrôler l'accès des élèves par classe.

**Why this priority**: Action critique post-publication. Sans assignation, même un sujet publié n'est vu par aucun élève. C'est l'étape finale du workflow de mise à disposition.

**Independent Test**: Ouvrir la page d'assignation d'un sujet, cocher/décocher des classes, soumettre le formulaire, vérifier que les élèves des classes sélectionnées peuvent voir le sujet.

**Acceptance Scenarios**:

1. **Given** un sujet et une liste de classes de l'enseignant, **When** l'enseignant ouvre le formulaire d'assignation, **Then** il voit toutes ses classes avec les assignations actuelles pré-cochées
2. **Given** un formulaire d'assignation modifié, **When** l'enseignant soumet, **Then** les associations classroom_subjects sont mises à jour et un message de confirmation s'affiche
3. **Given** un enseignant non propriétaire du sujet, **When** il tente d'ouvrir l'assignation, **Then** l'action est rejetée (autorisation préservée)

---

### User Story 3 — Exporter les identifiants d'une classe en PDF (Priority: P2)

En tant qu'enseignant, je veux télécharger les identifiants de connexion de ma classe au format PDF imprimable afin de distribuer les fiches papier aux élèves.

**Why this priority**: Workflow standard de distribution. Conformément au modèle RGPD (aucun email élève, transmission papier), c'est le moyen principal de communiquer les mots de passe.

**Independent Test**: Cliquer "Exporter en PDF" depuis la page d'une classe, vérifier qu'un fichier PDF contenant les identifiants se télécharge.

**Acceptance Scenarios**:

1. **Given** une classe avec au moins un élève, **When** l'enseignant demande l'export PDF, **Then** un fichier PDF est téléchargé contenant les fiches de connexion
2. **Given** un enseignant non propriétaire de la classe, **When** il tente l'export, **Then** l'action est rejetée

---

### User Story 4 — Exporter les identifiants d'une classe en Markdown (Priority: P2)

En tant qu'enseignant, je veux télécharger les identifiants de connexion de ma classe au format Markdown afin de les importer dans mes notes ou outils personnels.

**Why this priority**: Alternative au PDF pour les enseignants qui utilisent Obsidian, Notion, etc. Format texte lisible et éditable.

**Independent Test**: Cliquer "Exporter en Markdown" depuis la page d'une classe, vérifier qu'un fichier .md contenant les identifiants se télécharge.

**Acceptance Scenarios**:

1. **Given** une classe avec au moins un élève, **When** l'enseignant demande l'export Markdown, **Then** un fichier Markdown est téléchargé contenant les fiches de connexion

---

### Edge Cases

- Que se passe-t-il si l'enseignant double-clique sur "Relancer l'extraction" pendant qu'un job est en cours ? La deuxième tentative doit être refusée (guard d'état `processing`).
- Que se passe-t-il si le formulaire d'assignation est soumis sans aucune classe cochée ? L'assignation est vidée (le sujet n'est plus visible par aucun élève).
- Que se passe-t-il si la classe à exporter est vide (zéro élève) ? L'export est tout de même généré (document vide ou avec message "Aucun élève").
- Que se passe-t-il si les anciennes URLs (`/teacher/subjects/:id/retry_extraction`, `/teacher/subjects/:id/assign`, `/teacher/classrooms/:id/export_pdf`) sont utilisées (bookmarks) ? Elles n'existent plus — comportement 404 standard.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT permettre à un enseignant propriétaire de relancer l'extraction d'un sujet dont l'extraction est en état `failed`
- **FR-002**: Système DOIT refuser la relance d'une extraction qui n'est pas en état `failed` (c'est-à-dire : `pending`, `processing`, ou `done`) avec un message explicite. Seul l'état `failed` autorise la relance.
- **FR-003**: Système DOIT nettoyer les specific parts du sujet avant de relancer l'extraction (suppression cascadée des questions et answers via `dependent: :destroy`). Les common parts partagées via exam_session NE DOIVENT PAS être supprimées.
- **FR-004**: Système DOIT permettre à un enseignant propriétaire d'afficher le formulaire d'assignation de ses sujets aux classes
- **FR-005**: Système DOIT permettre à un enseignant propriétaire de mettre à jour les assignations classroom-subject via soumission du formulaire
- **FR-006**: Système DOIT permettre à un enseignant propriétaire de télécharger les identifiants de ses classes au format PDF
- **FR-007**: Système DOIT permettre à un enseignant propriétaire de télécharger les identifiants de ses classes au format Markdown
- **FR-008**: Système DOIT préserver l'autorisation actuelle : seul le propriétaire du sujet/classe peut effectuer ces actions
- **FR-009**: Système DOIT exposer chaque action comme une ressource REST dédiée :
  - `Extraction` sur Subject (création)
  - `Assignment` sur Subject (édition + mise à jour)
  - `Export` sur Classroom (show avec multiples formats)

### Key Entities

- **ExtractionJob** : modèle existant avec statut (pending, processing, done, failed) — UN record par sujet (has_one)
- **Subject** : existant avec transitions (publication vague 1) — ajouter règle "extraction non-retryable si en processing/done"
- **ClassroomSubject** : jointure existante, modifiée via collection_ids sur le formulaire
- **Extraction** : resource conceptuelle — création = "je veux relancer/redémarrer l'extraction"
- **Assignment** : resource conceptuelle — 1 assignment par sujet (singular), édition/mise à jour
- **Export** : resource conceptuelle sur Classroom — 1 export par classroom avec format variable (PDF/Markdown)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les URL exposées suivent le pattern REST :
  - `POST /teacher/subjects/:subject_id/extraction` (relancer)
  - `GET /teacher/subjects/:subject_id/assignment/edit` (afficher formulaire)
  - `PATCH /teacher/subjects/:subject_id/assignment` (soumettre)
  - `GET /teacher/classrooms/:id/export.pdf` et `.markdown` (télécharger)
- **SC-002**: Aucune action `retry_extraction`, `assign`, `export_pdf`, `export_markdown` ne subsiste dans `Teacher::SubjectsController` ou `Teacher::ClassroomsController`
- **SC-003**: Une extraction relancée après un échec partiel NE produit PAS de doublons de specific parts
- **SC-004**: Une extraction relancée ne touche PAS aux common parts du sujet (partagées via exam_session)
- **SC-005**: Les feature specs existantes touchant assignation et extraction passent après migration
- **SC-006**: Le flow end-to-end enseignant (upload → extraction → [retry si besoin] → validation → publication → assignation → export identifiants) reste fonctionnel
- **SC-007**: Les fichiers PDF et Markdown téléchargés ont les bons Content-Type et Content-Disposition pour forcer le download

## Assumptions

- Les services `ExportStudentCredentialsPdf` et `ExportStudentCredentialsMarkdown` existants sont réutilisés tels quels (conformes au pattern `self.call → new.call` depuis la vague 1 de rails-conventions)
- Le service `PersistExtractedData` sera modifié pour être idempotent : `@subject.parts.specific.destroy_all` en début de `#call`. Cela affecte aussi le cas "première extraction" mais sans effet (collection vide).
- Le modèle `ExtractionJob` garde son enum `status` actuel (pending, processing, done, failed)
- La vue existante `subjects/assign.html.erb` peut être soit renommée en `assignment/edit.html.erb`, soit extraite en partial réutilisable. Choix laissé à la phase de planning.
- Les URLs anciennes ne sont pas maintenues (pas de compatibilité arrière, migration en une PR)
- Les boutons existants (`button_to retry_extraction_...`, `link_to assign_...`, `button_to export_pdf_...`) seront migrés vers les nouveaux helpers

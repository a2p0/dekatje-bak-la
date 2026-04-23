# Feature Specification: Refonte Flow Tuteur

**Feature Branch**: `044-tutor-flow-refonte`
**Created**: 2026-04-22
**Last amended**: 2026-04-23 — pivot activation depuis page question (plus depuis page sujet)
**Status**: Draft

## Pivot 2026-04-23

L'activation du tuteur est déplacée de la page sujet vers la page question.
Raison architecturale : le drawer tuteur n'existe que sur `questions/show` — dispatcher un événement depuis `subjects/show` tirait dans le vide.

**Ce qui change :**
- US1 (activation page sujet + drawer auto-open) → remplacée par le nouveau comportement ci-dessous
- US2 (bouton "Commencer" unique) → conservée, simplifiée (T012 déjà fait)
- US3 (badge intro-question) → conservée, intégrée au flux d'activation

**Dépréciation UX renommage "Tutorat"** : noté, différé post-MVP.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Indicateur tuteur sur la page sujet (Priority: P1)

La page sujet affiche l'état du tuteur pour l'élève, sans bouton d'activation. L'activation se fait depuis la page question.

**Why this priority**: L'élève doit savoir si le tuteur est disponible avant de choisir sa question.

**Acceptance Scenarios**:

1. **Given** un élève sans clé API et sans free mode activé, **When** il arrive sur la page sujet, **Then** il voit "Tuteur indisponible — [Paramétrer]" avec un lien vers les paramètres.
2. **Given** un élève avec clé API (ou free mode) et aucune conversation active sur ce sujet, **When** il arrive sur la page sujet, **Then** il voit "Tuteur disponible".
3. **Given** un élève avec une conversation active sur ce sujet (ou `use_personal_key` activé par défaut), **When** il arrive sur la page sujet, **Then** il voit "Tuteur actif".
4. **Given** n'importe quel état, **When** la page sujet s'affiche, **Then** aucun bouton "Activer le tuteur" n'est présent.

---

### User Story 2 — Bouton "Commencer" unique et navigation (Priority: P1)

L'élève dispose d'un seul bouton "Commencer" sur la page sujet, pointant vers la première question non traitée.

**Independent Test**: Un seul bouton "Commencer" visible, lien correct selon progression.

**Acceptance Scenarios**:

1. **Given** n'importe quel état tuteur, **When** la page sujet s'affiche, **Then** un seul bouton "Commencer" est visible (le bouton dans `_tutor_activated` a déjà été supprimé en Phase 2).
2. **Given** un élève sans progression, **When** il clique sur [Commencer], **Then** il est redirigé vers Q1.1 (ou A.1 pour sujet spécifique seul).
3. **Given** un élève ayant traité Q1.1 et Q1.2, **When** il clique sur [Commencer], **Then** il est redirigé vers Q1.3.

---

### User Story 3 — Activation du tuteur et messages depuis la page question (Priority: P1)

Sur la page question, l'élève clique sur le bouton "Tutorat". Le drawer s'ouvre immédiatement avec un indicateur de chargement, puis les messages apparaissent : message d'accueil (si première activation sur ce sujet) + message intro-question (si première visite de cette question).

**Why this priority**: C'est le nouveau point d'entrée unique du tuteur. Toute la valeur de la feature est ici.

**Independent Test**: Cliquer sur "Tutorat" depuis une page question → drawer s'ouvre immédiatement → messages arrivent.

**Acceptance Scenarios**:

1. **Given** un élève avec tuteur disponible, aucune conversation sur ce sujet, première visite de Q1.1, **When** il clique sur [Tutorat], **Then** le drawer s'ouvre immédiatement (spinner visible), la conversation est créée, le message d'accueil apparaît, puis le message intro-question Q1.1 apparaît.
2. **Given** un élève avec une conversation déjà active, première visite de Q2.3, **When** il clique sur [Tutorat] sur Q2.3, **Then** le drawer s'ouvre, pas de nouveau message d'accueil, le message intro-question Q2.3 apparaît.
3. **Given** un élève revenant sur Q1.1 (déjà visitée, intro vue), **When** il clique sur [Tutorat], **Then** le drawer s'ouvre avec l'historique de la conversation — pas de nouveau message intro.
4. **Given** un élève sans clé API et sans free mode, **When** il arrive sur la page question, **Then** le bouton "Tutorat" n'est pas affiché (comportement existant conservé).
5. **Given** un élève avec tuteur disponible, **When** il arrive sur une page question avec intro déjà générée mais pas encore vue, **Then** un badge/indicateur est visible sur le bouton "Tutorat" sans ouvrir le drawer.

---

### Edge Cases

- **LLM timeout** sur `BuildWelcomeMessage` → fallback statique, drawer reste ouvert, l'élève peut continuer.
- **LLM timeout** sur `BuildIntroMessage` (zéro LLM — déterministe) → N/A.
- **`structured_correction` NULL** pour une question → message intro utilise `correction_text` comme fallback, sinon formulation générique.
- **Aucune clé API** → bouton "Tutorat" absent, indicateur "Indisponible — Paramétrer" sur page sujet.
- **Toutes les questions traitées** → bouton "Commencer" pointe vers page de complétion (comportement existant inchangé).
- **`data_hints` et `structured_correction` absents** → message intro utilise formulation générique ("cherche dans l'énoncé et les documents techniques").
- **Double clic** sur [Tutorat] → idempotent, pas de double conversation ni de double message.

---

## Requirements *(mandatory)*

### Functional Requirements

**Indicateur page sujet :**

- **FR-001**: La page sujet DOIT afficher un indicateur d'état tuteur : "Tuteur indisponible — [Paramétrer]" / "Tuteur disponible" / "Tuteur actif". Aucun bouton d'activation.
- **FR-002**: "Tuteur actif" = conversation active sur ce sujet OU `student.use_personal_key` = true avec clé présente.
- **FR-003**: "Tuteur indisponible" = pas de clé API élève ET pas de free mode activé par l'enseignant.
- **FR-004**: "Tuteur disponible" = clé disponible (perso ou free mode) mais aucune conversation active sur ce sujet.

**Activation depuis page question :**

- **FR-005**: Le clic sur [Tutorat] DOIT ouvrir le drawer immédiatement avec un indicateur de chargement (spinner ou "...").
- **FR-006**: Si aucune conversation n'existe pour ce sujet, `conversations#create` DOIT être appelé, la conversation créée, et `BuildWelcomeMessage` appelé (si `!welcome_sent`).
- **FR-007**: `BuildIntroMessage` DOIT être appelé si l'intro pour cette question n'a pas encore été générée (`!intro_seen` dans `QuestionState`).
- **FR-008**: Les messages d'accueil et intro-question SONT envoyés de façon séquentielle — welcome d'abord, intro ensuite.
- **FR-009**: Le message d'accueil NE DOIT PAS se ré-afficher si la conversation existe déjà (`welcome_sent = true`).
- **FR-010**: L'intro-question NE DOIT PAS se ré-afficher si déjà générée pour cette question (`intro_seen = true`).

**Messages — contenu :**

- **FR-011**: Message d'accueil template : "Bonjour ! Tu vas travailler sur [SUJET] ([N_QUESTIONS] questions). [PHRASE_ENCOURAGEMENT]" — `PHRASE_ENCOURAGEMENT` générée par LLM (courte, non-sollicitante), fallback statique si erreur.
- **FR-012**: Message intro-question template : "Question [N] — [LABEL]. Pour progresser, cherche [DATA_HINT ou CONCEPT]. Je suis là si tu as besoin d'aide — sinon, lance-toi."
- **FR-013**: `BuildIntroMessage` est déterministe (zéro LLM). Priorité hint : `data_hints.first` > `structured_correction["input_data"].first` > formulation générique.
- **FR-014**: Les messages d'accueil et intro-question NE DOIVENT PAS solliciter de réponse de l'élève (contrainte `phase_rank`).

**Badge intro-question :**

- **FR-015**: Un badge visuel DOIT être affiché sur le bouton "Tutorat" si un message intro a été généré mais pas encore vu (`intro_seen = false`).
- **FR-016**: Le badge DOIT disparaître après ouverture du drawer (appel `PATCH mark_intro_seen`).

**Bouton Commencer :**

- **FR-017**: Un seul bouton "Commencer" sur la page sujet, pointant vers la première question non traitée du périmètre actif.

### Key Entities

- **Conversation** : liée à (student, subject). `welcome_sent` dans `TutorState`. Un seul objet Conversation par (student, subject).
- **Message** : `kind` enum — `normal`, `welcome`, `intro`. Rôle `assistant`.
- **TutorState** : `welcome_sent` (bool), `question_states[question_id].intro_seen` (bool).

---

## Success Criteria *(mandatory)*

- **SC-001**: Zéro doublon de bouton "Commencer" sur la page sujet.
- **SC-002**: Le drawer s'ouvre en moins d'une seconde après le clic sur [Tutorat] (hors génération LLM).
- **SC-003**: Le message d'accueil s'affiche dans le drawer dans les 5 secondes (LLM inclus).
- **SC-004**: Le message intro-question ne contient aucune valeur finale — validé par sim (non-divulgation ≥ baseline 4.07).
- **SC-005**: Zéro régression `phase_rank` : l'élève peut poster sa réponse au premier tour sans être bloqué.
- **SC-006**: Le badge est visible sur le bouton "Tutorat" sans ouvrir le drawer.
- **SC-007**: En cas d'échec LLM welcome, fallback visible et flow non interrompu.

## Assumptions

- `conversations#create` reste le point d'entrée HTTP — son déclencheur change (bouton question, pas sujet).
- La "première question non traitée" s'appuie sur `StudentSession#progression` existant.
- Les messages welcome/intro ne sont pas streamés token par token (réponse complète).
- La contrainte `phase_rank` est validée par sim après implémentation, pas par guard actif.

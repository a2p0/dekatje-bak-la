# Feature Specification: Refonte Flow Tuteur

**Feature Branch**: `044-tutor-flow-refonte`
**Created**: 2026-04-22
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Activation du tuteur et accueil automatique (Priority: P1)

Un élève arrive sur la page d'un sujet et active le tuteur. Dès l'activation, le drawer s'ouvre automatiquement et un message d'accueil personnalisé s'affiche, sans qu'il n'ait à faire d'autre action.

**Why this priority**: C'est le point d'entrée principal du tuteur. Si l'accueil ne se déclenche pas, toute la valeur de la feature est perdue.

**Independent Test**: Activer le tuteur sur un sujet, vérifier que le drawer s'ouvre et qu'un message d'accueil apparaît dans le drawer.

**Acceptance Scenarios**:

1. **Given** un élève authentifié sur la page d'un sujet, tuteur non encore activé, **When** il clique sur [Activer le tuteur], **Then** le drawer s'ouvre automatiquement et un message d'accueil s'affiche dans le drawer.
2. **Given** un élève sur la page d'un sujet avec le tuteur déjà activé (clé API élève ou mode free), **When** la page se charge, **Then** le drawer s'ouvre automatiquement et un message d'accueil s'affiche (si pas encore vu pour ce sujet).
3. **Given** un élève avec le tuteur activé par défaut (free mode classe), **When** il arrive sur la page sujet, **Then** le drawer s'ouvre et le message d'accueil apparaît sans qu'il ait eu à cliquer sur "Activer".
4. **Given** un élève qui revient sur une page sujet après avoir déjà reçu le message d'accueil, **When** la page se charge, **Then** le drawer reste fermé (pas de re-déclenchement intrusif).

---

### User Story 2 — Bouton "Commencer" unique et navigation vers la première question non traitée (Priority: P1)

L'élève dispose d'un seul bouton "Commencer" en bas de la page sujet. Ce bouton l'emmène directement vers la première question non traitée du sujet.

**Why this priority**: Le doublon actuel est un bug visible qui crée de la confusion. La navigation vers la première question non traitée est essentielle en cas de reprise.

**Independent Test**: Vérifier qu'un seul bouton "Commencer" est présent sur la page, et qu'il pointe vers la bonne question selon la progression.

**Acceptance Scenarios**:

1. **Given** un élève sur la page sujet avec le tuteur activé, **When** la page s'affiche, **Then** un seul bouton "Commencer" est visible (en bas de page uniquement — plus de doublon dans la bannière d'activation).
2. **Given** un élève qui n'a traité aucune question, **When** il clique sur [Commencer], **Then** il est redirigé vers la question 1.1 (ou A.1 pour un sujet spécifique seul).
3. **Given** un élève qui a déjà traité Q1.1 et Q1.2, **When** il clique sur [Commencer], **Then** il est redirigé vers Q1.3 (première question non traitée).
4. **Given** un sujet spécifique seul (pas de partie commune), **When** l'élève clique sur [Commencer], **Then** il est redirigé vers A.1.

---

### User Story 3 — Message intro-question à l'ouverture du drawer sur la page question (Priority: P2)

Sur la page d'une question, l'élève voit un badge signalant qu'un message du tuteur l'attend. En ouvrant le drawer, le message intro-question est déjà présent — il contextualise la question sans donner la réponse.

**Why this priority**: Ajoute de la valeur pédagogique à chaque question sans être intrusif (le drawer reste fermé par défaut). Dépend de la P1 fonctionnelle mais peut être spécifié et testé séparément.

**Independent Test**: Charger une page question avec tuteur actif, vérifier le badge, ouvrir le drawer, vérifier la présence et le contenu du message intro.

**Acceptance Scenarios**:

1. **Given** un élève avec tuteur actif sur une page question, **When** la page se charge, **Then** le drawer est fermé et un badge signale qu'un message attend.
2. **Given** un élève sur une page question avec badge visible, **When** il ouvre le drawer, **Then** le message intro-question est déjà présent (pré-généré).
3. **Given** un message intro-question, **When** l'élève l'ouvre, **Then** le message mentionne la question et un indice sur où trouver les données — sans donner aucune valeur finale.
4. **Given** un élève qui a déjà ouvert le drawer pour cette question, **When** il revient sur la page, **Then** le badge est absent (message déjà vu) et le drawer reste fermé.
5. **Given** un élève arrivant sur une page question avec une réponse déjà formulée, **When** la page se charge, **Then** il peut saisir et envoyer sa réponse directement sans interagir avec le drawer.

---

### Edge Cases

- Que se passe-t-il si la génération LLM du message d'accueil échoue (timeout, erreur provider) ? → Fallback sur un message statique par défaut, sans erreur visible.
- Que se passe-t-il si `structured_correction` est NULL pour une question ? → Le message intro utilise `correction_text` comme fallback pour extraire le concept clé.
- Que se passe-t-il si l'élève n'a pas de clé API et que le free mode n'est pas activé ? → Le drawer tuteur n'est pas affiché ; le banner "Activer le tuteur" n'apparaît pas.
- Que se passe-t-il si toutes les questions sont déjà traitées et que l'élève clique sur [Commencer] ? → Navigation vers la page de complétion (comportement existant inchangé).
- Que se passe-t-il si `data_hints` et `structured_correction` sont tous deux absents ? → Le message intro utilise une formulation générique ("cherche dans l'énoncé et les documents techniques").

## Requirements *(mandatory)*

### Functional Requirements

**Activation et accueil :**

- **FR-001**: À l'activation du tuteur (clic sur le bouton ou tuteur déjà actif au chargement de page), le drawer DOIT s'ouvrir automatiquement.
- **FR-002**: À la première ouverture du drawer sur un sujet donné, un message d'accueil DOIT être envoyé automatiquement dans la conversation.
- **FR-003**: Le message d'accueil NE DOIT PAS solliciter de réponse de l'élève — il est encourageant et ne pose pas de question. Un élève arrivant avec une réponse formulée peut la poster directement sans interaction préalable.
- **FR-004**: Le message d'accueil NE DOIT PAS se ré-afficher si l'élève revient sur la page sujet après l'avoir déjà reçu.

**Bouton Commencer :**

- **FR-005**: Un seul bouton "Commencer" DOIT exister sur la page sujet, positionné en bas de page. Le bouton présent dans la bannière d'activation DOIT être supprimé.
- **FR-006**: Le bouton "Commencer" DOIT rediriger vers la première question non traitée du périmètre actif (common+specific ou specific seul selon la sélection de scope).
- **FR-007**: Pour un sujet commun ou complet, la première question non traitée DOIT être Q1.1 (ou la suivante si déjà traitée). Pour un sujet spécifique seul, ce DOIT être A.1.

**Intro-question :**

- **FR-008**: Sur chaque page question avec tuteur actif, un indicateur visuel (badge) DOIT signaler qu'un message intro-question attend dans le drawer.
- **FR-009**: Le drawer DOIT rester fermé par défaut sur la page question. L'élève choisit de l'ouvrir.
- **FR-010**: À l'ouverture du drawer sur une page question, le message intro-question DOIT être déjà présent dans la conversation.
- **FR-011**: Le message intro-question NE DOIT PAS révéler de valeur finale (résultat, choix correct). Il DOIT pointer vers une donnée d'entrée ou un concept clé.
- **FR-012**: Le message intro-question NE DOIT PAS solliciter de réponse. L'élève peut ignorer le drawer et répondre directement.
- **FR-013**: Si `data_hints` est disponible, le message intro DOIT utiliser le premier data_hint. Sinon, il DOIT utiliser le premier élément de `structured_correction.input_data` si disponible, sinon une formulation générique.

**Messages — forme slot-fill :**

- **FR-014**: Le message d'accueil DOIT suivre le template : "Bonjour ! Tu vas travailler sur [SUJET] ([N_QUESTIONS] questions). [PHRASE_ENCOURAGEMENT]" où `PHRASE_ENCOURAGEMENT` est une phrase générée par LLM, non-sollicitante.
- **FR-015**: Le message intro-question DOIT suivre le template : "Question [N] — [QUESTION_LABEL]. Pour progresser, cherche [DATA_HINT ou CONCEPT]. Je suis là si tu as besoin d'aide — sinon, lance-toi." Les slots fixes sont remplis côté serveur.
- **FR-016**: En cas d'échec LLM pour la génération de `PHRASE_ENCOURAGEMENT`, un message de fallback statique DOIT être utilisé sans erreur visible pour l'élève.

### Key Entities

- **Conversation** : Conversation tuteur liée à un couple (student_session, question). Le message d'accueil est rattaché à la conversation de la première question (ou à un objet dédié — à décider en phase plan).
- **Message** : Message dans une conversation (rôle assistant ou user). Les messages d'accueil et intro-question sont de rôle `assistant`, générés automatiquement.
- **StudentSession** : Trace la progression de l'élève et si le message d'accueil a déjà été envoyé pour un sujet donné.
- **TutorState** : État du tuteur. Étendu pour tracer le flag `welcome_sent` par sujet.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'élève ne voit jamais deux boutons "Commencer" simultanément sur la page sujet.
- **SC-002**: Le drawer s'ouvre en moins d'une seconde après le clic sur "Activer le tuteur" (hors génération LLM).
- **SC-003**: Le message d'accueil s'affiche dans le drawer dans les 5 secondes suivant l'activation (génération LLM incluse).
- **SC-004**: Le message intro-question ne contient aucune valeur finale — validé par sim tuteur (non-divulgation ≥ baseline 4.07).
- **SC-005**: Zéro régression sur le critère `phase_rank` en sim : un élève arrivant avec une réponse formulée peut la poster au premier tour sans être bloqué par une question du tuteur.
- **SC-006**: Le badge/indicateur sur la page question est visible sans ouvrir le drawer.
- **SC-007**: En cas d'échec LLM, l'élève voit un message de fallback et peut continuer normalement sans interruption du flow.

## Assumptions

- Le tuteur n'est visible que pour les élèves éligibles (clé API perso ou free mode activé par l'enseignant) — comportement existant conservé sans modification.
- Le tracking "message d'accueil déjà vu" s'appuie sur `TutorState` ou un flag dans `StudentSession#tutor_state` JSONB — choix définitif en phase plan.
- La "conversation sujet" (pour le message d'accueil) peut être rattachée à la première question du sujet ou à un objet `Conversation` de type `subject_welcome` — à décider en phase plan.
- Les messages d'accueil et intro-question ne sont pas streamés token par token (messages courts, réponse complète attendue).
- La logique de "première question non traitée" s'appuie sur `StudentSession#progression` existant.
- La contrainte phase_rank (greeting non-sollicitant) est implémentée comme règle de prompt côté LLM, pas comme guard actif — validée par sim après implémentation.
- La génération LLM du slot `PHRASE_ENCOURAGEMENT` utilise un appel séparé léger (pas le pipeline tuteur complet).

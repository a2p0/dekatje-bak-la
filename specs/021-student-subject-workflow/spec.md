# Feature Specification: Workflow sujet complet élève

**Feature Branch**: `021-student-subject-workflow`  
**Created**: 2026-04-08  
**Status**: Draft  
**Input**: Refonte du parcours élève lors d'un sujet complet (commune + spécifique). Wireframe de référence : `wireframes/workflow_sujet_complet.txt`

## Clarifications

### Session 2026-04-08

- Q: Comment la partie terminée est-elle affichée sur la page du sujet ? → A: Marquée visuellement (coche/badge "Terminé") mais reste accessible pour y revenir
- Q: Que se passe-t-il si l'élève revient sur un sujet déjà terminé ? → A: Accès libre à la liste des parties + questions (mode relecture/révision), pas de re-déclenchement du workflow de fin

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Liste des parties avec objectifs et séparation commune/spécifique (Priority: P1)

L'élève arrive sur la page d'accueil du sujet (après sélection du scope "Sujet complet"). Il voit la liste de toutes les parties, regroupées visuellement en deux sections : **PARTIE COMMUNE** et **PARTIE SPÉCIFIQUE**. Chaque partie affiche son numéro, son titre, son objectif (`objective_text`), et le nombre de questions. Un bouton "Commencer" est placé **en bas** de la liste.

**Why this priority**: C'est la première chose que l'élève voit. Sans cette vue structurée, il ne comprend pas l'organisation du sujet. C'est le point d'entrée de tout le workflow.

**Independent Test**: Peut être testé en accédant à la page sujet avec un sujet complet et en vérifiant que les parties sont regroupées et que les objectifs sont affichés.

**Acceptance Scenarios**:

1. **Given** un sujet avec des parties communes et spécifiques, **When** l'élève accède à la page du sujet (scope "complet"), **Then** les parties sont affichées en deux groupes avec en-têtes "PARTIE COMMUNE" et "PARTIE SPÉCIFIQUE"
2. **Given** une partie avec un `objective_text`, **When** la liste est affichée, **Then** l'objectif apparaît sous le titre de la partie
3. **Given** la liste des parties, **When** l'élève regarde la page, **Then** le bouton "Commencer" est en bas de la liste (pas en haut)
4. **Given** un scope "commun uniquement", **When** l'élève accède à la page, **Then** seules les parties communes sont affichées sans en-tête de section (pas de regroupement nécessaire)
5. **Given** un scope "spécifique uniquement", **When** l'élève accède à la page, **Then** seules les parties spécifiques sont affichées sans en-tête de section

---

### User Story 2 - Navigation séquentielle avec transitions entre parties (Priority: P1)

L'élève parcourt les questions séquentiellement. À la fin de chaque partie (dernière question), le bouton de navigation affiche "Fin de la partie" au lieu de "Question suivante". Ce bouton ramène à la page du sujet. Quand toutes les parties du scope ont été terminées (boutons "Fin de partie" cliqués), le parcours passe à la phase de révision.

**Why this priority**: Sans transitions claires entre parties, l'élève perd le fil de sa progression. La fin de partie est un moment charnière du workflow.

**Independent Test**: Naviguer jusqu'à la dernière question d'une partie et vérifier que le bouton affiche "Fin de la partie" et redirige correctement.

**Acceptance Scenarios**:

1. **Given** l'élève est sur la dernière question d'une partie, **When** il voit le bouton de navigation, **Then** le bouton affiche "Fin de la partie" (pas "Question suivante")
2. **Given** l'élève clique "Fin de la partie" sur la partie commune, **When** il est redirigé, **Then** il revient à la page du sujet
3. **Given** l'élève a terminé la partie commune mais pas la spécifique, **When** il revient à la page du sujet, **Then** il peut commencer la partie spécifique
4. **Given** un scope "commun uniquement", **When** l'élève atteint la dernière question, **Then** le bouton affiche "Fin de la partie" et le workflow se conclut (pas de partie spécifique attendue)

---

### User Story 3 - Mise en situation spécifique entre les deux parties (Priority: P2)

Quand l'élève commence la partie spécifique (après avoir terminé ou non la partie commune), un écran intermédiaire affiche la mise en situation spécifique (`specific_presentation`) avant la première question spécifique. Un bouton "Commencer" en bas permet de lancer les questions spécifiques.

**Why this priority**: La mise en situation spécifique contextualise les questions de spécialité. C'est important mais secondaire par rapport à la structure de navigation.

**Independent Test**: Terminer la partie commune, revenir à la page du sujet, lancer la partie spécifique et vérifier que la mise en situation spécifique s'affiche.

**Acceptance Scenarios**:

1. **Given** l'élève lance la partie spécifique, **When** la mise en situation spécifique existe (`specific_presentation` non vide), **Then** un écran intermédiaire affiche ce texte avec un bouton "Commencer" en bas
2. **Given** un sujet sans `specific_presentation`, **When** l'élève lance la partie spécifique, **Then** l'écran intermédiaire est sauté et l'élève arrive directement à la première question
3. **Given** un scope "spécifique uniquement", **When** l'élève accède au sujet pour la première fois, **Then** la mise en situation spécifique est affichée (si elle existe) avant les questions

---

### User Story 4 - Page des questions non répondues (Priority: P2)

Quand l'élève a cliqué "Fin de la partie" pour toutes les parties de son scope, s'il reste des questions non vues ou non répondues, une page récapitulative liste ces questions. Chaque question affiche son numéro et son titre, avec un bouton "Revenir à cette question". Un bouton "Terminer le sujet" permet de conclure sans tout répondre.

**Why this priority**: Cette page évite que l'élève oublie des questions et lui donne une vue d'ensemble de ce qu'il reste à faire.

**Independent Test**: Terminer les deux parties sans répondre à certaines questions, puis vérifier que la page des questions non répondues s'affiche.

**Acceptance Scenarios**:

1. **Given** l'élève a cliqué "Fin de la partie" pour toutes les parties, **When** il reste des questions non répondues, **Then** la page des questions non répondues s'affiche
2. **Given** la page des questions non répondues, **When** l'élève clique "Revenir à cette question", **Then** il est redirigé directement vers cette question
3. **Given** l'élève est sur une question accédée depuis la page des questions non répondues, **When** il clique "Question suivante", **Then** il est redirigé vers la page des questions non répondues (pas la question suivante dans l'ordre normal)
4. **Given** la page des questions non répondues, **When** l'élève clique "Terminer le sujet", **Then** le sujet est considéré comme terminé et la page de félicitations s'affiche
5. **Given** l'élève a cliqué "Fin de la partie" pour toutes les parties, **When** toutes les questions ont été répondues, **Then** la page de félicitations s'affiche directement (pas la page des questions non répondues)

---

### User Story 5 - Page de félicitations (Priority: P3)

Quand l'élève a terminé le sujet (toutes les questions répondues, ou clic sur "Terminer le sujet"), une page ou popup "Bravo !!" s'affiche avec un bouton "Revenir aux sujets".

**Why this priority**: C'est la cérémonie de fin. Important pour la motivation mais pas bloquant pour le workflow principal.

**Independent Test**: Terminer toutes les questions d'un sujet et vérifier que la page "Bravo" s'affiche.

**Acceptance Scenarios**:

1. **Given** toutes les questions ont été répondues (ou "Terminer le sujet" cliqué), **When** l'élève termine, **Then** une page "Bravo !!" s'affiche
2. **Given** la page de félicitations, **When** l'élève clique "Revenir aux sujets", **Then** il est redirigé vers la liste des sujets

---

### User Story 6 - Placement cohérent des boutons d'action (Priority: P3)

Tous les boutons d'action principaux (Commencer, Continuer, Fin de la partie, Terminer le sujet) sont placés **en bas** de leur section respective, de manière cohérente sur toutes les pages du parcours élève.

**Why this priority**: La cohérence de placement améliore l'ergonomie mais n'ajoute pas de fonctionnalité.

**Independent Test**: Parcourir l'ensemble du workflow et vérifier que les boutons d'action sont systématiquement en bas.

**Acceptance Scenarios**:

1. **Given** la page d'accueil du sujet (liste des parties), **When** l'élève regarde la page, **Then** le bouton "Commencer" est en bas de la liste des parties
2. **Given** la page de mise en situation (commune ou spécifique), **When** l'élève regarde la page, **Then** le bouton "Continuer"/"Commencer" est en bas du texte
3. **Given** la page d'une question, **When** l'élève regarde la page, **Then** les boutons de navigation sont en bas de la zone de contenu

---

### Edge Cases

- Que se passe-t-il si un sujet n'a que des parties communes (pas de spécifiques) ? Le workflow doit fonctionner normalement sans section "PARTIE SPÉCIFIQUE" et sans écran de mise en situation spécifique.
- Que se passe-t-il si `objective_text` est vide pour une partie ? L'objectif n'est simplement pas affiché, le titre reste visible.
- Que se passe-t-il si l'élève quitte en cours de route et revient ? La session reprend là où il en était grâce au `StudentSession#progression` existant. Les boutons "Fin de partie" déjà cliqués sont mémorisés.
- Que se passe-t-il si l'élève navigue directement via la sidebar vers une question d'une autre partie ? La sidebar reste fonctionnelle. Le bouton "Question suivante" suit l'ordre normal de la partie (pas la page des questions non répondues dans ce cas).
- Que se passe-t-il pour un sujet legacy (sans `exam_session`) ? Le comportement actuel est préservé — pas de séparation commune/spécifique, pas de mise en situation spécifique.
- Que se passe-t-il si l'élève revient sur un sujet déjà terminé ? Il accède à la liste des parties en mode relecture (toutes marquées comme terminées) et peut naviguer librement pour relire les corrections. Pas de popup "Bravo" ni de réinitialisation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La page d'accueil du sujet DOIT regrouper les parties sous des en-têtes "PARTIE COMMUNE" et "PARTIE SPÉCIFIQUE" quand le scope est "complet"
- **FR-002**: Chaque partie dans la liste DOIT afficher son `objective_text` sous son titre (si non vide)
- **FR-003**: Le bouton "Commencer" DOIT être placé en bas de la liste des parties
- **FR-004**: Le dernier bouton de navigation d'une partie DOIT afficher "Fin de la partie" au lieu de "Question suivante" ou "Retour aux sujets"
- **FR-005**: Le clic sur "Fin de la partie" DOIT rediriger vers la page du sujet et enregistrer que la partie a été parcourue
- **FR-006**: La mise en situation spécifique (`specific_presentation`) DOIT être affichée comme écran intermédiaire avant les questions de la partie spécifique, avec un bouton "Commencer" en bas
- **FR-007**: Quand toutes les parties du scope ont été parcourues et qu'il reste des questions non répondues, le système DOIT afficher une page récapitulative des questions restantes
- **FR-008**: Chaque question non répondue dans le récapitulatif DOIT avoir un lien "Revenir à cette question" qui ouvre directement la question
- **FR-009**: Depuis une question accédée via le récapitulatif, le bouton "Question suivante" DOIT rediriger vers la page des questions non répondues
- **FR-010**: Le bouton "Terminer le sujet" DOIT être disponible sur la page des questions non répondues
- **FR-011**: Une page de félicitations "Bravo !!" DOIT s'afficher quand le sujet est terminé (toutes questions répondues ou clic sur "Terminer le sujet"), avec un bouton "Revenir aux sujets"
- **FR-012**: Le `StudentSession` DOIT mémoriser les parties parcourues (statut "Fin de partie" cliqué) pour persister entre sessions
- **FR-013**: Pour les scopes "commun uniquement" ou "spécifique uniquement", le workflow DOIT s'adapter : une seule section, un seul "Fin de la partie" avant la phase de révision
- **FR-014**: Sur la page du sujet, les parties terminées (bouton "Fin de la partie" cliqué) DOIVENT être marquées visuellement (coche ou badge "Terminé") tout en restant accessibles pour y revenir
- **FR-015**: Un sujet déjà terminé DOIT rester accessible en mode relecture : l'élève voit la liste des parties avec leurs marqueurs de progression et peut naviguer librement dans les questions pour relire les corrections, sans re-déclenchement du workflow de fin

### Key Entities

- **StudentSession** : Entité existante. Doit être enrichie pour mémoriser les parties parcourues (ex: `parts_completed` dans `progression` ou `tutor_state`)
- **Part** : Entité existante. Utilise `section_type` (common/specific) pour le regroupement. Utilise `objective_text` pour l'affichage
- **Subject** : Entité existante. Utilise `specific_presentation` (champ existant) pour la mise en situation spécifique

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'élève peut parcourir un sujet complet (commune + spécifique) de bout en bout sans confusion sur sa progression
- **SC-002**: 100% des questions non répondues sont listées sur la page récapitulative après "Fin de la partie" des deux sections
- **SC-003**: Le workflow complet (début -> fin de la partie commune -> mise en situation spécifique -> fin de la partie spécifique -> récapitulatif -> félicitations) fonctionne sans erreur
- **SC-004**: Les scopes partiels (commun seul, spécifique seul) fonctionnent sans anomalie
- **SC-005**: La reprise de session (quitter et revenir) préserve l'état complet de progression

## Assumptions

- Le champ `specific_presentation` existe en base mais n'est pas encore peuplé par le pipeline d'extraction. La fonctionnalité s'adapte gracieusement quand ce champ est vide (écran sauté)
- Les sujets legacy (sans `exam_session`) continuent de fonctionner avec le workflow actuel — cette feature ne modifie pas leur comportement
- Le suivi des parties parcourues sera stocké dans le JSONB `progression` existant du `StudentSession`, sans nouvelle migration
- La sidebar existante reste fonctionnelle et inchangée — seuls les boutons de navigation principale sont modifiés
- Le mode tutoré (spotting card, chat) continue de fonctionner normalement dans le nouveau workflow

# Feature Specification: Refonte du système de phases tuteur et des types de questions

**Feature Branch**: `049-tutor-phases-rework`
**Created**: 2026-04-25
**Status**: Draft
**Input**: Refonte du système de phases tuteur et des types de questions

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Progression guidée par phases adaptées au type de question (Priority: P1)

Un élève ouvre le tuteur sur une question de calcul. Au lieu d'une phase "spotting" générique, le tuteur le guide d'abord à identifier ce que la question demande (spotting_type), puis à localiser les données nécessaires dans les documents techniques (spotting_data), puis l'accompagne dans le raisonnement (guiding). Pour une question QCM, le tuteur passe directement au guidage sans ces étapes préalables.

**Why this priority**: C'est le cœur de la refonte — les phases actuelles bloquent les élèves et le LLM en `greeting`/`reading`. Un tuteur adapté au type de question améliore directement la progression pédagogique.

**Independent Test**: Peut être testé en ouvrant le tuteur sur deux questions de types différents (calcul et QCM) et en vérifiant que les phases suivies diffèrent selon le type.

**Acceptance Scenarios**:

1. **Given** un élève ouvre le tuteur sur une question de type `calcul`, **When** le tuteur démarre, **Then** il passe par `enonce` → `spotting_type` → `spotting_data` → `guiding` dans cet ordre
2. **Given** un élève ouvre le tuteur sur une question de type `qcm`, **When** le tuteur démarre, **Then** il passe par `enonce` → `guiding` directement (spotting_type et spotting_data skippés)
3. **Given** une question de type `justification` ou `representation` sans DT/DR associés, **When** le tuteur atteint `spotting_type`, **Then** la phase `spotting_data` est skippée automatiquement vers `guiding`
4. **Given** une question de type `conclusion`, **When** le tuteur est en `spotting_data`, **Then** il aide l'élève à retrouver les résultats des questions précédentes de la même partie

---

### User Story 2 — Reprise de session à la phase sauvegardée (Priority: P2)

Un élève a commencé à travailler sur une question et s'est arrêté en phase `guiding`. Quand il revient sur la même question (même session ou nouvelle connexion), le tuteur reprend exactement là où il s'était arrêté, sans recommencer depuis le début.

**Why this priority**: Évite la frustration de répéter les étapes déjà faites. L'état de phase doit être persisté par question.

**Independent Test**: Peut être testé en quittant le tuteur en cours de session, puis en revenant sur la même question et en vérifiant que la phase reprend correctement.

**Acceptance Scenarios**:

1. **Given** un élève s'est arrêté à la phase `guiding` sur une question, **When** il rouvre le tuteur sur cette question, **Then** le tuteur reprend en `guiding` sans repasser par `enonce`, `spotting_type` ou `spotting_data`
2. **Given** un élève revient sur une question déjà terminée (`ended`), **When** il ouvre le tuteur, **Then** l'état `ended` est affiché (correction accessible, pas de reprise de cycle)
3. **Given** un élève revient après plus de 12h d'inactivité, **When** il ouvre le tuteur, **Then** un message de re-bienvenue est affiché avant de reprendre la phase sauvegardée

---

### User Story 3 — Greeting unique par sujet, re-greeting conditionnel (Priority: P3)

Quand un élève ouvre le tuteur pour la première fois sur un sujet, il reçoit un message de bienvenue. Ce message n'est pas répété à chaque question ou à chaque navigation dans le sujet. Un re-greeting est émis uniquement lors d'une reconnexion ou après 12h d'inactivité.

**Why this priority**: Évite la répétition agaçante du message de bienvenue à chaque question tout en maintenant une présence bienveillante lors des reprises.

**Independent Test**: Peut être testé en naviguant entre plusieurs questions d'un même sujet et en vérifiant qu'un seul greeting apparaît, puis en simulant une reconnexion.

**Acceptance Scenarios**:

1. **Given** un élève ouvre le tuteur pour la première fois sur un sujet, **When** le tuteur démarre, **Then** un message de bienvenue est affiché une seule fois
2. **Given** un élève navigue d'une question à une autre du même sujet, **When** le tuteur change de question, **Then** aucun nouveau greeting n'est émis
3. **Given** un élève se reconnecte après déconnexion, **When** il ouvre le tuteur, **Then** un re-greeting est affiché
4. **Given** un élève reprend une session après plus de 12h d'inactivité, **When** il ouvre le tuteur, **Then** un re-greeting est affiché

---

### User Story 4 — Nouveaux types de questions enrichis (Priority: P2)

Les enseignants et le pipeline d'extraction bénéficient d'une taxonomie étendue de 7 types de questions (identification, calcul, justification, vérification, représentation, conclusion, QCM), remplaçant l'ancienne taxonomie. Chaque type oriente le comportement du tuteur de façon adaptée.

**Why this priority**: Les nouveaux types permettent un guidage pédagogique beaucoup plus précis. Sans cette migration, la refonte des phases ne peut pas fonctionner correctement.

**Independent Test**: Peut être testé en créant des questions de chaque nouveau type et en vérifiant que le tuteur adapte son comportement de guidage.

**Acceptance Scenarios**:

1. **Given** une question de type `identification`, **When** le tuteur guide l'élève, **Then** le style de guidage oriente vers la localisation dans les documents
2. **Given** une question de type `representation`, **When** le tuteur guide l'élève, **Then** le style de guidage accompagne la construction (tracé, schéma, complétion DR)
3. **Given** des questions existantes avec les anciens types, **When** la migration est appliquée, **Then** chaque question est mappée vers le type le plus proche dans la nouvelle taxonomie sans perte de données

---

### Edge Cases

- Que se passe-t-il si une question n'a pas de `answer_type` défini ? → Le tuteur utilise un comportement par défaut (équivalent `identification`) sans bloquer l'élève.
- Que se passe-t-il si l'état de phase persisté est invalide (phase inexistante dans le nouveau système) ? → Réinitialisation à `enonce` pour la question concernée.
- Que se passe-t-il si `spotting_data` est atteint mais qu'il n'y a ni DT/DR ni données identifiables ? → La phase est skippée automatiquement vers `guiding`.
- Que se passe-t-il si un élève envoie une réponse complète dès la phase `enonce` ? → Le tuteur reconnaît la réponse anticipée et adapte sa progression sans forcer une régression de phase.

## Requirements *(mandatory)*

### Functional Requirements

**Phases**

- **FR-001**: Le système DOIT remplacer les phases actuelles par le nouveau système de 9 états : `idle`, `greeting`, `enonce`, `spotting_type`, `spotting_data`, `guiding`, `validating`, `feedback`, `ended`
- **FR-002**: Les phases `idle` et `greeting` DOIVENT rester globales au sujet (une seule fois par session sujet, pas par question)
- **FR-003**: Les phases `enonce`, `spotting_type`, `spotting_data`, `guiding`, `validating`, `feedback`, `ended` DOIVENT être trackées individuellement par question (état persisté dans `TutorState`)
- **FR-004**: Le système DOIT skipper `spotting_type` et `spotting_data` pour les questions de type `qcm`
- **FR-005**: Le système DOIT skipper `spotting_data` pour les questions sans DT/DR associés ET de type `justification` ou `representation`
- **FR-006**: Le système DOIT permettre de reprendre à la phase sauvegardée lors d'un retour sur une question déjà commencée
- **FR-007**: Le système DOIT émettre un re-greeting si la dernière activité date de plus de 12h ou si l'élève s'est déconnecté et reconnecté
- **FR-008**: Pour les questions de type `conclusion`, le tuteur DOIT en phase `spotting_data` aider l'élève à retrouver les résultats des questions précédentes de la même partie

**Types de questions**

- **FR-009**: Le système DOIT remplacer l'enum `answer_type` actuel par les 7 nouveaux types : `identification`, `calcul`, `justification`, `verification`, `representation`, `conclusion`, `qcm`
- **FR-010**: Une migration DOIT mapper chaque valeur d'ancien `answer_type` vers le type le plus sémantiquement proche dans la nouvelle taxonomie
- **FR-011**: Le pipeline d'extraction DOIT être mis à jour pour produire les nouveaux types lors de l'extraction PDF

**Comportement tuteur adaptatif**

- **FR-012**: Le prompt système du tuteur DOIT varier selon la phase courante ET le type de question, avec un style de guidage adapté (localisation DT pour `identification`, étapes numériques pour `calcul`, élimination distracteurs pour `qcm`, etc.)
- **FR-013**: Si un élève envoie une réponse anticipée (avant la phase `guiding`), le tuteur DOIT adapter sa réponse sans forcer une régression de phase

### Key Entities

- **TutorState** : état persisté par conversation — contient la phase globale sujet (greeting/idle) et un état par question (`question_states[question_id]` avec phase courante, dernière activité par question)
- **Question** : entité enrichie avec le nouveau `answer_type` (7 valeurs) et les `dt_dr_refs` existants qui conditionnent le skip de `spotting_data`
- **Conversation** : conteneur des messages et du `TutorState`, scoped par student + subject

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un élève naviguant entre questions d'un même sujet ne voit le greeting qu'une seule fois par session (ou après reconnexion / 12h d'inactivité) — vérifiable via spec feature
- **SC-002**: Pour une question QCM, le tuteur atteint la phase `guiding` sans passer par `spotting_type` ni `spotting_data` — vérifiable dans les specs feature
- **SC-003**: Un élève qui revient sur une question interrompue en `guiding` reprend en `guiding` dans 100% des cas (aucune régression vers `enonce`) — vérifiable via spec feature
- **SC-004**: Le score de simulation `respect_process` (actuellement 3.20/5) progresse d'au moins +0.5 pt après la refonte — mesuré via le système de sim tuteur existant sur 15 conversations minimum
- **SC-005**: Toutes les questions existantes sont migrées vers les nouveaux types sans perte de données (0 questions avec `answer_type: nil` après migration)
- **SC-006**: La CI reste verte après la migration (aucune régression sur les specs feature existantes)

## Assumptions

- La structure de `TutorState` (JSONB) est extensible pour ajouter le tracking par question sans migration de schéma lourde — seulement une évolution du format JSON interne
- Les anciennes valeurs d'`answer_type` sont suffisamment documentées pour un mapping sans ambiguïté vers les 7 nouveaux types
- Le système de simulation tuteur (`db/seeds/test.rb`) est déjà opérationnel et peut être utilisé pour valider SC-004 après implémentation
- La refonte des phases est principalement backend/prompt — pas de changements UI majeurs requis (le drawer existant reste inchangé)
- Les specs feature existantes (`student_tutor_full_flow_spec`, `student_tutor_spotting_spec`, `student_tutor_activation_spec`) devront être mises à jour pour refléter les nouvelles phases
- Les `validating` et `feedback` restent optionnels et skippables via le bouton "voir correction" existant

# Feature Specification: Filtrage des sujets par spécialité de classe

**Feature Branch**: `051-specialty-subject-filter`
**Created**: 2026-04-27
**Status**: Draft
**Input**: Filtrage des sujets par spécialité de classe — chaque classe a une spécialité (SIN, ITEC, EE, AC). Les élèves d'une classe ne peuvent accéder qu'aux sujets compatibles avec leur spécialité.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Accès filtré à la liste des sujets (Priority: P1)

Un élève se connecte et consulte la liste des sujets disponibles. Les sujets compatibles avec la spécialité de sa classe s'affichent normalement. Les sujets d'une autre spécialité et les sujets tronc commun s'affichent avec la mention "partie commune uniquement".

**Why this priority**: Règle métier fondamentale — sans ce filtrage, un élève AC peut accéder à du contenu SIN, ce qui n'a aucun sens pédagogique.

**Independent Test**: Connecter un élève AC, afficher la liste des sujets → sujets AC sans mention, sujets SIN/ITEC/EE et tronc commun avec mention "partie commune uniquement".

**Acceptance Scenarios**:

1. **Given** un élève de classe AC, **When** il consulte la liste des sujets, **Then** un sujet AC s'affiche normalement sans mention particulière
2. **Given** un élève de classe AC, **When** il consulte la liste des sujets, **Then** un sujet SIN s'affiche avec la mention "partie commune uniquement"
3. **Given** un élève de classe AC, **When** il consulte la liste des sujets, **Then** un sujet tronc commun s'affiche avec la mention "partie commune uniquement"
4. **Given** un élève de classe SIN, **When** il consulte la liste des sujets, **Then** un sujet AC s'affiche avec la mention "partie commune uniquement"

---

### User Story 2 - Accès bloqué à la partie spécifique d'une autre spécialité (Priority: P1)

Un élève tente d'accéder à la partie spécifique d'un sujet dont la spécialité ne correspond pas à celle de sa classe. L'accès est refusé et un message explicatif l'informe qu'il n'y a pas de partie spécifique pour sa spécialité sur ce sujet. L'accès à la partie commune du même sujet reste possible.

**Why this priority**: Même priorité que US1 — c'est l'autre face de la même règle. Sans ce blocage, le filtrage de la liste n'est qu'esthétique.

**Independent Test**: Connecter un élève AC, accéder directement à la partie spécifique d'un sujet SIN → blocage avec message informatif. Accéder à la partie commune du même sujet → accès accordé.

**Acceptance Scenarios**:

1. **Given** un élève AC sur un sujet SIN, **When** il tente d'accéder à la partie spécifique SIN, **Then** l'accès est refusé avec un message indiquant l'absence de partie spécifique pour sa spécialité (AC)
2. **Given** un élève AC sur un sujet SIN, **When** il accède à la partie commune, **Then** l'accès est accordé normalement
3. **Given** un élève AC sur un sujet tronc commun, **When** il accède à une partie commune, **Then** l'accès est accordé normalement
4. **Given** un élève AC sur un sujet AC, **When** il accède à la partie spécifique AC, **Then** l'accès est accordé normalement
5. **Given** un élève AC, **When** il tente d'accéder via URL directe à la partie spécifique d'un sujet SIN, **Then** l'accès est refusé (pas de bypass par URL)

---

### User Story 3 - Seeds de développement multi-spécialités (Priority: P2)

Les données de développement reflètent des scénarios multi-spécialités réalistes : au minimum une classe AC et une classe EE, avec des élèves ayant accès au tuteur, et un sujet EE disponible en plus du sujet AC principal.

**Why this priority**: Nécessaire pour tester manuellement et pour les specs Capybara. Sans seeds cohérents, les scénarios cross-spé ne peuvent pas être validés.

**Independent Test**: Lancer les seeds, se connecter avec un élève EE → voir le sujet AC avec mention "partie commune uniquement", accéder à sa partie commune, lancer le tuteur.

**Acceptance Scenarios**:

1. **Given** les seeds chargés, **When** un élève AC se connecte, **Then** il voit le sujet AC complet (TC + SPE) sans mention de restriction
2. **Given** les seeds chargés, **When** un élève EE se connecte, **Then** il voit le sujet AC avec mention "partie commune uniquement"
3. **Given** les seeds chargés, **When** un élève EE avec clé tuteur accède à la partie commune du sujet AC, **Then** il peut lancer le tuteur normalement
4. **Given** les seeds chargés, **When** un élève AC avec clé tuteur accède à la partie spécifique AC, **Then** il peut lancer le tuteur normalement

---

### Edge Cases

- Que se passe-t-il si un élève n'a pas de spécialité sur sa classe ? → Cas impossible en production — la spécialité est obligatoire à la création de la classe.
- Que se passe-t-il si un sujet est assigné via ClassroomSubject à une classe cross-spé ? → La règle de filtrage s'applique quand même, pas de bypass.
- Que se passe-t-il si un sujet n'a aucune partie spécifique (que des parties communes) ? → Toutes ses parties sont accessibles quelle que soit la spécialité de l'élève.
- Que se passe-t-il si un élève tente d'accéder via URL directe à une partie bloquée ? → Accès refusé, même comportement que via la navigation normale.
- Que se passe-t-il si un sujet tronc commun n'a que des parties communes ? → Toutes ses parties sont accessibles à tous les élèves.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT afficher la mention "partie commune uniquement" pour tout sujet dont la spécialité ne correspond pas à celle de la classe de l'élève connecté.
- **FR-002**: Le système DOIT afficher la mention "partie commune uniquement" pour tout sujet de type tronc commun (sans spécialité de classe cible).
- **FR-003**: Le système DOIT bloquer l'accès à toute partie spécifique d'un sujet dont la spécialité ne correspond pas à la spécialité de la classe de l'élève.
- **FR-004**: Le système DOIT autoriser l'accès aux parties communes d'un sujet quelle que soit la spécialité de la classe de l'élève.
- **FR-005**: Le blocage DOIT s'appliquer même via accès URL direct (pas de bypass par manipulation d'URL).
- **FR-006**: Le message de blocage DOIT indiquer explicitement l'absence de partie spécifique pour la spécialité de l'élève sur ce sujet.
- **FR-007**: Les seeds de développement DOIVENT inclure : une classe AC avec élèves (dont certains avec clé tuteur), une classe EE avec élèves (dont certains avec clé tuteur), un sujet AC (TC + SPE AC), un sujet EE.

### Key Entities

- **Classroom** : possède une spécialité (SIN, ITEC, EE, AC) — détermine l'accès complet ou restreint de ses élèves aux sujets.
- **Subject** : possède une spécialité (SIN, ITEC, EE, AC) ou est tronc commun — détermine qui peut accéder aux parties spécifiques.
- **Part** : possède un type (common ou specific) — les parties specific sont filtrées selon la compatibilité de spécialité.
- **Student** : appartient à une Classroom, hérite de sa spécialité pour les règles d'accès aux sujets.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% des tentatives d'accès aux parties spécifiques d'une spécialité non compatible sont bloquées, y compris via URL directe.
- **SC-002**: 100% des sujets non compatibles avec la spécialité de l'élève affichent la mention "partie commune uniquement" dans la liste.
- **SC-003**: Un élève accédant à un sujet cross-spécialité peut naviguer et travailler sur la partie commune sans erreur ni friction supplémentaire par rapport à un accès normal.
- **SC-004**: Les seeds permettent de tester les scénarios accès complet (élève AC sur sujet AC) et accès restreint (élève EE sur sujet AC) sans configuration manuelle.

## Assumptions

- La spécialité d'une classe est toujours définie — aucune classe sans spécialité en production.
- Les quatre spécialités du MVP sont SIN, ITEC, EE, AC. Tronc commun est un type de sujet, pas une spécialité de classe.
- L'enseignant peut assigner n'importe quel sujet à n'importe quelle classe (cross-spé intentionnel) — la règle de filtrage s'applique côté élève indépendamment de l'assignation.
- Le tuteur IA est disponible sur les parties communes pour les élèves de toutes spécialités — pas de restriction supplémentaire sur le tuteur.
- Aucune migration de base de données n'est nécessaire — les champs `specialty` et `section_type` existent déjà sur les modèles concernés.
- Le sujet de développement principal est de spécialité AC. Un sujet EE sera ajouté aux seeds pour les tests cross-spé.

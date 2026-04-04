# Feature Specification: Consolidation de l'extraction PDF

**Feature Branch**: `015-extraction-consolidation`  
**Created**: 2026-04-04  
**Status**: Draft  
**Input**: Consolidation extraction PDF: upload 2 fichiers (sujet + corrigé), ExamSession pour grouper les spécialités, parties communes partagées, spécialité sur profil élève, navigation commune/spé/complet.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Upload simplifié d'un sujet BAC (Priority: P1)

Un enseignant veut importer un sujet BAC STI2D officiel. Il dispose d'un PDF sujet monolithique (35 pages contenant mise en situation, questions communes, questions spécifiques, DTs et DRs) et d'un PDF corrigé correspondant. Il choisit la spécialité (SIN, ITEC, EE ou AC), remplit les métadonnées (titre, année, région), uploade les 2 fichiers, et le système extrait automatiquement toute la structure.

**Why this priority**: Sans upload et extraction fonctionnels, rien d'autre ne peut être testé. C'est la fondation de la feature.

**Independent Test**: Peut être testé en uploadant un vrai sujet BAC et en vérifiant que les parties communes, spécifiques, questions et corrections sont correctement extraites et structurées.

**Acceptance Scenarios**:

1. **Given** un enseignant connecté, **When** il crée un nouveau sujet en uploadant 2 PDFs (sujet ITEC + corrigé ITEC) avec les métadonnées, **Then** le système crée une session d'examen et un sujet, lance l'extraction, et extrait les parties communes (Parties 1 à 5) et spécifiques (Parties A, B) avec leurs questions, corrections et références DT/DR.
2. **Given** un sujet en cours d'extraction, **When** l'extraction se termine avec succès, **Then** l'enseignant voit la structure complète : parties communes avec leurs questions et parties spécifiques avec leurs questions, chacune avec les corrections et les références aux documents techniques.
3. **Given** un PDF sujet de 35 pages, **When** le système extrait le texte, **Then** les numéros de pages sont préservés pour identifier l'emplacement des DTs et DRs dans le PDF original.
4. **Given** une extraction en cours, **When** une erreur survient (PDF illisible, réponse LLM invalide), **Then** l'enseignant est informé de l'erreur et peut relancer l'extraction.

---

### User Story 2 - Deuxième spécialité et déduplication des parties communes (Priority: P1)

Après avoir importé le sujet ITEC d'une session, l'enseignant importe le sujet AC de la même session (même année, même thème, même région). Le système détecte que la partie commune existe déjà et ne la recrée pas : il crée uniquement la partie spécifique AC et la rattache à la même session d'examen.

**Why this priority**: La déduplication des parties communes est un des objectifs principaux de la consolidation. Sans elle, la notion de session d'examen perd son intérêt.

**Independent Test**: Peut être testé en uploadant successivement 2 sujets de spécialités différentes pour la même session et en vérifiant que les parties communes ne sont pas dupliquées.

**Acceptance Scenarios**:

1. **Given** une session d'examen "Polynésie 2024 CIME" existante avec le sujet ITEC et ses parties communes, **When** l'enseignant uploade le sujet AC de la même session, **Then** le système propose de rattacher à la session existante.
2. **Given** l'enseignant confirme le rattachement à la session existante, **When** l'extraction se termine, **Then** seules les parties spécifiques AC sont créées ; les parties communes existantes sont réutilisées sans duplication.
3. **Given** une session avec 2 sujets (ITEC + AC), **When** l'enseignant consulte la session, **Then** il voit 1 jeu de parties communes et 2 parties spécifiques (ITEC et AC).

---

### User Story 3 - Spécialité sur le profil élève (Priority: P2)

Un élève peut indiquer sa spécialité STI2D (SIN, ITEC, EE ou AC) dans ses paramètres. Ce choix sert de défaut pour le filtrage des sujets mais ne constitue pas une restriction.

**Why this priority**: La spécialité de l'élève est nécessaire pour la navigation personnalisée mais peut fonctionner sans (mode "tout afficher" par défaut).

**Independent Test**: Peut être testé en se connectant comme élève, en configurant sa spécialité, et en vérifiant que le choix est persisté.

**Acceptance Scenarios**:

1. **Given** un élève connecté, **When** il accède à ses paramètres, **Then** il voit un sélecteur de spécialité (SIN, ITEC, EE, AC).
2. **Given** un élève qui sélectionne "SIN" comme spécialité, **When** il sauvegarde, **Then** la spécialité est enregistrée et visible dans son profil.
3. **Given** un élève sans spécialité configurée, **When** il navigue dans les sujets, **Then** tous les sujets sont affichés sans filtrage.

---

### User Story 4 - Navigation élève : choix du périmètre (Priority: P2)

Quand un élève sélectionne un sujet, il choisit le périmètre de travail : partie commune uniquement (12 pts, 2h30), partie spécifique uniquement (8 pts, 1h30), ou sujet complet (20 pts, 4h). Ce choix détermine quelles questions lui sont présentées.

**Why this priority**: C'est l'aboutissement côté élève de toute la restructuration. Critique pour l'expérience utilisateur mais dépend des 3 premières stories.

**Independent Test**: Peut être testé en se connectant comme élève, en choisissant un sujet, puis en vérifiant que seules les questions du périmètre choisi sont affichées.

**Acceptance Scenarios**:

1. **Given** un élève qui accède à un sujet rattaché à une session d'examen, **When** il clique sur le sujet, **Then** il voit un écran de choix avec 3 options : "Partie commune", "Partie spécifique [spé du sujet]", "Sujet complet".
2. **Given** un élève qui choisit "Partie commune", **When** il commence à travailler, **Then** seules les questions des parties communes sont affichées.
3. **Given** un élève qui choisit "Partie spécifique ITEC", **When** il commence à travailler, **Then** seules les questions spécifiques ITEC sont affichées.
4. **Given** un élève qui choisit "Sujet complet", **When** il commence à travailler, **Then** toutes les questions (communes + spécifiques) sont affichées.
5. **Given** un élève qui a commencé en mode "Partie commune" et répondu à quelques questions, **When** il change de périmètre pour "Sujet complet", **Then** sa progression précédente est conservée et les questions déjà répondues restent marquées comme telles.

---

### User Story 5 - Rétrocompatibilité avec les anciens sujets (Priority: P3)

Les sujets existants (créés avec l'ancien format à 5 fichiers) continuent de fonctionner normalement sans migration obligatoire.

**Why this priority**: Protège les données existantes mais n'apporte pas de nouvelle fonctionnalité.

**Independent Test**: Peut être testé en accédant à un ancien sujet (5 fichiers) et en vérifiant que l'affichage enseignant et la navigation élève fonctionnent toujours.

**Acceptance Scenarios**:

1. **Given** un sujet créé avec l'ancien format (5 fichiers PDF), **When** un enseignant accède à la page du sujet, **Then** les informations et téléchargements des fichiers fonctionnent normalement.
2. **Given** un ancien sujet publié et assigné à une classe, **When** un élève y accède, **Then** la navigation questions fonctionne comme avant (sans écran de choix commune/spé).

---

### Edge Cases

- Que se passe-t-il si le PDF sujet ne contient pas de partie spécifique (ex: sujet contenant uniquement le tronc commun) ?
- Que se passe-t-il si l'enseignant uploade un corrigé qui ne correspond pas au sujet (spécialité différente) ?
- Que se passe-t-il si le LLM ne parvient pas à distinguer les parties communes des parties spécifiques ?
- Que se passe-t-il si l'enseignant veut corriger une question dans la partie commune — quel est l'impact sur les autres sujets de la session ?
- Quand un enseignant supprime un sujet d'une session, seules les parties spécifiques sont supprimées. Les parties communes restent tant qu'un sujet existe dans la session. La session doit être supprimée explicitement pour retirer les parties communes.
- Que se passe-t-il si le PDF fait plus de 40 pages et dépasse les limites de tokens du LLM ?

## Clarifications

### Session 2026-04-04

- Q: Que se passe-t-il quand un enseignant supprime un sujet rattaché à une session multi-spécialités ? → A: Suppression douce — seules les parties spécifiques du sujet sont supprimées. Les parties communes restent tant qu'au moins un sujet existe dans la session. La session elle-même doit être supprimée explicitement par l'enseignant si nécessaire.
- Q: Quand un élève change de périmètre en cours de travail, que devient sa progression ? → A: Progression cumulative — les réponses précédentes sont conservées quel que soit le changement de périmètre. Pas de confirmation nécessaire.

## Requirements *(mandatory)*

### Functional Requirements

**Upload et métadonnées :**
- **FR-001**: Le système DOIT permettre l'upload de 2 fichiers PDF (sujet + corrigé) au lieu de 5.
- **FR-002**: Le système DOIT extraire automatiquement les métadonnées du PDF (titre du thème, année, spécialité, référence document) via le LLM lors de l'extraction.
- **FR-003**: Le formulaire de création DOIT proposer les spécialités SIN, ITEC, EE et AC (pas de "tronc commun" comme option isolée).
- **FR-004**: Le système DOIT créer automatiquement une session d'examen lors du premier upload d'un sujet pour une combinaison année+région+thème donnée.

**Extraction :**
- **FR-005**: Le système DOIT extraire le texte des 2 PDFs avec des marqueurs de pages pour identifier l'emplacement des documents techniques.
- **FR-006**: Le système DOIT distinguer les parties communes (12 pts) des parties spécifiques (8 pts) dans le PDF monolithique.
- **FR-007**: Le système DOIT identifier et référencer les DTs et DRs avec leurs numéros de pages dans le PDF original.
- **FR-008**: Le système DOIT croiser le PDF sujet avec le PDF corrigé pour associer chaque question à sa correction.
- **FR-009**: Le système DOIT identifier les références DT/DR mentionnées dans chaque question (ex: "Question 2.1 — DT2, DR1").

**Session d'examen et déduplication :**
- **FR-010**: Le système DOIT permettre de rattacher un nouveau sujet à une session d'examen existante.
- **FR-011**: Quand une session existe déjà avec des parties communes, le système NE DOIT PAS recréer les parties communes lors de l'upload d'une nouvelle spécialité.
- **FR-012**: Les parties communes DOIVENT être partagées au niveau de la session d'examen, pas dupliquées par sujet.
- **FR-013**: Le système DOIT permettre d'avoir de 1 à 4 spécialités rattachées à une même session.

**Profil élève :**
- **FR-014**: Les élèves DOIVENT pouvoir indiquer leur spécialité (SIN, ITEC, EE, AC) dans leurs paramètres.
- **FR-015**: La spécialité de l'élève est optionnelle et sert de défaut pour le filtrage, pas de restriction.

**Navigation élève :**
- **FR-016**: Quand un élève accède à un sujet, il DOIT pouvoir choisir son périmètre de travail : partie commune seule, partie spécifique seule, ou sujet complet.
- **FR-017**: Le système DOIT mémoriser le choix de périmètre pour chaque session de travail élève.
- **FR-018**: Le filtrage des questions DOIT s'appliquer à la navigation, à la progression et au tutorat.
- **FR-024**: Quand un élève change de périmètre, sa progression DOIT être conservée de manière cumulative (les questions déjà répondues restent marquées).

**Suppression :**
- **FR-022**: La suppression d'un sujet NE DOIT supprimer que ses parties spécifiques. Les parties communes de la session DOIVENT être préservées tant qu'au moins un sujet existe dans la session.
- **FR-023**: L'enseignant DOIT pouvoir supprimer une session d'examen entière (avec ses parties communes) de manière explicite via une action dédiée.

**Rétrocompatibilité :**
- **FR-019**: Les sujets créés avec l'ancien format (5 fichiers) DOIVENT continuer de fonctionner sans modification.
- **FR-020**: Le formulaire de création DOIT gérer le nouveau format (2 fichiers) tout en conservant la possibilité d'afficher les anciens sujets.

**Renommage :**
- **FR-021**: La spécialité "EC" DOIT être renommée en "EE" (Énergie et Environnement) pour correspondre à la nomenclature officielle.

### Key Entities

- **Session d'examen** : Regroupe les sujets d'une même session d'examen officielle. Contient le titre du thème, l'année, la région, le type d'examen et la mise en situation commune. Possède de 1 à 4 sujets (un par spécialité) et les parties communes.
- **Sujet** : Représente un sujet d'une spécialité donnée (SIN, ITEC, EE, AC). Appartient à une session d'examen. Contient les 2 fichiers PDF (sujet + corrigé) et les parties spécifiques.
- **Partie** : Représente une partie de l'examen (ex: "Partie 1 : comment le CIME s'inscrit..."). Peut être commune (rattachée à la session, partagée entre tous les sujets) ou spécifique (rattachée à un sujet). Contient les références aux documents techniques (DTs/DRs avec pages).
- **Question** : Représente une question individuelle avec son énoncé, ses points, son type de réponse, et ses références aux documents techniques.
- **Élève** : Utilisateur avec une spécialité optionnelle dans son profil.
- **Session de travail** : Session de travail d'un élève sur un sujet, avec le périmètre choisi (commune/spé/complet).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un enseignant peut créer un sujet complet en uploadant 2 fichiers au lieu de 5, réduisant le nombre de fichiers à préparer de 60%.
- **SC-002**: L'extraction d'un PDF de 35 pages produit une structure correcte (parties communes et spécifiques identifiées, questions et corrections associées) dans 95% des cas pour les sujets BAC STI2D officiels.
- **SC-003**: Quand 2 sujets de spécialités différentes sont rattachés à la même session, les parties communes existent une seule fois (pas de duplication).
- **SC-004**: Un élève peut choisir son périmètre de travail (commune/spé/complet) en moins de 2 clics après avoir sélectionné un sujet.
- **SC-005**: Les sujets existants (ancien format) restent accessibles et fonctionnels sans intervention manuelle.
- **SC-006**: L'extraction identifie correctement les références DT/DR par question dans 90% des cas.

## Assumptions

- Les PDFs officiels BAC STI2D suivent une structure standardisée : page de garde, partie commune, DTs communs, DRs communs, page de garde spécifique, partie spécifique, DTs spécifiques, DRs spécifiques.
- Le texte des PDFs est extractible programmatiquement (pas de scan/OCR nécessaire pour les sujets officiels).
- Un PDF sujet de 35 pages + un corrigé de 18 pages restent dans les limites de tokens des modèles LLM utilisés pour l'extraction.
- La partie commune est identique entre les 4 fichiers de spécialités d'une même session — la détection de session existante se fait via les métadonnées (année + région + thème), pas par comparaison textuelle.
- Les DTs et DRs sont affichés par page du PDF original (pas de découpage en fichiers individuels pour cette version).
- Les corrections dans le fichier corrigé suivent la même numérotation de questions que le sujet.
- La modification d'une question de la partie commune impacte tous les sujets de la session (comportement attendu car les données sont partagées).

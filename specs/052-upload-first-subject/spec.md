# Feature Specification: Upload-First Subject Creation Workflow

**Feature Branch**: `052-upload-first-subject`
**Created**: 2026-04-27
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Upload PDFs et auto-remplissage des métadonnées (Priority: P1)

Le professeur accède à la page de création de sujet, uploade uniquement les deux PDFs (sujet + corrigé), lance l'extraction, puis arrive sur un formulaire de validation pré-rempli avec toutes les métadonnées extraites (titre, année, exam, spécialité, région, variante). Il valide ou corrige si besoin, puis soumet.

**Why this priority**: C'est le cœur du nouveau workflow. Réduit la saisie manuelle de 5 champs à 0 dans le cas nominal.

**Independent Test**: Un professeur peut créer un sujet complet en uploadant deux PDFs et en cliquant "Valider" sans saisir aucune métadonnée manuellement.

**Acceptance Scenarios**:

1. **Given** le prof est sur la page de création de sujet, **When** il uploade sujet.pdf et corrigé.pdf et soumet, **Then** l'extraction tourne et il arrive sur un formulaire de validation pré-rempli avec titre, année, exam, spécialité, région, variante
2. **Given** le formulaire de validation est affiché, **When** le prof clique "Créer le sujet" sans modifier, **Then** le sujet est créé en statut draft avec toutes les métadonnées extraites
3. **Given** le formulaire de validation est affiché, **When** le prof corrige la spécialité et soumet, **Then** le sujet est créé avec la spécialité corrigée
4. **Given** le prof est sur la page de création, **When** il n'uploade qu'un seul PDF, **Then** une erreur indique que les deux PDFs sont requis

---

### User Story 2 — Rattachement à une ExamSession existante (Priority: P2)

Quand les métadonnées extraites correspondent à une ExamSession déjà existante (même titre + même année), le formulaire de validation affiche une notice invitant le prof à confirmer le rattachement plutôt que de créer une session en doublon.

**Why this priority**: Évite la prolifération de sessions dupliquées pour le même examen, ce qui causerait des incohérences sur les parties communes partagées.

**Independent Test**: Uploader un sujet dont l'extraction retourne titre+année correspondant à une ExamSession existante → le formulaire affiche une notice de rattachement avec choix.

**Acceptance Scenarios**:

1. **Given** une ExamSession "CIME 2024" existe, **When** l'extraction retourne title="CIME 2024" et year="2024", **Then** le formulaire affiche une notice "Session existante détectée : CIME 2024 — Rattacher ou créer une nouvelle ?"
2. **Given** la notice est affichée, **When** le prof choisit "Rattacher", **Then** le sujet est créé et lié à la session existante
3. **Given** la notice est affichée, **When** le prof choisit "Créer une nouvelle session", **Then** une nouvelle ExamSession est créée avec les métadonnées extraites

---

### User Story 3 — Gestion des erreurs et métadonnées partielles (Priority: P2)

Quand l'extraction échoue partiellement ou totalement, le prof arrive sur le formulaire de validation avec les champs disponibles pré-remplis et les champs manquants vides, sans blocage.

**Why this priority**: L'extraction peut échouer ou retourner des données incomplètes. Le workflow ne doit jamais bloquer le prof.

**Independent Test**: Simuler une extraction avec métadonnées partielles → le formulaire s'affiche avec les champs disponibles pré-remplis, les autres vides avec indication "non détecté".

**Acceptance Scenarios**:

1. **Given** l'extraction réussit mais ne retourne pas la région, **When** le formulaire de validation s'affiche, **Then** tous les autres champs sont pré-remplis et le champ région est vide avec indication "non détecté"
2. **Given** l'extraction échoue complètement, **When** le prof est redirigé, **Then** il arrive sur le formulaire avec tous les champs vides et un message "Extraction échouée — remplissez les informations manuellement"
3. **Given** le formulaire affiche des champs manquants, **When** le prof les remplit et soumet, **Then** le sujet est créé normalement

---

### Edge Cases

- Que se passe-t-il si le prof uploade un PDF quelconque (non-sujet BAC) ? → l'extraction retourne des métadonnées incohérentes ou vides, le prof les corrige manuellement dans le formulaire
- Que se passe-t-il si la spécialité extraite n'est pas dans la liste (AC, EE, ITEC, SIN) ? → le champ spécialité reste vide, le prof le saisit manuellement
- Que se passe-t-il si le prof recharge la page pendant l'extraction ? → l'extraction continue en arrière-plan, le prof peut revenir via la liste des sujets en cours d'extraction
- Que se passe-t-il si les deux PDFs uploadés sont identiques ? → pas de validation sur le contenu, le prof est responsable

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT proposer une page d'upload avec uniquement deux champs obligatoires : sujet PDF et corrigé PDF — aucune métadonnée saisie à cette étape
- **FR-002**: Le système DOIT lancer l'extraction automatique immédiatement après l'upload des deux PDFs
- **FR-003**: Le système DOIT pré-remplir le formulaire de validation avec les métadonnées extraites : titre, année, type d'examen, spécialité, région, variante
- **FR-004**: La spécialité pré-remplie DOIT être l'une des 4 valeurs (AC, EE, ITEC, SIN) — si la valeur extraite ne correspond pas, le champ reste vide
- **FR-005**: Le système DOIT détecter si une ExamSession avec le même titre et la même année existe déjà et afficher une notice de confirmation avec choix Rattacher / Créer nouvelle
- **FR-006**: Le formulaire de validation DOIT permettre au prof de modifier toute métadonnée pré-remplie avant de soumettre
- **FR-007**: Les champs non détectés DOIVENT s'afficher vides avec une indication visuelle "non détecté", sans bloquer la soumission si remplis manuellement
- **FR-008**: En cas d'échec total de l'extraction, le système DOIT afficher le formulaire entièrement vide avec un message d'erreur explicite
- **FR-009**: L'ancien formulaire de création manuelle (saisie des métadonnées avant upload) DOIT être supprimé
- **FR-010**: Le sujet créé DOIT avoir le statut "draft" à l'issue de la validation

### Key Entities

- **Subject**: titre, année, spécialité (AC/EE/ITEC/SIN), exam, région, variante, statut draft — créé à l'issue de la validation du formulaire
- **ExamSession**: session d'examen regroupant les parties communes — peut être existante (rattachement confirmé) ou nouvelle (création)
- **ExtractionJob**: job asynchrone produisant les métadonnées et questions depuis les PDFs — son résultat alimente le formulaire de validation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un professeur peut créer un sujet complet sans saisir aucune métadonnée manuellement lorsque l'extraction réussit — durée totale (upload + validation) inférieure à 2 minutes
- **SC-002**: 100% des métadonnées présentes dans le résultat d'extraction (titre, année, exam, spécialité, région, variante) sont pré-remplies dans le formulaire de validation
- **SC-003**: En cas d'extraction partielle, le formulaire de validation s'affiche avec les champs disponibles pré-remplis — le prof n'est jamais bloqué
- **SC-004**: Zéro doublon d'ExamSession créé pour un même titre+année lorsque le prof choisit "Rattacher"

## Assumptions

- L'extraction asynchrone est déjà fonctionnelle et produit un JSON contenant les champs `metadata.title`, `metadata.year`, `metadata.exam`, `metadata.specialty`, `metadata.region`, `metadata.variante`
- Le workflow en aval (validation question par question, publication) reste inchangé
- Un seul prof crée un sujet à la fois — pas de collaboration simultanée
- L'upload requiert que le prof soit authentifié — pas de changement sur les permissions
- La valeur `tronc_commun` reste en base mais n'est pas accessible via ce nouveau workflow

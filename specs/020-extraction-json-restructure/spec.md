# Feature Specification: Restructuration du JSON d'extraction

**Feature Branch**: `020-extraction-json-restructure`
**Created**: 2026-04-07
**Status**: Draft
**Input**: Restructuration du JSON d'extraction BAC STI2D : scinder la présentation en common_presentation et specific_presentation, ajouter les métadonnées code/region/variante, renommer exam_type→exam, year en string

## User Scenarios & Testing *(mandatory)*

### User Story 1 — L'extraction produit deux mises en situation distinctes (Priority: P1)

Un enseignant uploade un sujet BAC STI2D avec son corrigé. Le système extrait automatiquement la mise en situation commune (partagée entre toutes les spécialités) et la mise en situation spécifique (propre à la spécialité du sujet). Chacune est restituée verbatim.

**Why this priority**: La séparation des deux présentations est l'objectif principal. Sans elle, l'élève ne voit qu'un seul texte de contexte incomplet.

**Independent Test**: Lancer l'extraction sur un sujet BAC réel. Le JSON résultant contient deux champs `common_presentation` et `specific_presentation`, chacun non vide et fidèle au PDF source.

**Acceptance Scenarios**:

1. **Given** un sujet BAC STI2D uploadé, **When** l'extraction est lancée, **Then** le JSON contient un champ `common_presentation` avec le texte verbatim de la mise en situation commune
2. **Given** un sujet BAC STI2D uploadé, **When** l'extraction est lancée, **Then** le JSON contient un champ `specific_presentation` avec le texte verbatim de la mise en situation spécifique
3. **Given** un sujet avec les deux mises en situation, **When** la persistence est exécutée, **Then** `common_presentation` est stocké sur l'ExamSession et `specific_presentation` sur le Subject

---

### User Story 2 — Le code sujet est extrait automatiquement (Priority: P2)

L'extraction identifie le code standardisé du sujet (ex: `24-2D2IDACPO1`) présent dans le PDF et le retourne dans les métadonnées, permettant de déduire automatiquement l'année, la spécialité, la région et la variante.

**Why this priority**: Le code simplifie le workflow enseignant en pré-remplissant les métadonnées. Mais il est secondaire par rapport à la séparation des présentations.

**Independent Test**: Lancer l'extraction sur un sujet BAC dont le code est connu. Le JSON contient `metadata.code` avec la bonne valeur et les champs dérivés (region, variante) sont cohérents.

**Acceptance Scenarios**:

1. **Given** un sujet BAC contenant le code `24-2D2IDACPO1`, **When** l'extraction est lancée, **Then** `metadata.code` vaut `"24-2D2IDACPO1"`
2. **Given** un code extrait, **When** les métadonnées sont parsées, **Then** `metadata.region` vaut `"polynesie"` et `metadata.variante` vaut `"normale"`

---

### User Story 3 — Les métadonnées utilisent les noms cohérents (Priority: P3)

Le JSON d'extraction utilise `exam` au lieu de `exam_type`, `year` est une string, et les nouveaux champs `region` et `variante` sont présents.

**Why this priority**: Cohérence du schéma JSON. Impacte le prompt, la persistence et le seed mais ne change pas le comportement utilisateur.

**Independent Test**: Vérifier que le JSON généré utilise les bons noms de champs et types.

**Acceptance Scenarios**:

1. **Given** une extraction, **When** le JSON est produit, **Then** `metadata.exam` existe (pas `exam_type`), `metadata.year` est une string, `metadata.region` et `metadata.variante` sont présents
2. **Given** le JSON restructuré, **When** la persistence est exécutée, **Then** les données sont correctement mappées vers les modèles Rails existants

---

### Edge Cases

- Que se passe-t-il si le PDF ne contient pas de mise en situation spécifique distincte ? Le champ `specific_presentation` est une chaîne vide.
- Que se passe-t-il si le code sujet est mal formé ? La persistence doit valider le format et lever une erreur.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le JSON d'extraction DOIT contenir `common_presentation` (texte verbatim de la mise en situation commune) au lieu de `presentation`
- **FR-002**: Le JSON d'extraction DOIT contenir `specific_presentation` (texte verbatim de la mise en situation spécifique)
- **FR-003**: Le champ `metadata.code` DOIT contenir le code standardisé du sujet (ex: `24-2D2IDACPO1`). Ce champ est OBLIGATOIRE — le prompt doit exiger son extraction et la persistence doit le valider
- **FR-004**: Le champ `metadata.exam` DOIT remplacer `metadata.exam_type`
- **FR-005**: Le champ `metadata.year` DOIT être une string (ex: `"2024"`)
- **FR-006**: Le champ `metadata.region` DOIT être présent avec les valeurs : `metropole`, `reunion`, `polynesie`, `nouvelle_caledonie`. L'enum `drom_com` DOIT être renommé en `reunion`
- **FR-007**: Le champ `metadata.variante` DOIT être présent avec les valeurs : `normale`, `remplacement`
- **FR-008**: La persistence DOIT stocker `common_presentation` sur `ExamSession.common_presentation`
- **FR-009**: La persistence DOIT stocker `specific_presentation` sur `Subject.specific_presentation`
- **FR-010**: Le prompt d'extraction DOIT être mis à jour avec le nouveau schéma JSON et des instructions explicites pour identifier les deux mises en situation
- **FR-011**: Le seed de développement DOIT être mis à jour pour utiliser le nouveau format JSON
- **FR-012**: Les specs unitaires DOIVENT être mises à jour pour refléter le nouveau schéma

### Key Entities

- **ExamSession**: Stocke `common_presentation` (mise en situation commune), `title`, `year`, `exam`, `region`, `variante`
- **Subject**: Stocke `specific_presentation` (mise en situation spécifique), `specialty`, `code`, `status`. Délègue `title`, `year`, `exam`, `region`, `variante`, `common_presentation` à ExamSession.
- **Metadata JSON**: Structure enrichie avec `code` (obligatoire), `region`, `variante`, renommages `exam`/`year`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'extraction d'un sujet BAC réel produit deux champs de présentation distincts et non vides
- **SC-002**: Le code sujet est correctement extrait et correspond au format attendu
- **SC-003**: Toutes les specs unitaires existantes passent après adaptation au nouveau schéma
- **SC-004**: Le seed de développement (`bin/rails db:seed:replant`) fonctionne avec le nouveau format JSON
- **SC-005**: La CI est verte sur la branche

## Assumptions

- Les colonnes sont renommées en base pour correspondre au JSON (`exam_type` → `exam`, `presentation_text` → `common_presentation`/`specific_presentation`)
- Les colonnes redondantes (`title`, `year`, `exam_type`, `region`) sont supprimées de Subject et déléguées à ExamSession
- L'enum `drom_com` est renommé en `reunion` sur ExamSession et Subject
- Les vues élève ne sont pas modifiées dans cette feature (elles seront traitées séparément)
- La rétrocompatibilité avec l'ancien format JSON n'est pas nécessaire — les données existantes seront ré-extraites

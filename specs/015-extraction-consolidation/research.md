# Research: Consolidation de l'extraction PDF

## R1 — Ownership polymorphique de Part (ExamSession vs Subject)

**Decision**: Part a deux FK nullables (`exam_session_id` et `subject_id`) avec une check constraint DB assurant qu'exactement une des deux est renseignée.

**Rationale**: Plus simple qu'un polymorphisme ActiveRecord (`partable_type/partable_id`) qui complique les joins et les queries. Les deux FK concrètes permettent des foreign keys réelles, des index performants, et des requêtes simples (`ExamSession.common_parts`, `Subject.parts`).

**Alternatives considered**:
- Polymorphisme AR (`belongs_to :partable, polymorphic: true`) — rejeté car pas de FK constraint possible, queries plus complexes
- Duplication des parties communes par Subject — rejeté car choix explicite de l'utilisateur pour le partage
- Table de jointure (`subject_parts`) — rejeté car surajoute de la complexité pour un cas simple

## R2 — Détection de session existante lors du 2e upload

**Decision**: Le formulaire enseignant propose un select "Session existante" listant les ExamSessions du prof (filtré par année et région si renseignés). Si sélectionnée, `exam_session_id` est passé directement. Sinon, une nouvelle ExamSession est créée automatiquement.

**Rationale**: La détection automatique par titre/thème est fragile (variations de noms). Un select explicite est simple, fiable, et donne le contrôle à l'enseignant.

**Alternatives considered**:
- Auto-détection par matching titre+année+région — rejeté car trop fragile, risque de faux positifs
- Création manuelle obligatoire de l'ExamSession avant upload — rejeté car ajoute une étape UX inutile

## R3 — Max tokens pour l'extraction dual-PDF

**Decision**: Augmenter `max_tokens` de 8192 à 16384 pour l'output. L'input (35 pages sujet + 18 pages corrigé) représente environ 30-50k tokens d'entrée, compatible avec tous les modèles utilisés (Claude Sonnet, Mistral Large, GPT-4o).

**Rationale**: Un sujet complet avec 20+ questions, corrections, et document_references nécessite environ 8-12k tokens de sortie JSON. 16384 offre une marge confortable.

**Alternatives considered**:
- Extraction en 2 passes (commune puis spécifique) — rejeté pour le MVP, ajouterait de la complexité
- 32768 tokens — possible mais inutile pour le moment, coût supérieur

## R4 — Affichage DTs/DRs par page du PDF original

**Decision**: Les DTs et DRs sont affichés en rendant la page correspondante du PDF original dans un viewer intégré (iframe PDF avec paramètre `#page=N`). Les `document_references` sur Part stockent les numéros de pages.

**Rationale**: Pas besoin de découper le PDF en fichiers individuels. Les navigateurs supportent nativement l'ouverture d'un PDF à une page donnée via `#page=N`. Simple et suffisant pour le MVP.

**Alternatives considered**:
- Découpage en PDFs individuels par DT (pdf-toolkit) — rejeté car complexité inutile pour le MVP
- Extraction d'images des DTs — rejeté, prévu en post-MVP

## R5 — Renommage enum EC → EE

**Decision**: Migration de données SQL qui met à jour les valeurs existantes. Le code enum passe de `EC: 3` à `EE: 3` (même valeur numérique). Pas besoin de changer la colonne, juste le mapping Ruby.

**Rationale**: Les enums Rails sont stockés comme integers. On change uniquement le nom Ruby (`EC` → `EE`) tout en gardant la même valeur (3). La migration de données met à jour les éventuels enregistrements existants qui référencent l'ancien nom dans d'autres contextes.

**Alternatives considered**:
- Ajouter EE comme nouvelle valeur (4) et migrer les données — rejeté car inutilement complexe, garder la même valeur numérique est plus propre

## R6 — Skip extraction communes quand session existe déjà

**Decision**: Quand une ExamSession a déjà des common_parts, le job d'extraction demande au LLM d'extraire uniquement la partie spécifique + ses corrections. Le prompt est adapté pour indiquer "la partie commune existe déjà, ignore-la".

**Rationale**: Économise des tokens et du temps de traitement. La partie commune est identique dans les 4 fichiers, pas besoin de la ré-extraire.

**Alternatives considered**:
- Toujours tout extraire puis ignorer les communes — rejeté car gaspille des tokens et augmente le risque d'erreur
- Comparer les communes extraites avec les existantes — rejeté car complexité inutile

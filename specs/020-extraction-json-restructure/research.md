# Research: Restructuration du JSON d'extraction

## R1 — Migration de base de données nécessaire ?

**Decision**: Aucune migration nécessaire.
**Rationale**: `ExamSession.presentation_text` (text) et `Subject.presentation_text` (text) existent déjà. `year` est déjà un string. Les enums `exam_type` et `region` existent avec les bonnes valeurs.
**Alternatives considered**: Ajouter une colonne `variante` sur Subject — reporté car pas utilisé dans le MVP. Ajouter une colonne `code` sur Subject — reporté pour la même raison.

## R2 — Comment le LLM identifie les deux mises en situation ?

**Decision**: Instructions explicites dans le prompt + few-shot example montrant la séparation.
**Rationale**: Dans les sujets BAC STI2D, la mise en situation commune est en début de document (avant les parties numérotées 1-5). La mise en situation spécifique est entre les parties communes et les parties spécifiques (avant les parties lettrées A/B/C). Le LLM peut les distinguer par leur position et leur contenu.
**Alternatives considered**: Extraction par regex/position de page — trop fragile, les formats varient.

## R3 — Format du code sujet

**Decision**: Le code sujet suit le format `YY-SSSSXXRRN` (ex: `24-2D2IDACPO1`). Le LLM l'extrait du PDF.
**Rationale**: Le code est toujours présent dans l'en-tête du sujet BAC. Format standard du ministère.
**Mapping region**: ME=metropole, LR=reunion, PO=polynesie, NC=nouvelle_caledonie
**Mapping variante**: 1=normale, 2=remplacement

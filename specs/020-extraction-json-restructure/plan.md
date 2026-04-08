# Implementation Plan: Restructuration du JSON d'extraction

**Branch**: `020-extraction-json-restructure` | **Date**: 2026-04-07 | **Spec**: [spec.md](spec.md)

## Summary

Restructurer le schéma JSON d'extraction et le modèle de données pour :
- Séparer les deux mises en situation (commune sur ExamSession, spécifique sur Subject)
- Ajouter code sujet et variante
- Supprimer les colonnes dupliquées entre ExamSession et Subject
- Renommer les colonnes pour cohérence (`exam_type` → `exam`, `presentation_text` → `common_presentation`/`specific_presentation`)

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Storage**: PostgreSQL via Neon
**Testing**: RSpec + FactoryBot (CI GitHub Actions)

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Fullstack Rails | ✅ | Pas de changement d'architecture |
| II. RGPD | ✅ | Pas de données personnelles impactées |
| III. Security | ✅ | Pas d'API keys impactées |
| IV. Testing | ✅ | TDD : specs mises à jour |
| V. Simplicity | ✅ | Suppression de redondance = simplification |
| VI. Workflow | ✅ | speckit complet, feature branch, PR |

## Nouveau modèle de données

### ExamSession (regroupe les données partagées)

| Colonne | Type | Action |
|---------|------|--------|
| `title` | string | Existante, inchangée |
| `year` | string | Existante, inchangée |
| `exam` | integer (enum) | **Renommer** `exam_type` → `exam` |
| `region` | integer (enum) | Existante, inchangée |
| `common_presentation` | text | **Renommer** `presentation_text` → `common_presentation` |
| `variante` | integer (enum) | **Ajouter** (normale: 0, remplacement: 1) |

### Subject (données propres à la spécialité)

| Colonne | Type | Action |
|---------|------|--------|
| `specialty` | integer (enum) | Existante, inchangée |
| `code` | string | **Ajouter** (ex: `24-2D2IDACPO1`) |
| `specific_presentation` | text | **Renommer** `presentation_text` → `specific_presentation` |
| `status` | integer (enum) | Existante, inchangée |
| `title` | string | **Supprimer** (délégué à ExamSession) |
| `year` | string | **Supprimer** (délégué à ExamSession) |
| `exam_type` | integer | **Supprimer** (délégué à ExamSession) |
| `region` | integer | **Supprimer** (délégué à ExamSession) |

### Subject model — delegates

```ruby
delegate :title, :year, :exam, :region, :common_presentation, :variante, to: :exam_session
```

## Schéma JSON d'extraction (nouveau format)

```json
{
  "metadata": {
    "title": "Complexe International Multisports et Escalade (C.I.M.E.)",
    "code": "24-2D2IDACPO1",
    "year": "2024",
    "exam": "bac",
    "specialty": "AC",
    "region": "polynesie",
    "variante": "normale"
  },
  "common_presentation": "Texte verbatim mise en situation commune...",
  "specific_presentation": "Texte verbatim mise en situation spécifique...",
  "common_parts": [...],
  "specific_parts": [...],
  "document_references": {...}
}
```

## Phases d'implémentation

### Phase 1 : Migrations

3 migrations distinctes :

**Migration 1** — Restructurer ExamSession :
- `rename_column :exam_sessions, :exam_type, :exam`
- `rename_column :exam_sessions, :presentation_text, :common_presentation`
- `add_column :exam_sessions, :variante, :integer, default: 0`

**Migration 2** — Restructurer Subject :
- `rename_column :subjects, :presentation_text, :specific_presentation`
- `add_column :subjects, :code, :string, null: false`

**Migration 3** — Supprimer les colonnes redondantes de Subject :
- `remove_column :subjects, :title`
- `remove_column :subjects, :year`
- `remove_column :subjects, :exam_type`
- `remove_column :subjects, :region`

**Migration 4** — Renommer enum value `drom_com` → `reunion` :
- `UPDATE exam_sessions SET region = 1 WHERE region = 1` (valeur inchangée, juste le nom Ruby)
- Renommage dans les modèles Ruby (pas de changement en base, l'enum est un integer)

### Phase 2 : Adapter les modèles

**Subject** :
- Supprimer les enums `exam_type` et `region` (délégués)
- Supprimer les validations sur `title`, `year`, `exam_type`, `region`
- Ajouter `delegate :title, :year, :exam, :region, :common_presentation, :variante, to: :exam_session`
- Rendre `exam_session` obligatoire (`belongs_to :exam_session` sans `optional`)

**ExamSession** :
- Renommer enum `exam_type` → `exam`
- Ajouter enum `variante` (normale: 0, remplacement: 1)

### Phase 3 : Adapter le prompt d'extraction

**`build_extraction_prompt.rb`** :
- Remplacer `presentation` par `common_presentation` + `specific_presentation`
- Modifier `metadata` : `exam_type` → `exam`, ajouter `code`, `region`, `variante`
- `year` en string
- Instructions explicites pour identifier les deux mises en situation
- Mettre à jour le few-shot example

### Phase 4 : Adapter la persistence

**`persist_extracted_data.rb`** :
- Lire `data["common_presentation"]` → `exam_session.common_presentation`
- Lire `data["specific_presentation"]` → `subject.specific_presentation`
- Lire `metadata["exam"]` → `exam_session.exam`
- Lire `metadata["code"]` → `subject.code`
- Lire `metadata["variante"]` → `exam_session.variante`
- Lire `metadata["region"]` → `exam_session.region`

### Phase 5 : Adapter les specs

- `spec/services/build_extraction_prompt_spec.rb` — nouveaux champs
- `spec/services/persist_extracted_data_spec.rb` — nouvelle fixture JSON, assertions
- `spec/factories/` — adapter les factories (subjects, exam_sessions)
- Toutes les specs qui référencent `subject.title`, `subject.year`, etc.

### Phase 6 : Adapter les vues et controllers

Grâce aux delegates, la majorité des vues ne changent pas (`subject.title` fonctionne toujours). Vérifier :
- Les controllers qui créent des Subject (teacher)
- Les formulaires qui éditent title/year/region sur Subject
- Les partials qui affichent la présentation

### Phase 7 : Régénérer le seed

1. Relancer l'extraction avec le nouveau prompt → nouveau JSON
2. Remplacer `db/seeds/development/claude_extraction.json`
3. Adapter `db/seeds/development.rb` pour le nouveau format
4. Vérifier `bin/rails db:seed:replant`

### Phase 8 : Validation

1. CI verte
2. `bin/rails db:seed:replant` fonctionne
3. `bin/rails db:migrate:rollback` fonctionne pour chaque migration

## Risques

- **Suppression de colonnes sur Subject** : toutes les références à `subject.title`, `subject.year` etc. doivent être couvertes par les delegates. Grep exhaustif nécessaire avant la migration.
- **ExamSession obligatoire** : les sujets existants sans ExamSession devront être migrés. Le seed replant résout ça pour le dev.
- **Formulaire enseignant** : le formulaire de création de sujet doit être adapté (title/year/region sur ExamSession, pas sur Subject).

# Data Model: Restructuration du JSON d'extraction

## Avant / Après

### ExamSession

| Colonne | Avant | Après |
|---------|-------|-------|
| title | ✅ | ✅ |
| year | ✅ | ✅ |
| exam_type | ✅ | **→ exam** (renommé) |
| region | ✅ (enum `drom_com`) | ✅ (enum renommé `reunion`) |
| presentation_text | ✅ | **→ common_presentation** (renommé) |
| variante | ❌ | **✅ ajouté** (enum: normale, remplacement) |

### Subject

| Colonne | Avant | Après |
|---------|-------|-------|
| title | ✅ | **❌ supprimé** (délégué à ExamSession) |
| year | ✅ | **❌ supprimé** (délégué à ExamSession) |
| exam_type | ✅ | **❌ supprimé** (délégué à ExamSession) |
| region | ✅ | **❌ supprimé** (délégué à ExamSession) |
| specialty | ✅ | ✅ |
| status | ✅ | ✅ |
| presentation_text | ✅ | **→ specific_presentation** (renommé) |
| code | ❌ | **✅ ajouté** (string, obligatoire, ex: 24-2D2IDACPO1) |

### Delegates sur Subject

```ruby
delegate :title, :year, :exam, :region, :common_presentation, :variante, to: :exam_session
```

## Relations

```
ExamSession (BAC STI2D 2024 Polynésie)
  ├─ title, year, exam, region, common_presentation, variante
  ├─ common_parts (Part, section_type: :common)
  │
  ├─ Subject (AC) → specialty, code, specific_presentation, status
  │     └─ parts (specific)
  ├─ Subject (SIN) → specialty, code, specific_presentation, status
  │     └─ parts (specific)
  ├─ Subject (ITEC)
  └─ Subject (EE)
```

## Schéma JSON d'extraction

```json
{
  "metadata": {
    "title": "string",
    "code": "string (ex: 24-2D2IDACPO1)",
    "year": "string (ex: 2024)",
    "exam": "string (bac | bts | autre)",
    "specialty": "string (AC | SIN | ITEC | EE)",
    "region": "string (metropole | reunion | polynesie | nouvelle_caledonie)",
    "variante": "string (normale | remplacement)"
  },
  "common_presentation": "string (texte verbatim)",
  "specific_presentation": "string (texte verbatim)",
  "common_parts": [...],
  "specific_parts": [...],
  "document_references": {...}
}
```

## Mapping JSON → Base de données

| Champ JSON | Destination | Colonne |
|-----------|-------------|---------|
| `metadata.title` | ExamSession | `title` |
| `metadata.year` | ExamSession | `year` |
| `metadata.exam` | ExamSession | `exam` |
| `metadata.region` | ExamSession | `region` |
| `metadata.variante` | ExamSession | `variante` |
| `metadata.specialty` | Subject | `specialty` |
| `metadata.code` | Subject | `code` |
| `common_presentation` | ExamSession | `common_presentation` |
| `specific_presentation` | Subject | `specific_presentation` |

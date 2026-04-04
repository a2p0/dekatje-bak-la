# Data Model: Consolidation de l'extraction PDF

## New Entity: ExamSession

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| id | bigint | PK | |
| title | string | NOT NULL | ex: "Polynésie 2024 CIME" |
| year | string | NOT NULL | ex: "2024" |
| region | integer | NOT NULL, default: 0 | enum: metropole(0), drom_com(1), polynesie(2), candidat_libre(3) |
| exam_type | integer | NOT NULL, default: 0 | enum: bac(0), bts(1), autre(2) |
| presentation_text | text | nullable | Mise en situation commune |
| owner_id | bigint | FK → users, NOT NULL | |
| timestamps | | | |

**Indexes**: `[owner_id, year, region]`

**Associations**:
- `belongs_to :owner, class_name: "User"`
- `has_many :subjects, dependent: :restrict_with_error`
- `has_many :common_parts, -> { where(section_type: :common) }, class_name: "Part", foreign_key: :exam_session_id, dependent: :destroy`

**Validations**: title, year, region, exam_type presence

---

## Modified Entity: Subject

### New/Changed Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| exam_session_id | ADD | bigint | FK → exam_sessions, nullable | Nullable pour rétrocompat anciens sujets |
| specialty | MODIFY enum | integer | | Rename EC(3) → EE(3), remove tronc_commun usage |

### New Attachments
- `has_one_attached :subject_pdf` — PDF sujet monolithique
- `has_one_attached :correction_pdf` — PDF corrigé

### Changed Associations
- `belongs_to :exam_session, optional: true`

### Changed Validations
- Conditional: si `subject_pdf` attaché → valider `subject_pdf` + `correction_pdf` (nouveau flow)
- Conditional: si `enonce_file` attaché → valider les 5 anciens fichiers (rétrocompat)
- `presentation_text` : colonne conservée sur Subject (rétrocompat anciens sujets). Pour les nouveaux sujets (avec ExamSession), la mise en situation est stockée sur `ExamSession#presentation_text`. Le Subject peut déléguer via `subject.exam_session&.presentation_text || subject.presentation_text`.

---

## Modified Entity: Part

### New/Changed Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| exam_session_id | ADD | bigint | FK → exam_sessions, nullable | Pour les parties communes |
| subject_id | MODIFY | bigint | FK → subjects, nullable (était NOT NULL) | Nullable pour les parties communes |
| specialty | ADD | integer | nullable | enum: SIN(0), ITEC(1), EE(2), AC(3) — pour les parts spécifiques |
| document_references | ADD | jsonb | default: [] | ex: `[{"label":"DT1","title":"Diagrammes SysML","pages":[13,14]}]` |

### Check Constraint
```sql
CHECK (
  (exam_session_id IS NOT NULL AND subject_id IS NULL) OR
  (exam_session_id IS NULL AND subject_id IS NOT NULL)
)
```

### Changed Associations
- `belongs_to :exam_session, optional: true`
- `belongs_to :subject, optional: true`

### State Rules
- **Partie commune** : `section_type: :common`, `exam_session_id` set, `subject_id: nil`
- **Partie spécifique** : `section_type: :specific`, `subject_id` set, `exam_session_id: nil`, `specialty` set

---

## Modified Entity: Question

### New Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| dt_references | ADD | jsonb | default: [] | ex: `["DT1", "DT3"]` |
| dr_references | ADD | jsonb | default: [] | ex: `["DR2"]` |

---

## Modified Entity: Student

### New Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| specialty | ADD | integer | nullable | enum: SIN(0), ITEC(1), EE(2), AC(3) |

---

## Modified Entity: StudentSession

### New Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| part_filter | ADD | integer | NOT NULL, default: 0 | enum: full(0), common_only(1), specific_only(2) |

---

## Modified Entity: ExtractionJob

### Changed Fields

| Field | Change | Type | Constraints | Notes |
|-------|--------|------|-------------|-------|
| exam_session_id | ADD | bigint | FK → exam_sessions, nullable | |

`subject_id` reste NOT NULL (chaque extraction est liée à un sujet).

---

## Relationship Diagram

```
User (teacher)
├── has_many :exam_sessions
│   ├── has_many :subjects
│   │   ├── has_many :parts (specific only, section_type: specific)
│   │   │   └── has_many :questions
│   │   │       └── has_one :answer
│   │   ├── has_one :extraction_job
│   │   ├── has_one_attached :subject_pdf
│   │   └── has_one_attached :correction_pdf
│   └── has_many :common_parts (section_type: common)
│       └── has_many :questions
│           └── has_one :answer
└── has_many :classrooms
    └── has_many :students
        ├── specialty (enum, optional)
        └── has_many :student_sessions
            ├── belongs_to :subject
            └── part_filter (enum: full/common_only/specific_only)
```

## Migration Order

1. `rename_ec_to_ee` — rename enum value in existing data
2. `create_exam_sessions` — new table
3. `add_exam_session_to_subjects` — add FK
4. `add_shared_parts_support` — Part: add exam_session_id, make subject_id nullable, add specialty, document_references, add check constraint
5. `add_dt_dr_references_to_questions` — Question: add dt_references, dr_references
6. `add_specialty_to_students` — Student: add specialty
7. `add_part_filter_to_student_sessions` — StudentSession: add part_filter
8. `update_extraction_jobs` — ExtractionJob: add exam_session_id

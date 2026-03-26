# Data Model: DekatjeBakLa

**Branch**: `001-bac-training-app` | **Date**: 2026-03-26

## Entités et relations

```
User (enseignant)
  email: string, not null, unique
  encrypted_password: string (Devise)
  first_name: string, not null
  last_name: string, not null
  encrypted_api_key: string
  encrypted_api_key_iv: string
  api_provider: integer (enum: anthropic:0, openrouter:1, openai:2, google:3)
  → has_many :classrooms
  → has_many :subjects

Classroom
  name: string, not null
  school_year: string, not null
  specialty: string
  access_code: string, not null, unique  ← slug URL login élève
  owner_id: integer (FK → users)
  → belongs_to :owner (User)
  → has_many :students
  → has_many :classroom_subjects
  → has_many :subjects, through: :classroom_subjects

Student
  first_name: string, not null
  last_name: string, not null
  username: string, not null, unique dans la classroom
  password_digest: string (bcrypt)
  encrypted_api_key: string
  encrypted_api_key_iv: string
  api_provider: integer (enum: openrouter:0, anthropic:1, openai:2, google:3)
  classroom_id: integer (FK → classrooms)
  → belongs_to :classroom
  → has_many :student_sessions

ClassroomSubject (jointure)
  classroom_id: integer
  subject_id: integer

Subject
  title: string, not null
  year: string
  exam_type: integer (enum: bac:0, bts:1, autre:2)
  specialty: integer (enum: tronc_commun:0, SIN:1, ITEC:2, EC:3, AC:4)
  status: integer (enum: draft:0, pending_validation:1, published:2, archived:3)
  presentation_text: text
  discarded_at: datetime  ← soft delete
  owner_id: integer (FK → users)
  → belongs_to :owner (User)
  → has_many :parts
  → has_many :technical_documents
  → has_many :classroom_subjects
  → has_one :extraction_job

TechnicalDocument
  doc_type: integer (enum: DT:0, DR:1)
  number: integer, not null
  title: string
  subject_id: integer (FK → subjects)
  → has_one_attached :file        ← PDF principal
  → has_one_attached :filled_file ← DR corrigé (optionnel)
  → belongs_to :subject
  → has_many :question_documents
  → has_many :questions, through: :question_documents

Part
  number: integer, not null
  title: string
  objective_text: text
  section_type: integer (enum: common:0, specific:1)
  position: integer
  subject_id: integer (FK → subjects)
  → belongs_to :subject
  → has_many :questions

Question
  number: string (ex: "1.1", "2.3")
  label: text, not null
  context_text: text
  points: decimal
  answer_type: integer (enum: text:0, calculation:1, argumentation:2,
                               dr_reference:3, completion:4, choice:5)
  position: integer
  status: integer (enum: draft:0, validated:1)
  discarded_at: datetime  ← soft delete
  part_id: integer (FK → parts)
  → belongs_to :part
  → has_many :question_documents
  → has_many :technical_documents, through: :question_documents
  → has_one :answer

QuestionDocument (jointure)
  question_id: integer
  technical_document_id: integer

Answer
  correction_text: text
  explanation_text: text
  key_concepts: jsonb (array of strings)
  data_hints: jsonb (array of {source, location})
  question_id: integer (FK → questions)
  → belongs_to :question

ExtractionJob
  status: integer (enum: pending:0, processing:1, done:2, failed:3)
  raw_json: jsonb
  error_message: text
  provider_used: integer (enum: teacher:0, server:1)
  subject_id: integer (FK → subjects)
  → belongs_to :subject

StudentSession
  mode: integer (enum: autonomous:0, tutored:1)
  progression: jsonb  ← {question_id: {seen: bool, answered: bool}}
  annotations: jsonb  ← RÉSERVÉ post-MVP
  started_at: datetime
  last_activity_at: datetime
  student_id: integer (FK → students)
  subject_id: integer (FK → subjects)
  → belongs_to :student
  → belongs_to :subject
  → has_many :conversations

Conversation
  messages: jsonb (array de {role, content, timestamp})
  provider_used: string
  tokens_used: integer
  student_session_id: integer (FK → student_sessions)
  question_id: integer (FK → questions)
  → belongs_to :student_session
  → belongs_to :question
```

## State transitions

### Subject#status
```
draft → pending_validation (après extraction réussie)
pending_validation → published (après validation enseignant)
published → archived (dépublication)
published → draft (retour édition)
```

### Question#status
```
draft → validated (validation enseignant)
validated → draft (retour édition)
```

### ExtractionJob#status
```
pending → processing (Sidekiq démarre le job)
processing → done (extraction réussie)
processing → failed (erreur API ou parsing)
failed → pending (retry enseignant)
```

## Index importants

- `classrooms.access_code` — unique, recherche par URL
- `students.username + classroom_id` — unique composite
- `subjects.discarded_at` — filtre soft delete
- `questions.discarded_at` — filtre soft delete
- `student_sessions.student_id + subject_id` — unique composite

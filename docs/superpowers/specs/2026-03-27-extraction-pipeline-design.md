# Design: PDF Extraction Pipeline

**Date**: 2026-03-27
**Branch**: `004-extraction-pipeline`
**Scope**: Modèles Part/Question/Answer, services extraction, job Sidekiq, notification Turbo Stream

---

## Architecture

Job Sidekiq `ExtractQuestionsJob` déclenché automatiquement à la création du sujet. Lit le PDF énoncé via `pdf-reader`, envoie à Claude API via Faraday, parse le JSON, persiste les modèles hiérarchiques. Notification temps réel via Turbo Stream ActionCable. Retry manuel si échec.

---

## Modèles

### `Part`
```
number: integer, not null
title: string, not null
objective_text: text
section_type: integer (enum: common:0, specific:1), not null, default: 0
position: integer, not null, default: 0
subject_id: FK → subjects
```
- `belongs_to :subject`
- `has_many :questions, dependent: :destroy`

### `Question`
```
number: string (ex: "1.2"), not null
label: text, not null
context_text: text
points: decimal
answer_type: integer (enum: text:0, calculation:1, argumentation:2, dr_reference:3, completion:4, choice:5)
position: integer, not null, default: 0
status: integer (enum: draft:0, validated:1), not null, default: 0
discarded_at: datetime
part_id: FK → parts
```
- `belongs_to :part`
- `has_one :answer, dependent: :destroy`
- Soft delete via `discarded_at`
- `scope :kept, -> { where(discarded_at: nil) }`

### `Answer`
```
correction_text: text
explanation_text: text
key_concepts: jsonb (array of strings)
data_hints: jsonb (array of {source, location})
question_id: FK → questions
```
- `belongs_to :question`

---

## Services

### `ResolveApiKey`
```ruby
ResolveApiKey.call(user:)
# → { api_key: String, provider: Symbol }
# Priorité : user.api_key (avec user.api_provider) || ENV['ANTHROPIC_API_KEY'] (provider: :anthropic)
```

### `AiClientFactory`
```ruby
AiClientFactory.build(provider:, api_key:)
# → objet avec .call(messages:, system:, max_tokens:, temperature:) → String
# Providers : anthropic, openrouter, openai, google
# Timeout Faraday : 60 secondes
```

Endpoints par provider :
| Provider | Base URL | Auth header |
|----------|----------|-------------|
| anthropic | https://api.anthropic.com/v1 | x-api-key |
| openrouter | https://openrouter.ai/api/v1 | Authorization: Bearer |
| openai | https://api.openai.com/v1 | Authorization: Bearer |
| google | https://generativelanguage.googleapis.com/v1beta | x-goog-api-key |

### `BuildExtractionPrompt`
```ruby
BuildExtractionPrompt.call(text:)
# → { system: String, messages: Array<{role:, content:}> }
```

System prompt : demande à Claude d'extraire les questions, corrections, data_hints en JSON structuré selon le schéma cible.

### `ExtractQuestionsFromPdf`
```ruby
ExtractQuestionsFromPdf.call(subject:, api_key:, provider:)
# → Hash (JSON parsé)
# 1. Télécharge le blob enonce_file depuis ActiveStorage
# 2. Lit le texte avec PDF::Reader
# 3. Appelle BuildExtractionPrompt + AiClientFactory
# 4. Parse et retourne le Hash
```

### `PersistExtractedData`
```ruby
PersistExtractedData.call(subject:, data:)
# → Subject mis à jour
# Persiste dans une transaction :
#   subject.update!(presentation_text: data["presentation"], status: :pending_validation)
#   Crée Parts → Questions → Answers depuis data["parts"]
```

---

## JSON cible

```json
{
  "presentation": "Mise en situation générale du sujet...",
  "parts": [{
    "number": 1,
    "title": "Titre de la partie",
    "objective": "Objectif pédagogique",
    "section_type": "common",
    "questions": [{
      "number": "1.2",
      "label": "Énoncé complet",
      "context": "Contexte local optionnel",
      "points": 2,
      "answer_type": "calculation",
      "correction": "Réponse officielle",
      "explanation": "Explication pédagogique",
      "data_hints": [
        {"source": "DT", "location": "tableau ligne Consommation"},
        {"source": "enonce", "location": "distance 186 km"}
      ],
      "key_concepts": ["énergie primaire", "rendement"]
    }]
  }]
}
```

`answer_type` valeurs : `"text"`, `"calculation"`, `"argumentation"`, `"dr_reference"`, `"completion"`, `"choice"`
`data_hints.source` valeurs : `"DT"`, `"DR"`, `"enonce"`, `"question_context"`

---

## Job Sidekiq

### `ExtractQuestionsJob`
```ruby
class ExtractQuestionsJob < ApplicationJob
  queue_as :extraction

  def perform(subject_id)
    subject = Subject.find(subject_id)
    job = subject.extraction_job
    job.update!(status: :processing)

    resolved = ResolveApiKey.call(user: subject.owner)
    data = ExtractQuestionsFromPdf.call(
      subject: subject,
      api_key: resolved[:api_key],
      provider: resolved[:provider]
    )
    PersistExtractedData.call(subject: subject, data: data)

    provider_used = subject.owner.api_key.present? ? :teacher : :server
    job.update!(status: :done, provider_used: provider_used)

    broadcast_extraction_status(subject)
  rescue => e
    job&.update!(status: :failed, error_message: e.message)
    broadcast_extraction_status(subject)
  end
end
```

**Déclenchement** : `ExtractQuestionsJob.perform_later(@subject.id)` dans `SubjectsController#create` après `create_extraction_job!`.

**Retry manuel** : action `retry_extraction` (POST) dans `SubjectsController` — remet `extraction_job.status` → `pending` et ré-enqueue le job.

---

## Turbo Stream notification

- Vue `show` : `<%= turbo_stream_from "subject_#{@subject.id}" %>`
- Partial `app/views/teacher/subjects/_extraction_status.html.erb` (statut + erreur)
- Le job broadcast via `Turbo::StreamsChannel.broadcast_replace_to("subject_#{subject.id}", target: "extraction-status", partial: "teacher/subjects/extraction_status", locals: { subject: subject })`

---

## Configuration

### Sidekiq
```yaml
# config/sidekiq.yml
:queues:
  - default
  - extraction
```

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

### ActionCable (Redis)
```yaml
# config/cable.yml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>

production:
  adapter: redis
  url: <%= ENV["REDIS_URL"] %>
```

---

## Routes

```ruby
resources :subjects, only: [ :index, :new, :create, :show ] do
  member do
    patch :publish
    patch :archive
    post  :retry_extraction
  end
end
```

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_create_parts.rb
  TIMESTAMP_create_questions.rb
  TIMESTAMP_create_answers.rb

app/models/
  part.rb
  question.rb
  answer.rb

app/jobs/
  extract_questions_job.rb

app/services/
  resolve_api_key.rb
  ai_client_factory.rb
  build_extraction_prompt.rb
  extract_questions_from_pdf.rb
  persist_extracted_data.rb

app/views/teacher/subjects/
  _extraction_status.html.erb

config/sidekiq.yml
config/cable.yml (modifié)
config/application.rb (modifié)
config/routes.rb (modifié)

spec/models/
  part_spec.rb
  question_spec.rb
  answer_spec.rb

spec/services/
  resolve_api_key_spec.rb
  ai_client_factory_spec.rb
  build_extraction_prompt_spec.rb
  extract_questions_from_pdf_spec.rb
  persist_extracted_data_spec.rb

spec/jobs/
  extract_questions_job_spec.rb

spec/factories/
  parts.rb
  questions.rb
  answers.rb
```

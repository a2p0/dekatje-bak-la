# Design: Student Mode 2 — Tutorat IA Streaming (F9)

**Date**: 2026-03-29
**Branch**: `009-student-mode2-tutor`
**Scope**: Chat tutorat IA avec streaming ActionCable, mémoire structurée (StudentInsight), prompt configurable par prof

---

## Architecture

Chat drawer à droite de la page question (desktop), overlay plein écran (mobile). L'élève envoie un message, un job Sidekiq appelle l'IA et streame les tokens via ActionCable. En fin de conversation, les insights structurés sont extraits (concepts maîtrisés, lacunes, erreurs). Le system prompt est configurable par le professeur (champ en base, fallback template par défaut).

---

## Migrations requises

### `CreateConversations`
```
student_id: FK → students
question_id: FK → questions
messages: jsonb, default: []
provider_used: string
tokens_used: integer, default: 0
timestamps
```

### `CreateStudentInsights`
```
student_id: FK → students
subject_id: FK → subjects
question_id: FK → questions (nullable)
insight_type: string
concept: string
text: text
timestamps
index: [student_id, subject_id]
```

### `AddTutorPromptTemplateToUsers`
```
tutor_prompt_template: text (nullable)
```

---

## Routes

```ruby
scope "/:access_code", as: :student do
  # existing routes...
  resources :conversations, only: [:create] do
    member do
      post :message
    end
  end
end
```

---

## Modèles

### `Conversation`
```ruby
belongs_to :student
belongs_to :question

validates :student_id, presence: true
validates :question_id, presence: true
```

### `StudentInsight`
```ruby
belongs_to :student
belongs_to :subject
belongs_to :question, optional: true

validates :insight_type, inclusion: { in: %w[mastered struggle misconception note] }
validates :concept, presence: true
```

### `Student` (ajouts)
```ruby
has_many :conversations, dependent: :destroy
has_many :student_insights, dependent: :destroy
```

### `Question` (ajouts)
```ruby
has_many :conversations, dependent: :destroy
```

### `User` (ajout)
```ruby
# tutor_prompt_template: text — configurable par le prof
```

---

## Controllers

### `Student::ConversationsController`
- `create` — trouve ou crée une Conversation pour la question. Vérifie que l'élève a une clé API configurée (sinon redirect avec message + lien settings). Retourne la conversation en JSON ou redirect.
- `message` — ajoute le message élève à conversation.messages, enqueue `TutorStreamJob`. Retourne un Turbo Stream.

---

## Services

### `BuildTutorPrompt`
Assemble le system prompt :
1. Template : `subject.owner.tutor_prompt_template.presence || DEFAULT_TEMPLATE`
2. Interpolation des variables : `%{specialty}`, `%{part_title}`, `%{objective_text}`, `%{question_label}`, `%{context_text}`, `%{correction_text}`
3. Append les StudentInsights existants pour cet élève/sujet

**DEFAULT_TEMPLATE :**
```
Tu es un tuteur bienveillant pour des élèves de Terminale préparant le BAC.
Spécialité : %{specialty}. Partie : %{part_title}. Objectif : %{objective_text}.
Question : %{question_label}. Contexte local : %{context_text}.
Correction officielle (confidentielle) : %{correction_text}.
Règle absolue : ne donne JAMAIS la réponse directement.
Guide l'élève par étapes, valorise ses tentatives, pose des questions.
Propose une fiche de révision si un concept clé est identifié.
Réponds en français, niveau lycée, de façon bienveillante.
```

### `ExtractStudentInsights`
Appelé en fin de conversation. Déclencheur : dans `Student::QuestionsController#show`, si une conversation existait pour la question précédente (stockée en `session[:last_conversation_id]`), on enqueue `ExtractStudentInsightsJob` pour cette conversation :
1. Envoie la conversation à l'IA avec un prompt d'extraction JSON
2. Parse : `[{type: "mastered", concept: "...", text: "..."}, ...]`
3. Crée les `StudentInsight` records

---

## Jobs

### `TutorStreamJob` (Sidekiq, queue: :default)
1. Charge la conversation, question, student
2. Appelle `BuildTutorPrompt` pour le system prompt
3. Appelle `AiClientFactory#stream` avec le modèle de l'élève
4. Broadcast chaque token via ActionCable : `{ token: "..." }`
5. En fin de stream : sauvegarde la réponse dans conversation.messages, met à jour tokens_used
6. Broadcast `{ done: true }`
7. En cas d'erreur : broadcast `{ error: "message" }`

---

## AiClientFactory (modifications)

- `build(provider:, api_key:, model: nil)` — model stocké à l'initialisation, utilisé dans `build_body` et `endpoint_path` (Google)
- `stream(messages:, system:, max_tokens:, temperature:, &block)` — nouvelle méthode, yield chaque token
- Parsing SSE par provider :
  - Anthropic : `event: content_block_delta`, `data: {"delta":{"text":"..."}}`
  - OpenRouter/OpenAI : `data: {"choices":[{"delta":{"content":"..."}}]}`
  - Google : chunks JSON `{"candidates":[{"content":{"parts":[{"text":"..."}]}}]}`
- Rétrocompatible : `call` continue de fonctionner sans `model:` (utilise les defaults hardcodés)

---

## ActionCable

### `TutorChannel`
```ruby
class TutorChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find(params[:conversation_id])
    stream_from "conversation_#{conversation.id}"
  end
end
```

### Connection élève
Adapter `ApplicationCable::Connection` pour identifier les élèves via `session[:student_id]` en plus de Devise pour les teachers.

---

## Frontend

### `chat_controller.js` (Stimulus)
- Targets : messages container, input, send button, drawer, backdrop
- `open()` / `close()` — toggle drawer chat (CSS responsive : drawer fixe à droite desktop, overlay mobile)
- `send()` — POST le message, disable l'input, affiche le message élève, crée placeholder réponse IA
- Souscription ActionCable au channel `TutorChannel`
- `onToken(token)` — append le token au placeholder réponse
- `onDone()` — re-enable l'input
- `onError(message)` — affiche le message d'erreur dans le chat

### Modifications `questions/show.html.erb`
- Bouton "💬 Tutorat" dans la top bar
- Drawer chat à droite (même pattern CSS que sidebar mais côté opposé)
- Si pas de clé API → bouton affiche message + lien settings

---

## Sécurité

- Conversation scoped à `current_student`
- Correction dans le system prompt uniquement, jamais côté client
- ActionCable : vérifier que le student a accès à la conversation
- Rate limit : max 1 message en attente par conversation (flag `streaming` sur Conversation)
- Tokens tracking sur `Conversation#tokens_used`, pas de limite MVP

---

## Gestion d'erreurs

| Erreur | Comportement |
|--------|-------------|
| Pas de clé API | Message "Configurez votre clé IA" + lien settings. Job non lancé. |
| Clé invalide (401) | Broadcast `{ error: "Clé API invalide. Vérifiez vos réglages." }` |
| Crédits insuffisants (402/429) | Broadcast `{ error: "Crédits insuffisants sur votre compte [provider]." }` |
| Timeout | Broadcast `{ error: "Le serveur n'a pas répondu. Réessayez." }` |

Dans tous les cas l'élève peut continuer en Mode 1.

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_create_conversations.rb
  TIMESTAMP_create_student_insights.rb
  TIMESTAMP_add_tutor_prompt_template_to_users.rb

app/models/
  conversation.rb
  student_insight.rb
  student.rb (modifié)
  question.rb (modifié)

app/controllers/student/
  conversations_controller.rb

app/services/
  build_tutor_prompt.rb
  extract_student_insights.rb
  ai_client_factory.rb (modifié — model param + stream method)

app/jobs/
  tutor_stream_job.rb

app/channels/
  tutor_channel.rb
  application_cable/connection.rb (modifié)

app/views/student/
  questions/show.html.erb (modifié — ajout drawer chat)
  questions/_chat_drawer.html.erb

app/javascript/controllers/
  chat_controller.js

spec/models/
  conversation_spec.rb
  student_insight_spec.rb

spec/services/
  build_tutor_prompt_spec.rb
  extract_student_insights_spec.rb

spec/jobs/
  tutor_stream_job_spec.rb

spec/channels/
  tutor_channel_spec.rb

spec/requests/student/
  conversations_spec.rb

spec/factories/
  conversations.rb
  student_insights.rb
```

# Student Mode 2 — Tutorat IA Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AI tutoring chat with streaming responses via ActionCable, structured memory (StudentInsight), and configurable tutor prompt.

**Architecture:** Conversation and StudentInsight models, TutorStreamJob with ActionCable broadcast, AiClientFactory adapted for model selection and streaming, BuildTutorPrompt service, chat drawer UI with Stimulus.

**Tech Stack:** Rails 8.1, ActionCable, Sidekiq, Hotwire/Turbo Streams, Stimulus, RSpec

---

## Fichiers creees/modifies

| Fichier | Action | Responsabilite |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_create_conversations.rb` | Creer | Table Conversation |
| `db/migrate/TIMESTAMP_create_student_insights.rb` | Creer | Table StudentInsight |
| `db/migrate/TIMESTAMP_add_tutor_prompt_template_to_users.rb` | Creer | Champ tutor_prompt_template sur User |
| `app/models/conversation.rb` | Creer | Modele Conversation |
| `app/models/student_insight.rb` | Creer | Modele StudentInsight |
| `app/models/student.rb` | Modifier | has_many :conversations, :student_insights |
| `app/models/question.rb` | Modifier | has_many :conversations |
| `app/services/ai_client_factory.rb` | Modifier | model: param + stream method |
| `app/services/build_tutor_prompt.rb` | Creer | Assemble system prompt tutorat |
| `app/services/extract_student_insights.rb` | Creer | Extrait insights depuis conversation |
| `app/jobs/tutor_stream_job.rb` | Creer | Job Sidekiq streaming IA |
| `app/jobs/extract_student_insights_job.rb` | Creer | Job extraction insights |
| `app/channels/application_cable/connection.rb` | Creer | Identification student/user |
| `app/channels/application_cable/channel.rb` | Creer | Base channel |
| `app/channels/tutor_channel.rb` | Creer | Channel ActionCable tutorat |
| `app/controllers/student/conversations_controller.rb` | Creer | create + message |
| `app/views/student/questions/_chat_drawer.html.erb` | Creer | Drawer chat |
| `app/views/student/questions/show.html.erb` | Modifier | Ajout bouton tutorat + drawer |
| `config/routes.rb` | Modifier | Routes conversations |
| `config/importmap.rb` | Modifier | Pin @rails/actioncable |
| `app/javascript/application.js` | Modifier | Import ActionCable |
| `app/javascript/controllers/chat_controller.js` | Creer | Stimulus chat controller |
| `spec/models/conversation_spec.rb` | Creer | Tests modele |
| `spec/models/student_insight_spec.rb` | Creer | Tests modele |
| `spec/factories/conversations.rb` | Creer | Factory |
| `spec/factories/student_insights.rb` | Creer | Factory |
| `spec/services/ai_client_factory_spec.rb` | Modifier | Tests model param + stream |
| `spec/services/build_tutor_prompt_spec.rb` | Creer | Tests service |
| `spec/services/extract_student_insights_spec.rb` | Creer | Tests service |
| `spec/jobs/tutor_stream_job_spec.rb` | Creer | Tests job |
| `spec/jobs/extract_student_insights_job_spec.rb` | Creer | Tests job |
| `spec/channels/tutor_channel_spec.rb` | Creer | Tests channel |
| `spec/requests/student/conversations_spec.rb` | Creer | Tests request |

---

## Task 1 : Migrations (Conversation, StudentInsight, tutor_prompt_template on User)

**Files:**
- Create: `db/migrate/TIMESTAMP_create_conversations.rb`
- Create: `db/migrate/TIMESTAMP_create_student_insights.rb`
- Create: `db/migrate/TIMESTAMP_add_tutor_prompt_template_to_users.rb`

- [ ] **Step 1 : Generer les migrations**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bin/rails generate migration CreateConversations student:references question:references messages:jsonb provider_used:string tokens_used:integer
```

```bash
bin/rails generate migration CreateStudentInsights student:references subject:references question:references insight_type:string concept:string text:text
```

```bash
bin/rails generate migration AddTutorPromptTemplateToUsers tutor_prompt_template:text
```

- [ ] **Step 2 : Editer la migration CreateConversations**

```ruby
# db/migrate/TIMESTAMP_create_conversations.rb
class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :student, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.jsonb :messages, default: [], null: false
      t.string :provider_used
      t.integer :tokens_used, default: 0, null: false
      t.boolean :streaming, default: false, null: false
      t.timestamps
    end

    add_index :conversations, [:student_id, :question_id]
  end
end
```

- [ ] **Step 3 : Editer la migration CreateStudentInsights**

```ruby
# db/migrate/TIMESTAMP_create_student_insights.rb
class CreateStudentInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :student_insights do |t|
      t.references :student, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :question, null: true, foreign_key: true
      t.string :insight_type, null: false
      t.string :concept, null: false
      t.text :text
      t.timestamps
    end

    add_index :student_insights, [:student_id, :subject_id]
  end
end
```

- [ ] **Step 4 : Editer la migration AddTutorPromptTemplateToUsers**

```ruby
# db/migrate/TIMESTAMP_add_tutor_prompt_template_to_users.rb
class AddTutorPromptTemplateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tutor_prompt_template, :text
  end
end
```

- [ ] **Step 5 : Migrer**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bin/rails db:migrate
```

Resultat attendu :
```
CreateConversations: migrated
CreateStudentInsights: migrated
AddTutorPromptTemplateToUsers: migrated
```

- [ ] **Step 6 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add migrations for Conversation, StudentInsight, tutor_prompt_template

Three migrations:
- conversations: messages jsonb, provider_used, tokens_used, streaming flag
- student_insights: insight_type, concept, text with student+subject index
- users: tutor_prompt_template text column for custom prompt

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Conversation + StudentInsight models + factories + specs

**Files:**
- Create: `app/models/conversation.rb`
- Create: `app/models/student_insight.rb`
- Create: `spec/models/conversation_spec.rb`
- Create: `spec/models/student_insight_spec.rb`
- Create: `spec/factories/conversations.rb`
- Create: `spec/factories/student_insights.rb`
- Modify: `app/models/student.rb`
- Modify: `app/models/question.rb`

- [ ] **Step 1 : Creer app/models/conversation.rb**

```ruby
# app/models/conversation.rb
class Conversation < ApplicationRecord
  belongs_to :student
  belongs_to :question

  validates :student_id, presence: true
  validates :question_id, presence: true

  def add_message!(role:, content:)
    messages << { "role" => role, "content" => content, "at" => Time.current.iso8601 }
    save!
  end

  def messages_for_api
    messages.map { |m| { role: m["role"], content: m["content"] } }
  end
end
```

- [ ] **Step 2 : Creer app/models/student_insight.rb**

```ruby
# app/models/student_insight.rb
class StudentInsight < ApplicationRecord
  belongs_to :student
  belongs_to :subject
  belongs_to :question, optional: true

  INSIGHT_TYPES = %w[mastered struggle misconception note].freeze

  validates :insight_type, inclusion: { in: INSIGHT_TYPES }
  validates :concept, presence: true
end
```

- [ ] **Step 3 : Modifier app/models/student.rb — ajouter les associations**

Ajouter apres `has_many :student_sessions, dependent: :destroy` :

```ruby
  has_many :conversations, dependent: :destroy
  has_many :student_insights, dependent: :destroy
```

- [ ] **Step 4 : Modifier app/models/question.rb — ajouter l'association**

Ajouter apres `has_one :answer, dependent: :destroy` :

```ruby
  has_many :conversations, dependent: :destroy
```

- [ ] **Step 5 : Creer spec/factories/conversations.rb**

```ruby
# spec/factories/conversations.rb
FactoryBot.define do
  factory :conversation do
    association :student
    association :question
    messages { [] }
    provider_used { "anthropic" }
    tokens_used { 0 }
    streaming { false }
  end
end
```

- [ ] **Step 6 : Creer spec/factories/student_insights.rb**

```ruby
# spec/factories/student_insights.rb
FactoryBot.define do
  factory :student_insight do
    association :student
    association :subject
    association :question
    insight_type { "mastered" }
    concept { "energie primaire" }
    text { "L'eleve comprend le concept d'energie primaire." }
  end
end
```

- [ ] **Step 7 : Creer spec/models/conversation_spec.rb**

```ruby
# spec/models/conversation_spec.rb
require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "associations" do
    it "belongs to student" do
      conversation = build(:conversation)
      expect(conversation.student).to be_a(Student)
    end

    it "belongs to question" do
      conversation = build(:conversation)
      expect(conversation.question).to be_a(Question)
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      conversation = build(:conversation)
      expect(conversation).to be_valid
    end

    it "is invalid without student" do
      conversation = build(:conversation, student: nil)
      expect(conversation).not_to be_valid
    end

    it "is invalid without question" do
      conversation = build(:conversation, question: nil)
      expect(conversation).not_to be_valid
    end
  end

  describe "#add_message!" do
    it "adds a message to the messages array" do
      conversation = create(:conversation, messages: [])
      conversation.add_message!(role: "user", content: "Bonjour")

      expect(conversation.messages.size).to eq(1)
      expect(conversation.messages.first["role"]).to eq("user")
      expect(conversation.messages.first["content"]).to eq("Bonjour")
      expect(conversation.messages.first["at"]).to be_present
    end

    it "appends to existing messages" do
      conversation = create(:conversation, messages: [{ "role" => "user", "content" => "Hello", "at" => Time.current.iso8601 }])
      conversation.add_message!(role: "assistant", content: "Bonjour !")

      expect(conversation.messages.size).to eq(2)
    end
  end

  describe "#messages_for_api" do
    it "returns messages in API format" do
      conversation = build(:conversation, messages: [
        { "role" => "user", "content" => "Bonjour", "at" => "2026-01-01T00:00:00Z" },
        { "role" => "assistant", "content" => "Salut !", "at" => "2026-01-01T00:00:01Z" }
      ])

      result = conversation.messages_for_api
      expect(result).to eq([
        { role: "user", content: "Bonjour" },
        { role: "assistant", content: "Salut !" }
      ])
    end
  end
end
```

- [ ] **Step 8 : Creer spec/models/student_insight_spec.rb**

```ruby
# spec/models/student_insight_spec.rb
require "rails_helper"

RSpec.describe StudentInsight, type: :model do
  describe "associations" do
    it "belongs to student" do
      insight = build(:student_insight)
      expect(insight.student).to be_a(Student)
    end

    it "belongs to subject" do
      insight = build(:student_insight)
      expect(insight.subject).to be_a(Subject)
    end

    it "optionally belongs to question" do
      insight = build(:student_insight, question: nil)
      expect(insight).to be_valid
    end
  end

  describe "validations" do
    it "is valid with valid attributes" do
      insight = build(:student_insight)
      expect(insight).to be_valid
    end

    it "is invalid without concept" do
      insight = build(:student_insight, concept: nil)
      expect(insight).not_to be_valid
    end

    it "is invalid with unknown insight_type" do
      insight = build(:student_insight, insight_type: "unknown")
      expect(insight).not_to be_valid
    end

    %w[mastered struggle misconception note].each do |type|
      it "is valid with insight_type #{type}" do
        insight = build(:student_insight, insight_type: type)
        expect(insight).to be_valid
      end
    end
  end
end
```

- [ ] **Step 9 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/models/conversation_spec.rb spec/models/student_insight_spec.rb
```

Resultat attendu : tous les tests passent (vert).

- [ ] **Step 10 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/models/conversation.rb app/models/student_insight.rb app/models/student.rb app/models/question.rb spec/models/conversation_spec.rb spec/models/student_insight_spec.rb spec/factories/conversations.rb spec/factories/student_insights.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add Conversation and StudentInsight models with specs

- Conversation: messages jsonb, add_message!, messages_for_api
- StudentInsight: mastered/struggle/misconception/note types
- Updated Student and Question with has_many associations
- Factories and model specs included

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : AiClientFactory — add model: param to build

**Files:**
- Modify: `app/services/ai_client_factory.rb`
- Modify: `spec/services/ai_client_factory_spec.rb`

- [ ] **Step 1 : Modifier AiClientFactory.build pour accepter model:**

Replace the `self.build` method and `initialize` in `app/services/ai_client_factory.rb`:

```ruby
# app/services/ai_client_factory.rb
class AiClientFactory
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    anthropic:   { base_url: "https://api.anthropic.com",                       auth_header: "x-api-key" },
    openrouter:  { base_url: "https://openrouter.ai",                           auth_header: "Authorization" },
    openai:      { base_url: "https://api.openai.com",                          auth_header: "Authorization" },
    google:      { base_url: "https://generativelanguage.googleapis.com",       auth_header: "x-goog-api-key" }
  }.freeze

  DEFAULT_MODELS = {
    anthropic:  "claude-sonnet-4-5-20251001",
    openrouter: "anthropic/claude-haiku-4-5",
    openai:     "gpt-4o-mini",
    google:     "gemini-2.0-flash"
  }.freeze

  def self.build(provider:, api_key:, model: nil)
    config = PROVIDERS[provider.to_sym]
    raise UnknownProviderError, "Unknown provider: #{provider}" unless config

    new(provider: provider.to_sym, api_key: api_key, config: config, model: model)
  end

  def initialize(provider:, api_key:, config:, model: nil)
    @provider = provider
    @api_key  = api_key
    @config   = config
    @model    = model || DEFAULT_MODELS[@provider]
  end

  def call(messages:, system:, max_tokens: 4096, temperature: 0.2)
    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    headers = build_headers
    body    = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)

    response = connection.post(endpoint_path, body, headers)

    raise "API error #{response.status}: #{response.body}" unless response.success?

    extract_text(response.body)
  end

  private

  def build_headers
    case @provider
    when :anthropic
      {
        "x-api-key"         => @api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type"      => "application/json"
      }
    when :openrouter, :openai
      { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
    when :google
      { "x-goog-api-key" => @api_key, "Content-Type" => "application/json" }
    end
  end

  def build_body(messages:, system:, max_tokens:, temperature:)
    case @provider
    when :anthropic
      { model: @model, system: system, messages: messages, max_tokens: max_tokens, temperature: temperature }
    when :openrouter
      { model: @model, messages: [{ role: "system", content: system }] + messages, max_tokens: max_tokens, temperature: temperature }
    when :openai
      { model: @model, messages: [{ role: "system", content: system }] + messages, max_tokens: max_tokens, temperature: temperature }
    when :google
      { contents: messages.map { |m| { role: m[:role], parts: [{ text: m[:content] }] } }, system_instruction: { parts: [{ text: system }] }, generationConfig: { maxOutputTokens: max_tokens, temperature: temperature } }
    end
  end

  def endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:generateContent"
    end
  end

  def extract_text(body)
    case @provider
    when :anthropic
      body.dig("content", 0, "text")
    when :openrouter, :openai
      body.dig("choices", 0, "message", "content")
    when :google
      body.dig("candidates", 0, "content", "parts", 0, "text")
    end
  end
end
```

- [ ] **Step 2 : Mettre a jour les specs existantes + ajouter tests model param**

```ruby
# spec/services/ai_client_factory_spec.rb
require "rails_helper"

RSpec.describe AiClientFactory do
  describe ".build" do
    it "builds a client for anthropic provider" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for openrouter provider" do
      client = described_class.build(provider: :openrouter, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for openai provider" do
      client = described_class.build(provider: :openai, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "builds a client for google provider" do
      client = described_class.build(provider: :google, api_key: "sk-test")
      expect(client).to respond_to(:call)
    end

    it "raises for unknown provider" do
      expect {
        described_class.build(provider: :unknown, api_key: "sk-test")
      }.to raise_error(AiClientFactory::UnknownProviderError)
    end

    it "accepts an optional model parameter" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      expect(client).to respond_to(:call)
    end

    it "calls anthropic API with correct headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "sk-ant-test" })
        .to_return(
          status: 200,
          body: { content: [{ text: '{"parts":[]}' }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-ant-test")
      result = client.call(
        messages: [{ role: "user", content: "test" }],
        system: "system prompt",
        max_tokens: 100,
        temperature: 0.1
      )

      expect(stub).to have_been_requested
      expect(result).to include("parts")
    end

    it "uses custom model in anthropic request body" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-haiku-4-5-20251001"))
        .to_return(
          status: 200,
          body: { content: [{ text: "hello" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses custom model in google endpoint path" do
      stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-06-05:generateContent")
        .to_return(
          status: 200,
          body: { candidates: [{ content: { parts: [{ text: "hello" }] } }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :google, api_key: "gk-test", model: "gemini-2.5-pro-preview-06-05")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end

    it "uses default model when none specified" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(body: hash_including("model" => "claude-sonnet-4-5-20251001"))
        .to_return(
          status: 200,
          body: { content: [{ text: "hello" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      client.call(messages: [{ role: "user", content: "test" }], system: "sys", max_tokens: 100)

      expect(stub).to have_been_requested
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/services/ai_client_factory_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 4 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/services/ai_client_factory.rb spec/services/ai_client_factory_spec.rb
git commit -m "$(cat <<'EOF'
feat(ai): add model: param to AiClientFactory.build

- build() accepts optional model: parameter
- DEFAULT_MODELS constant for fallback per provider
- Google endpoint_path uses dynamic model name
- Backward compatible: existing callers unchanged

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : AiClientFactory — add stream method

**Files:**
- Modify: `app/services/ai_client_factory.rb`
- Modify: `spec/services/ai_client_factory_spec.rb`

- [ ] **Step 1 : Ajouter la methode stream a AiClientFactory**

Add the `stream` method as a public method after `call` in `app/services/ai_client_factory.rb`:

```ruby
  def stream(messages:, system:, max_tokens: 4096, temperature: 0.7, &block)
    raise ArgumentError, "Block required for streaming" unless block_given?

    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.options.timeout = 120
    end

    headers = build_headers
    body    = build_stream_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    path    = stream_endpoint_path
    buffer  = ""

    response = connection.post(path, body.to_json, headers) do |req|
      req.options.on_data = proc do |chunk, _overall_received_bytes, _env|
        buffer += chunk
        buffer = parse_stream_buffer(buffer, &block)
      end
    end

    raise "API error #{response.status}: #{response.body}" unless response.status == 200
  end
```

- [ ] **Step 2 : Ajouter les methodes privees de streaming**

Add these private methods to `app/services/ai_client_factory.rb`:

```ruby
  def build_stream_body(messages:, system:, max_tokens:, temperature:)
    body = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    case @provider
    when :anthropic
      body.merge(stream: true)
    when :openrouter, :openai
      body.merge(stream: true)
    when :google
      body
    end
  end

  def stream_endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:streamGenerateContent?alt=sse"
    end
  end

  def parse_stream_buffer(buffer, &block)
    while (line_end = buffer.index("\n"))
      line = buffer.slice!(0, line_end + 1).strip
      next if line.empty?

      parse_stream_line(line, &block)
    end
    buffer
  end

  def parse_stream_line(line, &block)
    case @provider
    when :anthropic
      parse_anthropic_stream_line(line, &block)
    when :openrouter, :openai
      parse_openai_stream_line(line, &block)
    when :google
      parse_google_stream_line(line, &block)
    end
  end

  def parse_anthropic_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    if data["type"] == "content_block_delta" && data.dig("delta", "text")
      yield data["delta"]["text"]
    end

    if data["type"] == "message_delta" && data.dig("usage", "output_tokens")
      # Token count available at end — caller can track via block metadata if needed
    end
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_openai_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    content = data.dig("choices", 0, "delta", "content")
    yield content if content
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_google_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    data = JSON.parse(json_str)
    text = data.dig("candidates", 0, "content", "parts", 0, "text")
    yield text if text
  rescue JSON::ParserError
    # Skip malformed lines
  end
```

- [ ] **Step 3 : Le fichier complet app/services/ai_client_factory.rb doit etre**

```ruby
# app/services/ai_client_factory.rb
class AiClientFactory
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    anthropic:   { base_url: "https://api.anthropic.com",                       auth_header: "x-api-key" },
    openrouter:  { base_url: "https://openrouter.ai",                           auth_header: "Authorization" },
    openai:      { base_url: "https://api.openai.com",                          auth_header: "Authorization" },
    google:      { base_url: "https://generativelanguage.googleapis.com",       auth_header: "x-goog-api-key" }
  }.freeze

  DEFAULT_MODELS = {
    anthropic:  "claude-sonnet-4-5-20251001",
    openrouter: "anthropic/claude-haiku-4-5",
    openai:     "gpt-4o-mini",
    google:     "gemini-2.0-flash"
  }.freeze

  def self.build(provider:, api_key:, model: nil)
    config = PROVIDERS[provider.to_sym]
    raise UnknownProviderError, "Unknown provider: #{provider}" unless config

    new(provider: provider.to_sym, api_key: api_key, config: config, model: model)
  end

  def initialize(provider:, api_key:, config:, model: nil)
    @provider = provider
    @api_key  = api_key
    @config   = config
    @model    = model || DEFAULT_MODELS[@provider]
  end

  def call(messages:, system:, max_tokens: 4096, temperature: 0.2)
    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
    end

    headers = build_headers
    body    = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)

    response = connection.post(endpoint_path, body, headers)

    raise "API error #{response.status}: #{response.body}" unless response.success?

    extract_text(response.body)
  end

  def stream(messages:, system:, max_tokens: 4096, temperature: 0.7, &block)
    raise ArgumentError, "Block required for streaming" unless block_given?

    connection = Faraday.new(url: @config[:base_url]) do |f|
      f.request :json
      f.options.timeout = 120
    end

    headers = build_headers
    body    = build_stream_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    path    = stream_endpoint_path
    buffer  = ""

    response = connection.post(path, body.to_json, headers) do |req|
      req.options.on_data = proc do |chunk, _overall_received_bytes, _env|
        buffer += chunk
        buffer = parse_stream_buffer(buffer, &block)
      end
    end

    raise "API error #{response.status}: #{response.body}" unless response.status == 200
  end

  private

  def build_headers
    case @provider
    when :anthropic
      {
        "x-api-key"         => @api_key,
        "anthropic-version" => "2023-06-01",
        "Content-Type"      => "application/json"
      }
    when :openrouter, :openai
      { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
    when :google
      { "x-goog-api-key" => @api_key, "Content-Type" => "application/json" }
    end
  end

  def build_body(messages:, system:, max_tokens:, temperature:)
    case @provider
    when :anthropic
      { model: @model, system: system, messages: messages, max_tokens: max_tokens, temperature: temperature }
    when :openrouter
      { model: @model, messages: [{ role: "system", content: system }] + messages, max_tokens: max_tokens, temperature: temperature }
    when :openai
      { model: @model, messages: [{ role: "system", content: system }] + messages, max_tokens: max_tokens, temperature: temperature }
    when :google
      { contents: messages.map { |m| { role: m[:role], parts: [{ text: m[:content] }] } }, system_instruction: { parts: [{ text: system }] }, generationConfig: { maxOutputTokens: max_tokens, temperature: temperature } }
    end
  end

  def build_stream_body(messages:, system:, max_tokens:, temperature:)
    body = build_body(messages: messages, system: system, max_tokens: max_tokens, temperature: temperature)
    case @provider
    when :anthropic
      body.merge(stream: true)
    when :openrouter, :openai
      body.merge(stream: true)
    when :google
      body
    end
  end

  def endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:generateContent"
    end
  end

  def stream_endpoint_path
    case @provider
    when :anthropic then "/v1/messages"
    when :openrouter, :openai then "/api/v1/chat/completions"
    when :google then "/v1beta/models/#{@model}:streamGenerateContent?alt=sse"
    end
  end

  def extract_text(body)
    case @provider
    when :anthropic
      body.dig("content", 0, "text")
    when :openrouter, :openai
      body.dig("choices", 0, "message", "content")
    when :google
      body.dig("candidates", 0, "content", "parts", 0, "text")
    end
  end

  def parse_stream_buffer(buffer, &block)
    while (line_end = buffer.index("\n"))
      line = buffer.slice!(0, line_end + 1).strip
      next if line.empty?

      parse_stream_line(line, &block)
    end
    buffer
  end

  def parse_stream_line(line, &block)
    case @provider
    when :anthropic
      parse_anthropic_stream_line(line, &block)
    when :openrouter, :openai
      parse_openai_stream_line(line, &block)
    when :google
      parse_google_stream_line(line, &block)
    end
  end

  def parse_anthropic_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    if data["type"] == "content_block_delta" && data.dig("delta", "text")
      yield data["delta"]["text"]
    end
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_openai_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    return if json_str == "[DONE]"

    data = JSON.parse(json_str)
    content = data.dig("choices", 0, "delta", "content")
    yield content if content
  rescue JSON::ParserError
    # Skip malformed lines
  end

  def parse_google_stream_line(line, &block)
    return unless line.start_with?("data: ")

    json_str = line.sub("data: ", "")
    data = JSON.parse(json_str)
    text = data.dig("candidates", 0, "content", "parts", 0, "text")
    yield text if text
  rescue JSON::ParserError
    # Skip malformed lines
  end
end
```

- [ ] **Step 4 : Ajouter les specs streaming**

Append to `spec/services/ai_client_factory_spec.rb` inside the main `RSpec.describe` block, after the existing `describe ".build"` block:

```ruby
  describe "#stream" do
    it "raises ArgumentError without a block" do
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      expect {
        client.stream(messages: [{ role: "user", content: "test" }], system: "sys")
      }.to raise_error(ArgumentError, "Block required for streaming")
    end

    it "streams tokens from anthropic" do
      sse_chunks = [
        "event: content_block_start\ndata: {\"type\":\"content_block_start\"}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"Bonjour\"}}\n\n",
        "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\" !\"}}\n\n",
        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
      ]

      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :anthropic, api_key: "sk-test")
      client.stream(messages: [{ role: "user", content: "test" }], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq(["Bonjour", " !"])
    end

    it "streams tokens from openai" do
      sse_chunks = [
        "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
        "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n",
        "data: [DONE]\n\n"
      ]

      stub_request(:post, "https://api.openai.com/api/v1/chat/completions")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :openai, api_key: "sk-test")
      client.stream(messages: [{ role: "user", content: "test" }], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq(["Hello", " world"])
    end

    it "streams tokens from google" do
      sse_chunks = [
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Salut\"}]}}]}\n\n",
        "data: {\"candidates\":[{\"content\":{\"parts\":[{\"text\":\" toi\"}]}}]}\n\n"
      ]

      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse")
        .to_return(
          status: 200,
          body: sse_chunks.join,
          headers: { "Content-Type" => "text/event-stream" }
        )

      tokens = []
      client = described_class.build(provider: :google, api_key: "gk-test")
      client.stream(messages: [{ role: "user", content: "test" }], system: "sys") do |token|
        tokens << token
      end

      expect(tokens).to eq(["Salut", " toi"])
    end

    it "raises on API error" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 401, body: "Unauthorized")

      client = described_class.build(provider: :anthropic, api_key: "bad-key")
      expect {
        client.stream(messages: [{ role: "user", content: "test" }], system: "sys") { |_t| }
      }.to raise_error(/API error 401/)
    end
  end
```

- [ ] **Step 5 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/services/ai_client_factory_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 6 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/services/ai_client_factory.rb spec/services/ai_client_factory_spec.rb
git commit -m "$(cat <<'EOF'
feat(ai): add stream method to AiClientFactory

- stream(messages:, system:, &block) yields tokens in real-time
- SSE parsing for Anthropic (content_block_delta), OpenAI/OpenRouter
  (choices delta), and Google (streamGenerateContent?alt=sse)
- Uses Faraday on_data callback for chunked response processing
- Specs with mocked SSE responses for all 4 providers

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : BuildTutorPrompt service

**Files:**
- Create: `app/services/build_tutor_prompt.rb`
- Create: `spec/services/build_tutor_prompt_spec.rb`

- [ ] **Step 1 : Creer app/services/build_tutor_prompt.rb**

```ruby
# app/services/build_tutor_prompt.rb
class BuildTutorPrompt
  DEFAULT_TEMPLATE = <<~PROMPT
    Tu es un tuteur bienveillant pour des eleves de Terminale preparant le BAC.
    Specialite : %{specialty}. Partie : %{part_title}. Objectif : %{objective_text}.
    Question : %{question_label}. Contexte local : %{context_text}.
    Correction officielle (confidentielle) : %{correction_text}.
    Regle absolue : ne donne JAMAIS la reponse directement.
    Guide l'eleve par etapes, valorise ses tentatives, pose des questions.
    Propose une fiche de revision si un concept cle est identifie.
    Reponds en francais, niveau lycee, de facon bienveillante.
  PROMPT

  def self.call(question:, student:)
    new(question: question, student: student).call
  end

  def initialize(question:, student:)
    @question = question
    @student  = student
  end

  def call
    prompt = interpolate_template
    prompt += insights_section if insights.any?
    prompt
  end

  private

  def interpolate_template
    template % template_variables
  end

  def template
    subject.owner.tutor_prompt_template.presence || DEFAULT_TEMPLATE
  end

  def template_variables
    {
      specialty:       subject.specialty,
      part_title:      part.title,
      objective_text:  part.objective_text.to_s,
      question_label:  @question.label,
      context_text:    @question.context_text.to_s,
      correction_text: answer_correction_text
    }
  end

  def answer_correction_text
    @question.answer&.correction_text.to_s
  end

  def part
    @question.part
  end

  def subject
    part.subject
  end

  def insights
    @insights ||= StudentInsight.where(student: @student, subject: subject).order(:created_at)
  end

  def insights_section
    lines = ["\n\n--- Historique de l'eleve ---"]
    insights.each do |insight|
      lines << "- [#{insight.insight_type}] #{insight.concept}: #{insight.text}"
    end
    lines.join("\n")
  end
end
```

- [ ] **Step 2 : Creer spec/services/build_tutor_prompt_spec.rb**

```ruby
# spec/services/build_tutor_prompt_spec.rb
require "rails_helper"

RSpec.describe BuildTutorPrompt do
  let(:user) { create(:user, tutor_prompt_template: nil) }
  let(:subject_record) { create(:subject, owner: user, specialty: :SIN) }
  let(:part) { create(:part, subject: subject_record, title: "Partie 1", objective_text: "Comparer les transports") }
  let(:question) { create(:question, part: part, label: "Calculer la consommation", context_text: "Distance 186 km") }
  let!(:answer) { create(:answer, question: question, correction_text: "56,73 litres") }
  let(:student) { create(:student) }

  describe ".call" do
    it "returns the interpolated default template" do
      result = described_class.call(question: question, student: student)

      expect(result).to include("SIN")
      expect(result).to include("Partie 1")
      expect(result).to include("Comparer les transports")
      expect(result).to include("Calculer la consommation")
      expect(result).to include("Distance 186 km")
      expect(result).to include("56,73 litres")
      expect(result).to include("ne donne JAMAIS la reponse directement")
    end

    it "uses teacher custom template when set" do
      user.update!(tutor_prompt_template: "Custom prompt for %{specialty} — %{question_label}")

      result = described_class.call(question: question, student: student)

      expect(result).to include("Custom prompt for SIN")
      expect(result).to include("Calculer la consommation")
      expect(result).not_to include("ne donne JAMAIS")
    end

    it "appends student insights when they exist" do
      create(:student_insight,
        student: student,
        subject: subject_record,
        insight_type: "mastered",
        concept: "energie primaire",
        text: "Bien compris"
      )

      result = described_class.call(question: question, student: student)

      expect(result).to include("Historique de l'eleve")
      expect(result).to include("[mastered] energie primaire: Bien compris")
    end

    it "does not include insights section when no insights exist" do
      result = described_class.call(question: question, student: student)

      expect(result).not_to include("Historique de l'eleve")
    end

    it "handles question without answer gracefully" do
      question_no_answer = create(:question, part: part, label: "Question sans reponse")

      result = described_class.call(question: question_no_answer, student: student)

      expect(result).to include("Question sans reponse")
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/services/build_tutor_prompt_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 4 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/services/build_tutor_prompt.rb spec/services/build_tutor_prompt_spec.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add BuildTutorPrompt service

- DEFAULT_TEMPLATE with variable interpolation (%{specialty}, etc.)
- Falls back to default when teacher has no custom template
- Appends StudentInsight history for the student/subject pair
- Handles missing answers gracefully

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : ActionCable — TutorChannel + connection

**Files:**
- Create: `app/channels/application_cable/connection.rb`
- Create: `app/channels/application_cable/channel.rb`
- Create: `app/channels/tutor_channel.rb`
- Create: `spec/channels/tutor_channel_spec.rb`
- Modify: `config/importmap.rb`
- Modify: `app/javascript/application.js`

- [ ] **Step 1 : Creer app/channels/application_cable/connection.rb**

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_student, :current_user

    def connect
      self.current_student = find_student
      self.current_user = find_user
      reject_unauthorized_connection unless current_student || current_user
    end

    private

    def find_student
      Student.find_by(id: request.session[:student_id])
    end

    def find_user
      env["warden"]&.user
    end
  end
end
```

- [ ] **Step 2 : Creer app/channels/application_cable/channel.rb**

```ruby
# app/channels/application_cable/channel.rb
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

- [ ] **Step 3 : Creer app/channels/tutor_channel.rb**

```ruby
# app/channels/tutor_channel.rb
class TutorChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find_by(id: params[:conversation_id])

    if conversation && conversation.student_id == current_student&.id
      stream_from "conversation_#{conversation.id}"
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup if needed
  end
end
```

- [ ] **Step 4 : Ajouter ActionCable JS a importmap**

Add to `config/importmap.rb`:

```ruby
pin "@rails/actioncable", to: "actioncable.esm.js"
```

- [ ] **Step 5 : Importer ActionCable dans application.js**

Modify `app/javascript/application.js` to:

```javascript
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@rails/actioncable"
```

- [ ] **Step 6 : Creer spec/channels/tutor_channel_spec.rb**

```ruby
# spec/channels/tutor_channel_spec.rb
require "rails_helper"

RSpec.describe TutorChannel, type: :channel do
  let(:student) { create(:student) }
  let(:question) { create(:question) }
  let(:conversation) { create(:conversation, student: student, question: question) }

  before do
    stub_connection current_student: student, current_user: nil
  end

  describe "#subscribed" do
    it "subscribes to the conversation stream" do
      subscribe(conversation_id: conversation.id)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("conversation_#{conversation.id}")
    end

    it "rejects subscription for another student's conversation" do
      other_student = create(:student)
      other_conversation = create(:conversation, student: other_student, question: question)

      subscribe(conversation_id: other_conversation.id)

      expect(subscription).to be_rejected
    end

    it "rejects subscription for non-existent conversation" do
      subscribe(conversation_id: 999999)

      expect(subscription).to be_rejected
    end
  end
end
```

- [ ] **Step 7 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/channels/tutor_channel_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 8 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/channels/ spec/channels/ config/importmap.rb app/javascript/application.js
git commit -m "$(cat <<'EOF'
feat(tutor): add ActionCable TutorChannel with student auth

- ApplicationCable::Connection identifies student via session or user via Warden
- TutorChannel subscribes to conversation stream, scoped to current_student
- Rejects unauthorized subscriptions
- ActionCable JS pinned in importmap
- Channel specs included

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : TutorStreamJob

**Files:**
- Create: `app/jobs/tutor_stream_job.rb`
- Create: `spec/jobs/tutor_stream_job_spec.rb`

- [ ] **Step 1 : Creer app/jobs/tutor_stream_job.rb**

```ruby
# app/jobs/tutor_stream_job.rb
class TutorStreamJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    student = conversation.student
    question = conversation.question

    conversation.update!(streaming: true)

    system_prompt = BuildTutorPrompt.call(question: question, student: student)

    client = AiClientFactory.build(
      provider: student.api_provider,
      api_key: student.api_key,
      model: student.effective_model
    )

    full_response = ""

    client.stream(
      messages: conversation.messages_for_api,
      system: system_prompt,
      max_tokens: 2048,
      temperature: 0.7
    ) do |token|
      full_response += token
      ActionCable.server.broadcast("conversation_#{conversation.id}", { token: token })
    end

    conversation.add_message!(role: "assistant", content: full_response)
    conversation.update!(
      streaming: false,
      tokens_used: conversation.tokens_used + estimate_tokens(full_response),
      provider_used: student.api_provider
    )

    ActionCable.server.broadcast("conversation_#{conversation.id}", { done: true })
  rescue Faraday::UnauthorizedError, RuntimeError => e
    handle_error(conversation, e)
  rescue Faraday::TimeoutError => e
    handle_error(conversation, e, "Le serveur n'a pas repondu. Reessayez.")
  rescue StandardError => e
    handle_error(conversation, e, "Une erreur est survenue. Reessayez.")
  end

  private

  def estimate_tokens(text)
    (text.length / 4.0).ceil
  end

  def handle_error(conversation, error, custom_message = nil)
    message = custom_message || error_message_for(error)
    conversation.update!(streaming: false)
    ActionCable.server.broadcast("conversation_#{conversation.id}", { error: message })
    Rails.logger.error("[TutorStreamJob] #{error.class}: #{error.message}")
  end

  def error_message_for(error)
    case error.message
    when /401/
      "Cle API invalide. Verifiez vos reglages."
    when /402/, /429/
      "Credits insuffisants sur votre compte."
    when /timeout/i
      "Le serveur n'a pas repondu. Reessayez."
    else
      "Erreur de communication avec l'IA. Reessayez."
    end
  end
end
```

- [ ] **Step 2 : Creer spec/jobs/tutor_stream_job_spec.rb**

```ruby
# spec/jobs/tutor_stream_job_spec.rb
require "rails_helper"

RSpec.describe TutorStreamJob, type: :job do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:part) { create(:part) }
  let(:question) { create(:question, part: part) }
  let!(:answer) { create(:answer, question: question) }
  let(:conversation) do
    create(:conversation,
      student: student,
      question: question,
      messages: [{ "role" => "user", "content" => "Bonjour, aide-moi" }]
    )
  end

  let(:mock_client) { instance_double(AiClientFactory) }

  before do
    allow(AiClientFactory).to receive(:build).and_return(mock_client)
  end

  describe "#perform" do
    it "streams tokens and saves the full response" do
      allow(mock_client).to receive(:stream) do |**_args, &block|
        block.call("Bonjour")
        block.call(" !")
      end

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { token: "Bonjour" })
      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { token: " !" })
      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { done: true })

      described_class.perform_now(conversation.id)

      conversation.reload
      expect(conversation.messages.last["role"]).to eq("assistant")
      expect(conversation.messages.last["content"]).to eq("Bonjour !")
      expect(conversation.streaming).to be(false)
      expect(conversation.tokens_used).to be > 0
    end

    it "sets streaming flag during execution" do
      allow(mock_client).to receive(:stream) do |**_args, &block|
        expect(conversation.reload.streaming).to be(true)
        block.call("token")
      end
      allow(ActionCable.server).to receive(:broadcast)

      described_class.perform_now(conversation.id)

      expect(conversation.reload.streaming).to be(false)
    end

    it "broadcasts error on API failure" do
      allow(mock_client).to receive(:stream).and_raise(RuntimeError, "API error 401: Unauthorized")

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { error: "Cle API invalide. Verifiez vos reglages." })

      described_class.perform_now(conversation.id)

      expect(conversation.reload.streaming).to be(false)
    end

    it "broadcasts timeout error" do
      allow(mock_client).to receive(:stream).and_raise(Faraday::TimeoutError)

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { error: "Le serveur n'a pas repondu. Reessayez." })

      described_class.perform_now(conversation.id)
    end

    it "builds client with student provider and model" do
      allow(mock_client).to receive(:stream) { |**_args, &block| block.call("ok") }
      allow(ActionCable.server).to receive(:broadcast)

      expect(AiClientFactory).to receive(:build).with(
        provider: "anthropic",
        api_key: "sk-test",
        model: student.effective_model
      ).and_return(mock_client)

      described_class.perform_now(conversation.id)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/jobs/tutor_stream_job_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 4 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/jobs/tutor_stream_job.rb spec/jobs/tutor_stream_job_spec.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add TutorStreamJob with ActionCable broadcasting

- Loads conversation, builds prompt, streams via AiClientFactory
- Broadcasts each token + done signal via ActionCable
- Saves full response to conversation.messages
- Error handling: 401 (invalid key), 402/429 (credits), timeout
- Sets streaming flag to prevent concurrent requests

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8 : ExtractStudentInsights service + job

**Files:**
- Create: `app/services/extract_student_insights.rb`
- Create: `app/jobs/extract_student_insights_job.rb`
- Create: `spec/services/extract_student_insights_spec.rb`
- Create: `spec/jobs/extract_student_insights_job_spec.rb`

- [ ] **Step 1 : Creer app/services/extract_student_insights.rb**

```ruby
# app/services/extract_student_insights.rb
class ExtractStudentInsights
  EXTRACTION_PROMPT = <<~PROMPT
    Analyse cette conversation entre un tuteur et un eleve de Terminale.
    Identifie les concepts maitrises, les difficultes et les erreurs de comprehension.

    Reponds UNIQUEMENT avec un tableau JSON valide, sans texte supplementaire.
    Chaque element doit avoir exactement ces cles :
    - "type": un parmi "mastered", "struggle", "misconception", "note"
    - "concept": le nom court du concept (ex: "energie primaire", "rendement")
    - "text": une phrase explicative courte

    Exemple :
    [
      {"type": "mastered", "concept": "energie primaire", "text": "L'eleve comprend la distinction entre energie primaire et finale."},
      {"type": "struggle", "concept": "rendement", "text": "L'eleve confond rendement et puissance."}
    ]

    Si aucun insight n'est identifiable, reponds avec un tableau vide : []
  PROMPT

  def self.call(conversation:)
    new(conversation: conversation).call
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return [] if @conversation.messages.size < 4

    raw_json = call_ai
    insights = parse_insights(raw_json)
    persist_insights(insights)
    insights
  end

  private

  def call_ai
    client = resolve_client
    messages_text = @conversation.messages.map { |m| "#{m['role']}: #{m['content']}" }.join("\n\n")

    client.call(
      messages: [{ role: "user", content: messages_text }],
      system: EXTRACTION_PROMPT,
      max_tokens: 1024,
      temperature: 0.1
    )
  end

  def resolve_client
    student = @conversation.student

    if student.api_key.present?
      AiClientFactory.build(
        provider: student.api_provider,
        api_key: student.api_key,
        model: student.effective_model
      )
    elsif ENV["ANTHROPIC_API_KEY"].present?
      AiClientFactory.build(
        provider: :anthropic,
        api_key: ENV["ANTHROPIC_API_KEY"],
        model: "claude-haiku-4-5-20251001"
      )
    else
      raise "No API key available for insight extraction"
    end
  end

  def parse_insights(raw_json)
    cleaned = raw_json.to_s.strip
    cleaned = cleaned[/\[.*\]/m] || "[]"
    JSON.parse(cleaned)
  rescue JSON::ParserError
    Rails.logger.warn("[ExtractStudentInsights] Failed to parse JSON: #{raw_json}")
    []
  end

  def persist_insights(insights)
    subject = @conversation.question.part.subject

    insights.each do |insight|
      next unless StudentInsight::INSIGHT_TYPES.include?(insight["type"])
      next if insight["concept"].blank?

      StudentInsight.create!(
        student: @conversation.student,
        subject: subject,
        question: @conversation.question,
        insight_type: insight["type"],
        concept: insight["concept"],
        text: insight["text"]
      )
    end
  end
end
```

- [ ] **Step 2 : Creer app/jobs/extract_student_insights_job.rb**

```ruby
# app/jobs/extract_student_insights_job.rb
class ExtractStudentInsightsJob < ApplicationJob
  queue_as :low_priority

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    ExtractStudentInsights.call(conversation: conversation)
  rescue StandardError => e
    Rails.logger.error("[ExtractStudentInsightsJob] #{e.class}: #{e.message}")
  end
end
```

- [ ] **Step 3 : Creer spec/services/extract_student_insights_spec.rb**

```ruby
# spec/services/extract_student_insights_spec.rb
require "rails_helper"

RSpec.describe ExtractStudentInsights do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:part) { create(:part) }
  let(:question) { create(:question, part: part) }
  let(:conversation) do
    create(:conversation,
      student: student,
      question: question,
      messages: [
        { "role" => "user", "content" => "Comment calculer ?" },
        { "role" => "assistant", "content" => "Quelle formule utiliser ?" },
        { "role" => "user", "content" => "P = U x I ?" },
        { "role" => "assistant", "content" => "Oui ! C'est correct." }
      ]
    )
  end

  let(:mock_client) { instance_double(AiClientFactory) }

  before do
    allow(AiClientFactory).to receive(:build).and_return(mock_client)
  end

  describe ".call" do
    it "extracts and persists insights from conversation" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "mastered", "concept": "puissance electrique", "text": "Connait P=UI"}]'
      )

      result = described_class.call(conversation: conversation)

      expect(result.size).to eq(1)
      expect(StudentInsight.count).to eq(1)

      insight = StudentInsight.last
      expect(insight.insight_type).to eq("mastered")
      expect(insight.concept).to eq("puissance electrique")
      expect(insight.student).to eq(student)
      expect(insight.subject).to eq(part.subject)
    end

    it "returns empty array for short conversations (< 4 messages)" do
      short_conversation = create(:conversation,
        student: student,
        question: question,
        messages: [
          { "role" => "user", "content" => "Bonjour" },
          { "role" => "assistant", "content" => "Salut !" }
        ]
      )

      result = described_class.call(conversation: short_conversation)

      expect(result).to eq([])
      expect(StudentInsight.count).to eq(0)
    end

    it "handles malformed JSON gracefully" do
      allow(mock_client).to receive(:call).and_return("Not valid JSON at all")

      result = described_class.call(conversation: conversation)

      expect(result).to eq([])
      expect(StudentInsight.count).to eq(0)
    end

    it "skips insights with unknown types" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "unknown_type", "concept": "test", "text": "skip me"}, {"type": "mastered", "concept": "valid", "text": "keep me"}]'
      )

      described_class.call(conversation: conversation)

      expect(StudentInsight.count).to eq(1)
      expect(StudentInsight.last.concept).to eq("valid")
    end

    it "skips insights with blank concept" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "mastered", "concept": "", "text": "no concept"}]'
      )

      described_class.call(conversation: conversation)

      expect(StudentInsight.count).to eq(0)
    end

    it "falls back to server ANTHROPIC_API_KEY when student has no key" do
      student.update!(api_key: nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("sk-server-key")
      allow(ENV).to receive(:fetch).and_call_original

      expect(AiClientFactory).to receive(:build).with(
        provider: :anthropic,
        api_key: "sk-server-key",
        model: "claude-haiku-4-5-20251001"
      ).and_return(mock_client)

      allow(mock_client).to receive(:call).and_return("[]")

      described_class.call(conversation: conversation)
    end
  end
end
```

- [ ] **Step 4 : Creer spec/jobs/extract_student_insights_job_spec.rb**

```ruby
# spec/jobs/extract_student_insights_job_spec.rb
require "rails_helper"

RSpec.describe ExtractStudentInsightsJob, type: :job do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:question) { create(:question) }
  let(:conversation) { create(:conversation, student: student, question: question) }

  describe "#perform" do
    it "calls ExtractStudentInsights service" do
      expect(ExtractStudentInsights).to receive(:call).with(conversation: conversation)

      described_class.perform_now(conversation.id)
    end

    it "does nothing for non-existent conversation" do
      expect(ExtractStudentInsights).not_to receive(:call)

      described_class.perform_now(999999)
    end

    it "logs errors without raising" do
      allow(ExtractStudentInsights).to receive(:call).and_raise(StandardError, "test error")

      expect(Rails.logger).to receive(:error).with(/ExtractStudentInsightsJob.*test error/)

      described_class.perform_now(conversation.id)
    end
  end
end
```

- [ ] **Step 5 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/services/extract_student_insights_spec.rb spec/jobs/extract_student_insights_job_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 6 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/services/extract_student_insights.rb app/jobs/extract_student_insights_job.rb spec/services/extract_student_insights_spec.rb spec/jobs/extract_student_insights_job_spec.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add ExtractStudentInsights service and job

- Sends conversation to AI with structured extraction prompt
- Parses JSON array of insights (mastered/struggle/misconception/note)
- Persists StudentInsight records linked to student/subject/question
- Skips short conversations (< 4 messages)
- Falls back to server ANTHROPIC_API_KEY when student has no key
- Job runs on low_priority queue, swallows errors

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9 : Routes + ConversationsController + chat drawer view

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/student/conversations_controller.rb`
- Create: `app/views/student/questions/_chat_drawer.html.erb`
- Modify: `app/views/student/questions/show.html.erb`
- Modify: `app/controllers/student/questions_controller.rb`

- [ ] **Step 1 : Ajouter les routes conversations**

In `config/routes.rb`, add inside the `scope "/:access_code"` block, after the `test_key` route:

```ruby
    resources :conversations, only: [:create], controller: "student/conversations" do
      member do
        post :message
      end
    end
```

The full student scope should look like:

```ruby
  # Auth eleve via access_code
  scope "/:access_code", as: :student do
    get    "/",        to: "student/sessions#new",     as: :login
    post   "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    get "/subjects",                                to: "student/subjects#index",    as: :root
    get "/subjects/:id",                            to: "student/subjects#show",     as: :subject
    get "/subjects/:subject_id/questions/:id",      to: "student/questions#show",    as: :question
    patch "/subjects/:subject_id/questions/:id/reveal", to: "student/questions#reveal", as: :reveal_question
    get   "/settings",          to: "student/settings#show",     as: :settings
    patch "/settings",          to: "student/settings#update"
    post  "/settings/test_key", to: "student/settings#test_key", as: :test_key
    resources :conversations, only: [:create], controller: "student/conversations" do
      member do
        post :message
      end
    end
  end
```

- [ ] **Step 2 : Creer app/controllers/student/conversations_controller.rb**

```ruby
# app/controllers/student/conversations_controller.rb
class Student::ConversationsController < Student::BaseController
  before_action :require_api_key, only: [:create, :message]
  before_action :set_conversation, only: [:message]

  def create
    question = Question.kept.find(params[:question_id])
    conversation = current_student.conversations.find_or_create_by!(question: question)

    render json: { conversation_id: conversation.id }
  end

  def message
    return render_rate_limited if @conversation.streaming?

    content = params[:content].to_s.strip
    return render_empty_message if content.blank?

    @conversation.add_message!(role: "user", content: content)
    TutorStreamJob.perform_later(@conversation.id)

    render json: { status: "ok" }
  end

  private

  def require_api_key
    return if current_student.api_key.present?

    respond_to do |format|
      format.json do
        render json: {
          error: "Configurez votre cle IA dans les reglages.",
          settings_url: student_settings_path(access_code: params[:access_code])
        }, status: :unprocessable_entity
      end
      format.html do
        redirect_to student_settings_path(access_code: params[:access_code]),
                    alert: "Configurez votre cle IA pour utiliser le tutorat."
      end
    end
  end

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  end

  def render_rate_limited
    render json: { error: "Une reponse est deja en cours. Patientez." }, status: :too_many_requests
  end

  def render_empty_message
    render json: { error: "Le message ne peut pas etre vide." }, status: :unprocessable_entity
  end
end
```

- [ ] **Step 3 : Creer app/views/student/questions/_chat_drawer.html.erb**

```erb
<%# app/views/student/questions/_chat_drawer.html.erb %>
<div data-chat-target="drawer"
     style="position: fixed; top: 0; right: 0; bottom: 0; width: 380px; max-width: 100vw;
            background: #0f172a; border-left: 1px solid #374151; z-index: 50;
            transform: translateX(100%); transition: transform 0.2s ease-in-out;
            display: flex; flex-direction: column;">

  <%# Header %>
  <div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #374151;">
    <span style="color: #e2e8f0; font-weight: 600; font-size: 14px;">Tutorat IA</span>
    <button data-action="click->chat#close"
            style="background: none; border: none; color: #94a3b8; font-size: 18px; cursor: pointer;">
      ✕
    </button>
  </div>

  <%# Messages area %>
  <div data-chat-target="messages"
       style="flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 12px;">
    <% if local_assigns[:conversation] && conversation.messages.any? %>
      <% conversation.messages.each do |msg| %>
        <% if msg["role"] == "user" %>
          <div style="align-self: flex-end; background: #7c3aed; color: white; padding: 8px 12px; border-radius: 12px 12px 2px 12px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;">
            <%= msg["content"] %>
          </div>
        <% else %>
          <div style="align-self: flex-start; background: #1e293b; color: #e2e8f0; padding: 8px 12px; border-radius: 12px 12px 12px 2px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;">
            <%= msg["content"] %>
          </div>
        <% end %>
      <% end %>
    <% else %>
      <div style="color: #64748b; font-size: 13px; text-align: center; margin-top: 40px;">
        Posez votre question pour commencer le tutorat.
      </div>
    <% end %>
  </div>

  <%# Streaming response placeholder %>
  <div data-chat-target="streaming"
       style="display: none; align-self: flex-start; background: #1e293b; color: #e2e8f0; padding: 8px 12px; border-radius: 12px 12px 12px 2px; max-width: 85%; font-size: 13px; line-height: 1.4; margin: 0 16px 12px; word-break: break-word;">
  </div>

  <%# Error area %>
  <div data-chat-target="error"
       style="display: none; margin: 0 16px 8px; padding: 8px 12px; background: #7f1d1d; color: #fca5a5; border-radius: 6px; font-size: 12px;">
  </div>

  <%# Input area %>
  <div style="padding: 12px 16px; border-top: 1px solid #374151;">
    <div style="display: flex; gap: 8px;">
      <input data-chat-target="input"
             data-action="keydown.enter->chat#send"
             type="text"
             placeholder="Ecrivez votre question..."
             style="flex: 1; padding: 8px 12px; background: #1e293b; border: 1px solid #374151; border-radius: 6px; color: #e2e8f0; font-size: 13px; outline: none;"
             autocomplete="off">
      <button data-chat-target="sendButton"
              data-action="click->chat#send"
              style="padding: 8px 16px; background: #7c3aed; color: white; border: none; border-radius: 6px; font-size: 13px; cursor: pointer; white-space: nowrap;">
        Envoyer
      </button>
    </div>
  </div>
</div>

<%# Backdrop (mobile) %>
<div data-chat-target="backdrop"
     data-action="click->chat#close"
     style="display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 40;">
</div>
```

- [ ] **Step 4 : Modifier app/views/student/questions/show.html.erb**

Replace the entire file with:

```erb
<div data-controller="sidebar chat"
     data-chat-create-url-value="<%= student_conversations_path(access_code: params[:access_code]) %>"
     data-chat-message-url-value=""
     data-chat-question-id-value="<%= @question.id %>"
     data-chat-has-api-key-value="<%= current_student.api_key.present? %>"
     data-chat-settings-url-value="<%= student_settings_path(access_code: params[:access_code]) %>"
     data-chat-conversation-id-value="<%= @conversation&.id %>"
     style="display: flex; min-height: 100vh;">

  <%# Backdrop sidebar (mobile only) %>
  <div data-sidebar-target="backdrop"
       data-action="click->sidebar#close"
       class="hidden"
       style="position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 40; display: none;">
  </div>
  <style>
    [data-sidebar-target="backdrop"]:not(.hidden) { display: block !important; }
    @media (min-width: 1024px) {
      [data-sidebar-target="backdrop"] { display: none !important; }
      [data-sidebar-target="drawer"] {
        transform: none !important;
        position: relative !important;
        z-index: auto !important;
      }
    }
  </style>

  <%# Sidebar / Drawer %>
  <div data-sidebar-target="drawer"
       style="width: 300px; background: #111827; border-right: 1px solid #374151; flex-shrink: 0;
              position: fixed; top: 0; left: 0; bottom: 0; z-index: 50;
              transform: translateX(-100%); transition: transform 0.2s ease-in-out;
              overflow-y: auto;">
    <%= render "student/questions/sidebar",
        subject: @subject,
        current_part: @part,
        current_question: @question,
        parts: @parts,
        questions_in_part: @questions_in_part,
        session_record: @session_record,
        access_code: params[:access_code] %>
  </div>

  <%# Main content %>
  <div style="flex: 1; padding: 16px; max-width: 800px; margin: 0 auto;">
    <%# Top bar %>
    <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 20px;">
      <button data-action="click->sidebar#open"
              style="width: 36px; height: 36px; background: #1e293b; border: none; border-radius: 6px; color: #94a3b8; font-size: 18px; cursor: pointer;">
        ☰
      </button>
      <span style="color: #94a3b8; font-size: 13px;">
        <%= @part.title %> — Q<%= @question.number %>
        (<%= @questions_in_part.index(@question).to_i + 1 %>/<%= @questions_in_part.size %>)
      </span>
      <div style="flex: 1; height: 4px; background: #1e293b; border-radius: 2px;">
        <%
          total = @questions_in_part.size
          answered = @questions_in_part.count { |q| @session_record.answered?(q.id) }
          pct = total > 0 ? (answered * 100.0 / total).round : 0
        %>
        <div style="width: <%= pct %>%; height: 100%; background: #7c3aed; border-radius: 2px;"></div>
      </div>
      <%# Tutor button %>
      <button data-action="click->chat#open"
              style="padding: 6px 14px; background: #7c3aed; color: white; border: none; border-radius: 6px; font-size: 13px; cursor: pointer; white-space: nowrap;">
        Tutorat
      </button>
    </div>

    <%# Question card %>
    <div style="background: #1e293b; border-radius: 8px; padding: 16px; margin-bottom: 16px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <span style="color: #7c3aed; font-weight: 600; font-size: 14px;">Question <%= @question.number %></span>
        <span style="background: #7c3aed33; color: #a78bfa; font-size: 11px; padding: 2px 8px; border-radius: 10px;"><%= @question.points %> pts</span>
      </div>
      <p style="color: #e2e8f0; font-size: 14px; line-height: 1.5; margin: 0 0 8px;"><%= @question.label %></p>
      <% if @question.context_text.present? %>
        <p style="color: #94a3b8; font-size: 13px; line-height: 1.4; margin: 0; font-style: italic;"><%= @question.context_text %></p>
      <% end %>
    </div>

    <%# Correction area %>
    <%= turbo_frame_tag "question_#{@question.id}_correction" do %>
      <% if @session_record.answered?(@question.id) %>
        <%= render "student/questions/correction",
            question: @question, subject: @subject, session_record: @session_record %>
      <% elsif @question.answer %>
        <div style="text-align: center; margin-bottom: 16px;">
          <%= button_to "Voir la correction",
              student_reveal_question_path(access_code: params[:access_code], subject_id: @subject.id, id: @question.id),
              method: :patch,
              data: { turbo_frame: "question_#{@question.id}_correction" },
              style: "padding: 12px 32px; background: #7c3aed; color: white; border: none; border-radius: 6px; font-size: 14px; cursor: pointer;" %>
        </div>
      <% end %>
    <% end %>

    <%# Navigation %>
    <%
      idx = @questions_in_part.index(@question).to_i
      prev_q = idx > 0 ? @questions_in_part[idx - 1] : nil
      next_q = idx < @questions_in_part.size - 1 ? @questions_in_part[idx + 1] : nil
    %>
    <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 16px; border-top: 1px solid #1e293b;">
      <% if prev_q %>
        <%= link_to "← Q#{prev_q.number}",
            student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: prev_q.id),
            style: "color: #7c3aed; font-size: 13px; text-decoration: none;" %>
      <% else %>
        <span></span>
      <% end %>

      <% if next_q %>
        <%= link_to "Question suivante →",
            student_question_path(access_code: params[:access_code], subject_id: @subject.id, id: next_q.id),
            style: "display: inline-block; padding: 10px 24px; background: #22c55e; color: white; border-radius: 6px; font-size: 13px; font-weight: 600; text-decoration: none;" %>
      <% else %>
        <%= link_to "Retour aux sujets",
            student_root_path(access_code: params[:access_code]),
            style: "display: inline-block; padding: 10px 24px; background: #22c55e; color: white; border-radius: 6px; font-size: 13px; font-weight: 600; text-decoration: none;" %>
      <% end %>
    </div>
  </div>

  <%# Chat drawer %>
  <%= render "student/questions/chat_drawer", conversation: @conversation %>
</div>
```

- [ ] **Step 5 : Modifier app/controllers/student/questions_controller.rb**

Add conversation loading and insight extraction trigger. Replace the entire file:

```ruby
# app/controllers/student/questions_controller.rb
class Student::QuestionsController < Student::BaseController
  before_action :set_subject
  before_action :set_question
  before_action :set_session_record

  def show
    @part = @question.part
    @parts = @subject.parts.order(:position)
    @questions_in_part = @part.questions.kept.order(:position)
    @session_record.mark_seen!(@question.id)

    # Load existing conversation for this question (if any)
    @conversation = current_student.conversations.find_by(question: @question)

    # Trigger insight extraction for the previous conversation (if any)
    extract_previous_insights
  end

  def reveal
    @session_record.mark_answered!(@question.id)
    render turbo_stream: turbo_stream.replace(
      "question_#{@question.id}_correction",
      partial: "student/questions/correction",
      locals: { question: @question, subject: @subject, session_record: @session_record }
    )
  end

  private

  def set_subject
    @subject = @classroom.subjects.published.find_by(id: params[:subject_id])
    unless @subject
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Sujet introuvable."
    end
  end

  def set_question
    @question = Question.kept.joins(:part)
                        .where(parts: { subject_id: @subject.id })
                        .find_by(id: params[:id])
    unless @question
      redirect_to student_root_path(access_code: params[:access_code]),
                  alert: "Question introuvable."
    end
  end

  def set_session_record
    @session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end
  end

  def extract_previous_insights
    last_id = session[:last_conversation_id]
    return unless last_id

    session.delete(:last_conversation_id)
    conversation = current_student.conversations.find_by(id: last_id)
    return unless conversation && conversation.question_id != @question.id

    ExtractStudentInsightsJob.perform_later(conversation.id)
  end
end
```

- [ ] **Step 6 : Lancer le serveur pour verifier que les routes fonctionnent**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bin/rails routes | grep conversation
```

Resultat attendu :
```
student_conversation_message POST /:access_code/conversations/:id/message student/conversations#message
         student_conversations POST /:access_code/conversations            student/conversations#create
```

- [ ] **Step 7 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add config/routes.rb app/controllers/student/conversations_controller.rb app/controllers/student/questions_controller.rb app/views/student/questions/_chat_drawer.html.erb app/views/student/questions/show.html.erb
git commit -m "$(cat <<'EOF'
feat(tutor): add ConversationsController, chat drawer, and routes

- POST conversations#create: find_or_create conversation for question
- POST conversations#message: add user message + enqueue TutorStreamJob
- Rate limiting via streaming flag on Conversation
- Chat drawer partial with message display and input
- Modified questions/show to include tutor button and chat drawer
- Insight extraction triggered when navigating away from question

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10 : Stimulus chat_controller.js + request specs + smoke test

**Files:**
- Create: `app/javascript/controllers/chat_controller.js`
- Create: `spec/requests/student/conversations_spec.rb`

- [ ] **Step 1 : Creer app/javascript/controllers/chat_controller.js**

```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "messages", "streaming", "error", "input", "sendButton"]
  static values = {
    createUrl: String,
    messageUrl: String,
    questionId: Number,
    hasApiKey: Boolean,
    settingsUrl: String,
    conversationId: Number
  }

  connect() {
    this.consumer = null
    this.subscription = null
    this.isStreaming = false

    if (this.conversationIdValue) {
      this.subscribeToConversation(this.conversationIdValue)
    }
  }

  disconnect() {
    this.unsubscribe()
  }

  open() {
    if (!this.hasApiKeyValue) {
      if (confirm("Vous devez configurer votre cle IA pour utiliser le tutorat. Aller aux reglages ?")) {
        window.location.href = this.settingsUrlValue
      }
      return
    }

    this.drawerTarget.style.transform = "translateX(0)"
    this.backdropTarget.style.display = "block"

    if (!this.conversationIdValue) {
      this.createConversation()
    }

    this.scrollToBottom()
    this.inputTarget.focus()
  }

  close() {
    this.drawerTarget.style.transform = "translateX(100%)"
    this.backdropTarget.style.display = "none"
  }

  async createConversation() {
    try {
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ question_id: this.questionIdValue })
      })

      if (!response.ok) {
        const data = await response.json()
        this.showError(data.error || "Erreur lors de la creation de la conversation.")
        return
      }

      const data = await response.json()
      this.conversationIdValue = data.conversation_id
      this.subscribeToConversation(data.conversation_id)
    } catch (error) {
      this.showError("Erreur de connexion. Verifiez votre connexion internet.")
    }
  }

  async send() {
    if (this.isStreaming) return

    const content = this.inputTarget.value.trim()
    if (!content) return

    this.inputTarget.value = ""
    this.hideError()
    this.appendUserMessage(content)
    this.setStreaming(true)

    const messageUrl = `/${this.accessCode()}/conversations/${this.conversationIdValue}/message`

    try {
      const response = await fetch(messageUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ content: content })
      })

      if (!response.ok) {
        const data = await response.json()
        this.showError(data.error || "Erreur lors de l'envoi du message.")
        this.setStreaming(false)
      }
    } catch (error) {
      this.showError("Erreur de connexion. Verifiez votre connexion internet.")
      this.setStreaming(false)
    }
  }

  subscribeToConversation(conversationId) {
    this.unsubscribe()

    this.consumer = createConsumer()
    const controller = this

    this.subscription = this.consumer.subscriptions.create(
      { channel: "TutorChannel", conversation_id: conversationId },
      {
        received(data) {
          if (data.token) {
            controller.onToken(data.token)
          } else if (data.done) {
            controller.onDone()
          } else if (data.error) {
            controller.onError(data.error)
          }
        }
      }
    )
  }

  unsubscribe() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    if (this.consumer) {
      this.consumer.disconnect()
      this.consumer = null
    }
  }

  onToken(token) {
    this.streamingTarget.style.display = "block"
    this.streamingTarget.textContent += token
    this.scrollToBottom()
  }

  onDone() {
    const content = this.streamingTarget.textContent
    if (content) {
      this.appendAssistantMessage(content)
    }
    this.streamingTarget.textContent = ""
    this.streamingTarget.style.display = "none"
    this.setStreaming(false)
  }

  onError(message) {
    this.streamingTarget.textContent = ""
    this.streamingTarget.style.display = "none"
    this.showError(message)
    this.setStreaming(false)
  }

  appendUserMessage(content) {
    const div = document.createElement("div")
    div.style.cssText = "align-self: flex-end; background: #7c3aed; color: white; padding: 8px 12px; border-radius: 12px 12px 2px 12px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;"
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  appendAssistantMessage(content) {
    const div = document.createElement("div")
    div.style.cssText = "align-self: flex-start; background: #1e293b; color: #e2e8f0; padding: 8px 12px; border-radius: 12px 12px 12px 2px; max-width: 85%; font-size: 13px; line-height: 1.4; word-break: break-word;"
    div.textContent = content
    this.messagesTarget.appendChild(div)
    this.scrollToBottom()
  }

  setStreaming(value) {
    this.isStreaming = value
    this.inputTarget.disabled = value
    this.sendButtonTarget.disabled = value
    this.sendButtonTarget.style.opacity = value ? "0.5" : "1"
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.style.display = "block"
  }

  hideError() {
    this.errorTarget.textContent = ""
    this.errorTarget.style.display = "none"
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  accessCode() {
    return window.location.pathname.split("/")[1]
  }
}
```

- [ ] **Step 2 : Creer spec/requests/student/conversations_spec.rb**

```ruby
# spec/requests/student/conversations_spec.rb
require "rails_helper"

RSpec.describe "Student::Conversations", type: :request do
  let(:user) { create(:user) }
  let(:classroom) { create(:classroom, owner: user) }
  let(:student) { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:subject_record) { create(:subject, owner: user, status: :published) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
  let(:part) { create(:part, subject: subject_record) }
  let(:question) { create(:question, part: part, status: :validated) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /conversations" do
    it "creates a conversation for the question" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to be_present

      expect(Conversation.count).to eq(1)
      expect(Conversation.last.student).to eq(student)
      expect(Conversation.last.question).to eq(question)
    end

    it "returns existing conversation if one already exists" do
      existing = create(:conversation, student: student, question: question)

      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to eq(existing.id)
      expect(Conversation.count).to eq(1)
    end

    it "rejects when student has no API key" do
      student.update!(api_key: nil)

      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("cle IA")
    end
  end

  describe "POST /conversations/:id/message" do
    let!(:conversation) { create(:conversation, student: student, question: question) }

    it "adds a message and enqueues TutorStreamJob" do
      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "Aide-moi avec cette question" },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)

      conversation.reload
      expect(conversation.messages.last["role"]).to eq("user")
      expect(conversation.messages.last["content"]).to eq("Aide-moi avec cette question")

      expect(TutorStreamJob).to have_been_enqueued.with(conversation.id)
    end

    it "rejects empty messages" do
      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "  " },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects when conversation is already streaming" do
      conversation.update!(streaming: true)

      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "Question" },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:too_many_requests)
    end

    it "prevents accessing another student's conversation" do
      other_student = create(:student, classroom: classroom)
      other_conversation = create(:conversation, student: other_student, question: question)

      expect {
        post message_student_conversation_path(access_code: classroom.access_code, id: other_conversation.id),
             params: { content: "Hack" },
             headers: { "Accept" => "application/json" },
             as: :json
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec spec/requests/student/conversations_spec.rb
```

Resultat attendu : tous les tests passent.

- [ ] **Step 4 : Lancer la suite complete**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
bundle exec rspec
```

Resultat attendu : tous les tests existants + nouveaux passent.

- [ ] **Step 5 : Commit**

```bash
cd /home/fz/Documents/Dev/claudeCLI/DekatjeBakLa
git add app/javascript/controllers/chat_controller.js spec/requests/student/conversations_spec.rb
git commit -m "$(cat <<'EOF'
feat(tutor): add Stimulus chat controller and request specs

- chat_controller.js: ActionCable subscription, token streaming,
  open/close drawer, send messages, error display
- Request specs: create conversation, send message, rate limiting,
  API key requirement, authorization checks

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

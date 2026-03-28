# Extraction Pipeline — Plan B: Services, Job, Controller, Turbo Stream

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter les services d'extraction IA, le job Sidekiq, le retry controller et la notification Turbo Stream temps réel.

**Architecture:** Cinq services isolés (ResolveApiKey, AiClientFactory, BuildExtractionPrompt, ExtractQuestionsFromPdf, PersistExtractedData), un job Sidekiq qui les orchestre, mise à jour du SubjectsController pour déclencher le job et gérer le retry, partial Turbo Stream broadcasté depuis le job.

**Tech Stack:** Rails 8.1, Sidekiq, Faraday, pdf-reader, Turbo Streams, RSpec + FactoryBot

**Prérequis:** Plan A complété (modèles Part, Question, Answer existants, Sidekiq configuré)

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `app/services/resolve_api_key.rb` | Créer | Résolution clé API teacher ou serveur |
| `app/services/ai_client_factory.rb` | Créer | Client Faraday multi-provider |
| `app/services/build_extraction_prompt.rb` | Créer | Prompt système + messages pour Claude |
| `app/services/extract_questions_from_pdf.rb` | Créer | Lecture PDF + appel IA |
| `app/services/persist_extracted_data.rb` | Créer | Persistence Parts/Questions/Answers |
| `app/jobs/extract_questions_job.rb` | Créer | Orchestration + broadcast Turbo Stream |
| `app/controllers/teacher/subjects_controller.rb` | Modifier | Déclencher job + action retry_extraction |
| `app/views/teacher/subjects/_extraction_status.html.erb` | Créer | Partial statut extraction |
| `app/views/teacher/subjects/show.html.erb` | Modifier | turbo_stream_from + partial |
| `config/routes.rb` | Modifier | Ajouter post :retry_extraction |
| `spec/services/resolve_api_key_spec.rb` | Créer | Tests ResolveApiKey |
| `spec/services/ai_client_factory_spec.rb` | Créer | Tests AiClientFactory |
| `spec/services/build_extraction_prompt_spec.rb` | Créer | Tests BuildExtractionPrompt |
| `spec/services/persist_extracted_data_spec.rb` | Créer | Tests PersistExtractedData |
| `spec/jobs/extract_questions_job_spec.rb` | Créer | Tests job |

---

## Task 1 : Service ResolveApiKey (TDD)

**Files:**
- Create: `spec/services/resolve_api_key_spec.rb`
- Create: `app/services/resolve_api_key.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/resolve_api_key_spec.rb
require "rails_helper"

RSpec.describe ResolveApiKey do
  describe ".call" do
    context "when user has an encrypted api_key" do
      it "returns user api_key and provider" do
        user = create(:user, confirmed_at: Time.current)
        # Simule un api_key chiffré — on utilise le champ directement
        allow(user).to receive(:api_key).and_return("user-sk-test")
        allow(user).to receive(:api_provider).and_return("openrouter")

        result = described_class.call(user: user)

        expect(result[:api_key]).to eq("user-sk-test")
        expect(result[:provider]).to eq(:openrouter)
      end
    end

    context "when user has no api_key" do
      it "falls back to ANTHROPIC_API_KEY env var with anthropic provider" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return(nil)

        stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => "server-sk-test"))

        result = described_class.call(user: user)

        expect(result[:api_key]).to eq("server-sk-test")
        expect(result[:provider]).to eq(:anthropic)
      end

      it "raises if no api_key available at all" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return(nil)

        stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => nil))

        expect {
          described_class.call(user: user)
        }.to raise_error(ResolveApiKey::NoApiKeyError)
      end
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/resolve_api_key_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ResolveApiKey`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/resolve_api_key.rb
class ResolveApiKey
  class NoApiKeyError < StandardError; end

  def self.call(user:)
    if user.api_key.present?
      { api_key: user.api_key, provider: user.api_provider.to_sym }
    elsif ENV["ANTHROPIC_API_KEY"].present?
      { api_key: ENV["ANTHROPIC_API_KEY"], provider: :anthropic }
    else
      raise NoApiKeyError, "Aucune clé API disponible (ni enseignant ni serveur)"
    end
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/resolve_api_key_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/resolve_api_key.rb spec/services/resolve_api_key_spec.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add ResolveApiKey service with teacher/server fallback

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Service AiClientFactory (TDD)

**Files:**
- Create: `spec/services/ai_client_factory_spec.rb`
- Create: `app/services/ai_client_factory.rb`

- [ ] **Step 1 : Écrire les tests**

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

    it "calls anthropic API with correct headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "sk-ant-test" })
        .to_return(
          status: 200,
          body: { content: [ { text: '{"parts":[]}' } ] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      client = described_class.build(provider: :anthropic, api_key: "sk-ant-test")
      result = client.call(
        messages: [ { role: "user", content: "test" } ],
        system: "system prompt",
        max_tokens: 100,
        temperature: 0.1
      )

      expect(stub).to have_been_requested
      expect(result).to include("parts")
    end
  end
end
```

- [ ] **Step 2 : Ajouter webmock au Gemfile (groupe test)**

Lire le Gemfile, puis ajouter dans `group :test` :

```ruby
gem "webmock"
```

Puis :
```bash
bundle install
```

Commit :
```bash
git add Gemfile Gemfile.lock
git commit -m "$(cat <<'EOF'
chore(install): webmock to stub HTTP requests in AI client tests

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3 : Activer webmock dans rails_helper**

Lire `spec/rails_helper.rb`, puis ajouter en haut du fichier après les requires existants :

```ruby
require "webmock/rspec"
```

- [ ] **Step 4 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/ai_client_factory_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant AiClientFactory`

- [ ] **Step 5 : Créer le service**

```ruby
# app/services/ai_client_factory.rb
class AiClientFactory
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    anthropic:   { base_url: "https://api.anthropic.com/v1",               auth_header: "x-api-key" },
    openrouter:  { base_url: "https://openrouter.ai/api/v1",               auth_header: "Authorization" },
    openai:      { base_url: "https://api.openai.com/v1",                  auth_header: "Authorization" },
    google:      { base_url: "https://generativelanguage.googleapis.com/v1beta", auth_header: "x-goog-api-key" }
  }.freeze

  def self.build(provider:, api_key:)
    config = PROVIDERS[provider.to_sym]
    raise UnknownProviderError, "Unknown provider: #{provider}" unless config

    new(provider: provider.to_sym, api_key: api_key, config: config)
  end

  def initialize(provider:, api_key:, config:)
    @provider = provider
    @api_key  = api_key
    @config   = config
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
      { model: "claude-sonnet-4-5-20251001", system: system, messages: messages, max_tokens: max_tokens, temperature: temperature }
    when :openrouter
      { model: "anthropic/claude-haiku-4-5", messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :openai
      { model: "gpt-4o-mini", messages: [ { role: "system", content: system } ] + messages, max_tokens: max_tokens, temperature: temperature }
    when :google
      { contents: messages.map { |m| { role: m[:role], parts: [ { text: m[:content] } ] } }, system_instruction: { parts: [ { text: system } ] }, generationConfig: { maxOutputTokens: max_tokens, temperature: temperature } }
    end
  end

  def endpoint_path
    case @provider
    when :anthropic then "/messages"
    when :openrouter, :openai then "/chat/completions"
    when :google then "/models/gemini-2.0-flash:generateContent"
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

- [ ] **Step 6 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/ai_client_factory_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 7 : Commit**

```bash
git add app/services/ai_client_factory.rb spec/services/ai_client_factory_spec.rb spec/rails_helper.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add AiClientFactory with Faraday multi-provider support

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Service BuildExtractionPrompt (TDD)

**Files:**
- Create: `spec/services/build_extraction_prompt_spec.rb`
- Create: `app/services/build_extraction_prompt.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/build_extraction_prompt_spec.rb
require "rails_helper"

RSpec.describe BuildExtractionPrompt do
  describe ".call" do
    let(:text) { "Partie 1 - Question 1.1 : Calculer la consommation." }

    subject(:result) { described_class.call(text: text) }

    it "returns a hash with system and messages keys" do
      expect(result).to have_key(:system)
      expect(result).to have_key(:messages)
    end

    it "system prompt contains JSON schema instructions" do
      expect(result[:system]).to include("JSON")
      expect(result[:system]).to include("parts")
      expect(result[:system]).to include("questions")
    end

    it "messages contain the PDF text" do
      expect(result[:messages].first[:content]).to include(text)
    end

    it "messages use user role" do
      expect(result[:messages].first[:role]).to eq("user")
    end

    it "instructs to extract data_hints" do
      expect(result[:system]).to include("data_hints")
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/build_extraction_prompt_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant BuildExtractionPrompt`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/build_extraction_prompt.rb
class BuildExtractionPrompt
  SYSTEM_PROMPT = <<~PROMPT.freeze
    Tu es un assistant spécialisé dans l'analyse de sujets d'examens BAC STI2D français.
    Analyse le texte fourni et extrais toutes les informations structurées.

    Retourne UNIQUEMENT un objet JSON valide avec cette structure exacte :
    {
      "presentation": "Mise en situation générale du sujet",
      "parts": [
        {
          "number": 1,
          "title": "Titre de la partie",
          "objective": "Objectif pédagogique",
          "section_type": "common",
          "questions": [
            {
              "number": "1.1",
              "label": "Énoncé complet de la question",
              "context": "Contexte local ou données spécifiques (peut être vide)",
              "points": 2,
              "answer_type": "calculation",
              "correction": "Réponse officielle",
              "explanation": "Explication pédagogique",
              "data_hints": [
                {"source": "DT", "location": "description précise de l'emplacement"}
              ],
              "key_concepts": ["concept1", "concept2"]
            }
          ]
        }
      ]
    }

    Règles :
    - section_type : "common" (partie commune) ou "specific" (partie spécifique par spécialité)
    - answer_type : "text", "calculation", "argumentation", "dr_reference", "completion", "choice"
    - data_hints.source : "DT", "DR", "enonce", "question_context"
    - Ne retourne AUCUN texte en dehors du JSON
    - Si une information est manquante, utilise une chaîne vide "" ou un tableau vide []
  PROMPT

  def self.call(text:)
    {
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: "Voici le texte du sujet BAC à analyser :\n\n#{text}"
        }
      ]
    }
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/build_extraction_prompt_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/build_extraction_prompt.rb spec/services/build_extraction_prompt_spec.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add BuildExtractionPrompt service with JSON schema instructions

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Service PersistExtractedData (TDD)

**Files:**
- Create: `spec/services/persist_extracted_data_spec.rb`
- Create: `app/services/persist_extracted_data.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/persist_extracted_data_spec.rb
require "rails_helper"

RSpec.describe PersistExtractedData do
  let(:subject_obj) { create(:subject) }

  let(:data) do
    {
      "presentation" => "Mise en situation du sujet CIME.",
      "parts" => [
        {
          "number" => 1,
          "title" => "Comment le CIME s'inscrit dans une démarche DD ?",
          "objective" => "Comparer les modes de transport",
          "section_type" => "common",
          "questions" => [
            {
              "number" => "1.1",
              "label" => "Calculer la consommation en litres pour 186 km.",
              "context" => "Données : distance = 186 km",
              "points" => 2,
              "answer_type" => "calculation",
              "correction" => "Car = 56,73 l",
              "explanation" => "On applique : Conso × Distance / 100",
              "data_hints" => [ { "source" => "DT", "location" => "tableau Consommation" } ],
              "key_concepts" => [ "énergie primaire" ]
            }
          ]
        }
      ]
    }
  end

  describe ".call" do
    it "updates subject presentation_text" do
      described_class.call(subject: subject_obj, data: data)
      expect(subject_obj.reload.presentation_text).to eq("Mise en situation du sujet CIME.")
    end

    it "sets subject status to pending_validation" do
      described_class.call(subject: subject_obj, data: data)
      expect(subject_obj.reload.status).to eq("pending_validation")
    end

    it "creates parts" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Part, :count).by(1)
    end

    it "creates questions" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Question, :count).by(1)
    end

    it "creates answers" do
      expect {
        described_class.call(subject: subject_obj, data: data)
      }.to change(Answer, :count).by(1)
    end

    it "sets correct part attributes" do
      described_class.call(subject: subject_obj, data: data)
      part = subject_obj.reload.parts.first
      expect(part.number).to eq(1)
      expect(part.title).to eq("Comment le CIME s'inscrit dans une démarche DD ?")
      expect(part.section_type).to eq("common")
    end

    it "sets correct question attributes" do
      described_class.call(subject: subject_obj, data: data)
      question = subject_obj.parts.first.questions.first
      expect(question.number).to eq("1.1")
      expect(question.answer_type).to eq("calculation")
      expect(question.points).to eq(2.0)
    end

    it "sets correct answer attributes with data_hints" do
      described_class.call(subject: subject_obj, data: data)
      answer = subject_obj.parts.first.questions.first.answer
      expect(answer.correction_text).to eq("Car = 56,73 l")
      expect(answer.data_hints).to eq([ { "source" => "DT", "location" => "tableau Consommation" } ])
      expect(answer.key_concepts).to eq([ "énergie primaire" ])
    end

    it "rolls back on error" do
      bad_data = { "presentation" => "test", "parts" => [ { "number" => nil, "title" => nil, "section_type" => "common", "questions" => [] } ] }
      expect {
        described_class.call(subject: subject_obj, data: bad_data) rescue nil
      }.not_to change(Part, :count)
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/persist_extracted_data_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant PersistExtractedData`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/persist_extracted_data.rb
class PersistExtractedData
  def self.call(subject:, data:)
    ActiveRecord::Base.transaction do
      subject.update!(
        presentation_text: data["presentation"],
        status: :pending_validation
      )

      Array(data["parts"]).each_with_index do |part_data, part_index|
        part = subject.parts.create!(
          number:        part_data["number"].to_i,
          title:         part_data["title"].to_s,
          objective_text: part_data["objective"].to_s,
          section_type:  part_data["section_type"] || "common",
          position:      part_index
        )

        Array(part_data["questions"]).each_with_index do |q_data, q_index|
          question = part.questions.create!(
            number:       q_data["number"].to_s,
            label:        q_data["label"].to_s,
            context_text: q_data["context"].to_s,
            points:       q_data["points"].to_f,
            answer_type:  q_data["answer_type"] || "text",
            position:     q_index,
            status:       :draft
          )

          question.create_answer!(
            correction_text:  q_data["correction"].to_s,
            explanation_text: q_data["explanation"].to_s,
            key_concepts:     Array(q_data["key_concepts"]),
            data_hints:       Array(q_data["data_hints"])
          )
        end
      end
    end

    subject
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/persist_extracted_data_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/persist_extracted_data.rb spec/services/persist_extracted_data_spec.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add PersistExtractedData service with transactional persistence

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Job ExtractQuestionsJob (TDD)

**Files:**
- Create: `app/jobs/extract_questions_job.rb`
- Create: `spec/jobs/extract_questions_job_spec.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/jobs/extract_questions_job_spec.rb
require "rails_helper"

RSpec.describe ExtractQuestionsJob, type: :job do
  let(:subject_obj) { create(:subject) }
  let(:extraction_job) { create(:extraction_job, subject: subject_obj, status: :pending) }

  let(:resolved_key) { { api_key: "sk-test", provider: :anthropic } }
  let(:extracted_data) do
    { "presentation" => "Test", "parts" => [] }
  end

  before do
    extraction_job # ensure it exists
    allow(ResolveApiKey).to receive(:call).and_return(resolved_key)
    allow(ExtractQuestionsFromPdf).to receive(:call).and_return(extracted_data)
    allow(PersistExtractedData).to receive(:call).and_return(subject_obj)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  describe "#perform" do
    it "sets extraction_job status to processing then done" do
      described_class.perform_now(subject_obj.id)
      expect(extraction_job.reload.status).to eq("done")
    end

    it "calls ResolveApiKey with subject owner" do
      described_class.perform_now(subject_obj.id)
      expect(ResolveApiKey).to have_received(:call).with(user: subject_obj.owner)
    end

    it "calls ExtractQuestionsFromPdf with correct args" do
      described_class.perform_now(subject_obj.id)
      expect(ExtractQuestionsFromPdf).to have_received(:call).with(
        subject: subject_obj,
        api_key: "sk-test",
        provider: :anthropic
      )
    end

    it "calls PersistExtractedData" do
      described_class.perform_now(subject_obj.id)
      expect(PersistExtractedData).to have_received(:call).with(
        subject: subject_obj,
        data: extracted_data
      )
    end

    it "broadcasts Turbo Stream update" do
      described_class.perform_now(subject_obj.id)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
    end

    context "when an error occurs" do
      before do
        allow(ExtractQuestionsFromPdf).to receive(:call).and_raise(StandardError, "API timeout")
      end

      it "sets extraction_job status to failed" do
        described_class.perform_now(subject_obj.id)
        expect(extraction_job.reload.status).to eq("failed")
      end

      it "stores the error message" do
        described_class.perform_now(subject_obj.id)
        expect(extraction_job.reload.error_message).to eq("API timeout")
      end
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/jobs/extract_questions_job_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ExtractQuestionsJob`

- [ ] **Step 3 : Créer le job**

```ruby
# app/jobs/extract_questions_job.rb
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
    broadcast_extraction_status(subject) if subject
  end

  private

  def broadcast_extraction_status(subject)
    Turbo::StreamsChannel.broadcast_replace_to(
      "subject_#{subject.id}",
      target: "extraction-status",
      partial: "teacher/subjects/extraction_status",
      locals: { subject: subject }
    )
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/jobs/extract_questions_job_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/jobs/extract_questions_job.rb spec/jobs/extract_questions_job_spec.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add ExtractQuestionsJob with Sidekiq and Turbo Stream broadcast

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Service ExtractQuestionsFromPdf (TDD)

**Files:**
- Create: `spec/services/extract_questions_from_pdf_spec.rb`
- Create: `app/services/extract_questions_from_pdf.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/extract_questions_from_pdf_spec.rb
require "rails_helper"

RSpec.describe ExtractQuestionsFromPdf do
  let(:subject_obj) { create(:subject) }

  describe ".call" do
    before do
      # Stub pdf-reader to return fake text
      fake_reader = instance_double(PDF::Reader)
      allow(fake_reader).to receive(:pages).and_return([
        instance_double(PDF::Reader::Page, text: "Partie 1 Question 1.1 Calculer")
      ])
      allow(PDF::Reader).to receive(:new).and_return(fake_reader)

      # Stub AiClientFactory
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return('{"presentation":"test","parts":[]}')
    end

    it "returns a parsed hash" do
      result = described_class.call(
        subject: subject_obj,
        api_key: "sk-test",
        provider: :anthropic
      )
      expect(result).to be_a(Hash)
      expect(result).to have_key("presentation")
    end

    it "calls AiClientFactory with correct provider and api_key" do
      described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      expect(AiClientFactory).to have_received(:build).with(provider: :anthropic, api_key: "sk-test")
    end

    it "raises on invalid JSON response" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return("not valid json")

      expect {
        described_class.call(subject: subject_obj, api_key: "sk-test", provider: :anthropic)
      }.to raise_error(ExtractQuestionsFromPdf::ParseError)
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/extract_questions_from_pdf_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ExtractQuestionsFromPdf`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/extract_questions_from_pdf.rb
class ExtractQuestionsFromPdf
  class ParseError < StandardError; end

  def self.call(subject:, api_key:, provider:)
    # Télécharge le blob enonce_file et lit le texte PDF
    text = extract_text_from_pdf(subject.enonce_file)

    # Construit le prompt
    prompt = BuildExtractionPrompt.call(text: text)

    # Appelle l'IA
    client = AiClientFactory.build(provider: provider, api_key: api_key)
    raw_response = client.call(
      messages: prompt[:messages],
      system: prompt[:system],
      max_tokens: 8192,
      temperature: 0.1
    )

    # Parse le JSON
    parse_json_response(raw_response)
  end

  def self.extract_text_from_pdf(attachment)
    attachment.blob.open do |file|
      reader = PDF::Reader.new(file)
      reader.pages.map(&:text).join("\n")
    end
  end
  private_class_method :extract_text_from_pdf

  def self.parse_json_response(raw)
    # Extrait le JSON même si la réponse contient du texte autour
    json_match = raw.to_s.match(/\{.*\}/m)
    raise ParseError, "Réponse IA invalide : JSON introuvable" unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    raise ParseError, "Impossible de parser le JSON : #{e.message}"
  end
  private_class_method :parse_json_response
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/extract_questions_from_pdf_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/extract_questions_from_pdf.rb spec/services/extract_questions_from_pdf_spec.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add ExtractQuestionsFromPdf service with pdf-reader and JSON parsing

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Routes + Controller updates + Turbo Stream

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/teacher/subjects_controller.rb`
- Create: `app/views/teacher/subjects/_extraction_status.html.erb`
- Modify: `app/views/teacher/subjects/show.html.erb`

- [ ] **Step 1 : Ajouter retry_extraction dans routes.rb**

Lire `config/routes.rb`, puis modifier la section subjects pour ajouter `post :retry_extraction` :

```ruby
resources :subjects, only: [ :index, :new, :create, :show ] do
  member do
    patch :publish
    patch :archive
    post  :retry_extraction
  end
end
```

- [ ] **Step 2 : Mettre à jour SubjectsController**

Lire `app/controllers/teacher/subjects_controller.rb`, puis :

1. Dans `create`, après `@subject.create_extraction_job!(status: :pending, provider_used: :server)`, ajouter :
```ruby
ExtractQuestionsJob.perform_later(@subject.id)
```

2. Ajouter l'action `retry_extraction` et mettre à jour `before_action` :

```ruby
before_action :set_subject, only: [ :show, :publish, :archive, :retry_extraction ]
```

```ruby
def retry_extraction
  job = @subject.extraction_job
  unless job&.failed?
    return redirect_to teacher_subject_path(@subject),
                       alert: "L'extraction ne peut être relancée que si elle a échoué."
  end

  job.update!(status: :pending, error_message: nil)
  ExtractQuestionsJob.perform_later(@subject.id)
  redirect_to teacher_subject_path(@subject),
              notice: "Extraction relancée."
end
```

- [ ] **Step 3 : Créer le partial _extraction_status**

```erb
<%# app/views/teacher/subjects/_extraction_status.html.erb %>
<div id="extraction-status">
  <% job = subject.extraction_job %>
  <% if job %>
    <p>
      Statut extraction :
      <strong><%= job.status %></strong>
      <% if job.provider_used %>
        (via <%= job.provider_used %>)
      <% end %>
    </p>
    <% if job.failed? %>
      <p style="color: red;">Erreur : <%= job.error_message %></p>
      <%= button_to "Relancer l'extraction",
          retry_extraction_teacher_subject_path(subject),
          method: :post %>
    <% end %>
    <% if job.processing? %>
      <p>Extraction en cours... <em>(la page se mettra à jour automatiquement)</em></p>
    <% end %>
  <% else %>
    <p>Aucun job d'extraction.</p>
  <% end %>
</div>
```

- [ ] **Step 4 : Mettre à jour show.html.erb**

Lire `app/views/teacher/subjects/show.html.erb`, puis remplacer la section `<h2>Extraction</h2>` par :

```erb
<%= turbo_stream_from "subject_#{@subject.id}" %>

<h2>Extraction</h2>
<%= render "extraction_status", subject: @subject %>
```

- [ ] **Step 5 : Vérifier les routes**

```bash
bin/rails routes | grep "retry_extraction"
```

Résultat attendu : `retry_extraction_teacher_subject POST /teacher/subjects/:id/retry_extraction`

- [ ] **Step 6 : Commit**

```bash
git add config/routes.rb app/controllers/teacher/subjects_controller.rb app/views/teacher/subjects/
git commit -m "$(cat <<'EOF'
feat(extraction): wire job to controller, add retry_extraction action and Turbo Stream

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8 : Smoke test final

- [ ] **Step 1 : Lancer toute la suite RSpec**

```bash
bundle exec rspec spec/models/ spec/services/ spec/jobs/ spec/requests/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep -E "retry_extraction|subject"
```

- [ ] **Step 3 : Rubocop**

```bash
bin/rubocop --no-color 2>&1 | tail -5
```

Résultat attendu : `no offenses detected`

- [ ] **Step 4 : Commit final si nécessaire**

```bash
git status
# Si des fichiers non commités :
git add .
git commit -m "$(cat <<'EOF'
chore: finalize extraction pipeline implementation

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

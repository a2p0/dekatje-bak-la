# Student API Key Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow students to configure their default work mode, AI provider, model, and API key from a settings page, with key validation.

**Architecture:** Migration to replace legacy encrypted columns with Rails 8 `encrypts`, add `api_model` and `default_mode`. Settings controller with Turbo Frame key validation. Stimulus controller for dynamic model dropdown. ValidateStudentApiKey service using AiClientFactory.

**Tech Stack:** Rails 8.1, Hotwire/Turbo Frames, Stimulus, RSpec

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_update_students_for_api_config.rb` | Créer | Migration colonnes |
| `app/models/student.rb` | Modifier | encrypts, default_mode enum, AVAILABLE_MODELS |
| `config/routes.rb` | Modifier | Routes settings + test_key |
| `app/controllers/student/settings_controller.rb` | Créer | show, update, test_key |
| `app/services/validate_student_api_key.rb` | Créer | Test clé API |
| `app/views/student/settings/show.html.erb` | Créer | Formulaire settings |
| `app/views/student/questions/_sidebar.html.erb` | Modifier | Lien settings |
| `app/javascript/controllers/settings_controller.js` | Créer | Dynamic model dropdown + toggle |
| `spec/services/validate_student_api_key_spec.rb` | Créer | Tests service |
| `spec/requests/student/settings_spec.rb` | Créer | Tests request |

---

## Task 1 : Migration + modèle Student

**Files:**
- Create: `db/migrate/TIMESTAMP_update_students_for_api_config.rb`
- Modify: `app/models/student.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration UpdateStudentsForApiConfig
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class UpdateStudentsForApiConfig < ActiveRecord::Migration[8.1]
  def change
    remove_column :students, :encrypted_api_key, :string
    remove_column :students, :encrypted_api_key_iv, :string
    add_column :students, :api_key, :string
    add_column :students, :api_model, :string
    add_column :students, :default_mode, :integer, default: 0, null: false
  end
end
```

- [ ] **Step 3 : Migrer**

```bash
bin/rails db:migrate
```

Résultat attendu : `UpdateStudentsForApiConfig: migrated`

- [ ] **Step 4 : Mettre à jour app/models/student.rb**

Remplacer le contenu entier par :

```ruby
class Student < ApplicationRecord
  belongs_to :classroom
  has_secure_password
  has_many :student_sessions, dependent: :destroy

  encrypts :api_key

  enum :api_provider, { openrouter: 0, anthropic: 1, openai: 2, google: 3 }
  enum :default_mode, { revision: 0, tutored: 1 }

  validates :first_name, :last_name, :username, presence: true
  validates :username, uniqueness: { scope: :classroom_id }

  AVAILABLE_MODELS = {
    "openrouter" => [
      { id: "qwen/qwen3-next-80b-a3b-instruct:free", label: "Qwen3 80B (gratuit)", cost: "🆓", note: "Lent, rate limit bas" },
      { id: "deepseek/deepseek-chat-v3-0324", label: "DeepSeek V3", cost: "$" },
      { id: "anthropic/claude-sonnet-4-5", label: "Claude Sonnet 4.5", cost: "$$" }
    ],
    "anthropic" => [
      { id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5", cost: "$" },
      { id: "claude-sonnet-4-5-20250514", label: "Claude Sonnet 4.5", cost: "$$" }
    ],
    "openai" => [
      { id: "gpt-4o-mini", label: "GPT-4o Mini", cost: "$" },
      { id: "gpt-4o", label: "GPT-4o", cost: "$$" }
    ],
    "google" => [
      { id: "gemini-2.0-flash", label: "Gemini 2.0 Flash", cost: "$" },
      { id: "gemini-2.5-pro-preview-06-05", label: "Gemini 2.5 Pro", cost: "$$$" }
    ]
  }.freeze

  def default_model_for_provider
    AVAILABLE_MODELS[api_provider]&.first&.dig(:id)
  end

  def effective_model
    api_model.presence || default_model_for_provider
  end
end
```

- [ ] **Step 5 : Lancer les tests existants**

```bash
bundle exec rspec spec/models/student_spec.rb
```

Résultat attendu : tous PASS (les tests existants ne dépendent pas des anciennes colonnes)

- [ ] **Step 6 : Commit**

```bash
git add db/migrate/ db/schema.rb app/models/student.rb
git commit -m "$(cat <<'EOF'
feat(student): migrate to Rails 8 encrypts, add api_model and default_mode

Replace legacy encrypted_api_key/iv columns with encrypts :api_key.
Add AVAILABLE_MODELS constant with per-provider model lists and cost indicators.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Routes + SettingsController + vue

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/student/settings_controller.rb`
- Create: `app/views/student/settings/show.html.erb`

- [ ] **Step 1 : Mettre à jour config/routes.rb**

Ajouter dans le bloc `scope "/:access_code", as: :student do`, après la ligne `patch "/subjects/:subject_id/questions/:id/reveal"...` :

```ruby
get   "/settings",          to: "student/settings#show",     as: :settings
patch "/settings",          to: "student/settings#update"
post  "/settings/test_key", to: "student/settings#test_key", as: :test_key
```

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep "settings\|test_key"
```

Résultat attendu : `student_settings`, `student_test_key`

- [ ] **Step 3 : Créer app/controllers/student/settings_controller.rb**

```ruby
class Student::SettingsController < Student::BaseController
  def show
    @models_json = Student::AVAILABLE_MODELS.to_json
  end

  def update
    if current_student.update(settings_params)
      redirect_to student_settings_path(access_code: params[:access_code]),
                  notice: "Réglages enregistrés."
    else
      @models_json = Student::AVAILABLE_MODELS.to_json
      render :show, status: :unprocessable_entity
    end
  end

  def test_key
    result = ValidateStudentApiKey.call(
      provider: params[:provider],
      api_key: params[:api_key],
      model: params[:model]
    )

    render turbo_stream: turbo_stream.replace(
      "test_key_result",
      html: if result[:valid]
              '<p id="test_key_result" style="color: #22c55e; font-size: 13px; margin-top: 8px;">✓ Clé valide — connexion réussie.</p>'.html_safe
            else
              "<p id=\"test_key_result\" style=\"color: #ef4444; font-size: 13px; margin-top: 8px;\">✗ #{ERB::Util.html_escape(result[:error])}</p>".html_safe
            end
    )
  end

  private

  def settings_params
    params.require(:student).permit(:default_mode, :api_provider, :api_model, :api_key)
  end
end
```

- [ ] **Step 4 : Créer app/views/student/settings/show.html.erb**

```erb
<div style="max-width: 600px; margin: 0 auto; padding: 24px;">
  <h1 style="margin-bottom: 24px;">Réglages</h1>

  <% if flash[:notice] %>
    <p style="color: #22c55e; margin-bottom: 16px;"><%= flash[:notice] %></p>
  <% end %>

  <%= form_with model: current_student, url: student_settings_path(access_code: params[:access_code]),
                method: :patch, data: { controller: "settings", settings_models_value: @models_json } do |f| %>

    <fieldset style="border: 1px solid #374151; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
      <legend style="color: #9ca3af; font-size: 13px; text-transform: uppercase; padding: 0 8px;">Mode par défaut</legend>

      <div style="margin-bottom: 8px;">
        <label style="display: flex; align-items: center; gap: 8px; color: #e2e8f0; cursor: pointer;">
          <%= f.radio_button :default_mode, "revision", style: "accent-color: #7c3aed;" %>
          Révision autonome (correction seule)
        </label>
      </div>
      <div>
        <label style="display: flex; align-items: center; gap: 8px; color: #e2e8f0; cursor: pointer;">
          <%= f.radio_button :default_mode, "tutored", style: "accent-color: #7c3aed;" %>
          Tutorat IA (nécessite une clé API)
        </label>
      </div>
    </fieldset>

    <fieldset style="border: 1px solid #374151; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
      <legend style="color: #9ca3af; font-size: 13px; text-transform: uppercase; padding: 0 8px;">Configuration IA</legend>

      <div style="margin-bottom: 16px;">
        <%= f.label :api_provider, "Provider", style: "display: block; color: #9ca3af; font-size: 13px; margin-bottom: 4px;" %>
        <%= f.select :api_provider,
            Student.api_providers.keys.map { |k| [k.capitalize, k] },
            {},
            style: "width: 100%; padding: 8px; background: #1e293b; color: #e2e8f0; border: 1px solid #374151; border-radius: 6px;",
            data: { action: "change->settings#providerChanged", settings_target: "provider" } %>
      </div>

      <div style="margin-bottom: 16px;">
        <%= f.label :api_model, "Modèle", style: "display: block; color: #9ca3af; font-size: 13px; margin-bottom: 4px;" %>
        <select name="student[api_model]"
                data-settings-target="model"
                style="width: 100%; padding: 8px; background: #1e293b; color: #e2e8f0; border: 1px solid #374151; border-radius: 6px;">
          <% models = Student::AVAILABLE_MODELS[current_student.api_provider] || [] %>
          <% models.each do |m| %>
            <option value="<%= m[:id] %>" <%= "selected" if current_student.api_model == m[:id] || (current_student.api_model.blank? && m == models.first) %>>
              <%= m[:cost] %> <%= m[:label] %><%= " — #{m[:note]}" if m[:note] %>
            </option>
          <% end %>
        </select>
      </div>

      <div style="margin-bottom: 16px;">
        <%= f.label :api_key, "Clé API", style: "display: block; color: #9ca3af; font-size: 13px; margin-bottom: 4px;" %>
        <div style="display: flex; gap: 8px;">
          <%= f.password_field :api_key,
              value: current_student.api_key,
              placeholder: "sk-...",
              style: "flex: 1; padding: 8px; background: #1e293b; color: #e2e8f0; border: 1px solid #374151; border-radius: 6px;",
              data: { settings_target: "apiKey" } %>
          <button type="button"
                  data-action="click->settings#toggleApiKey"
                  style="padding: 8px 12px; background: #1e293b; color: #9ca3af; border: 1px solid #374151; border-radius: 6px; cursor: pointer;">
            👁
          </button>
        </div>
      </div>

      <button type="button"
              data-action="click->settings#testKey"
              data-settings-target="testButton"
              style="padding: 8px 16px; background: #374151; color: #e2e8f0; border: none; border-radius: 6px; cursor: pointer; font-size: 13px;">
        Tester la clé
      </button>

      <%= turbo_frame_tag "test_key_result" do %>
        <p id="test_key_result"></p>
      <% end %>
    </fieldset>

    <%= f.submit "Enregistrer",
        style: "padding: 12px 32px; background: #7c3aed; color: white; border: none; border-radius: 6px; font-size: 14px; cursor: pointer;" %>
  <% end %>

  <%= link_to "← Retour aux sujets",
      student_root_path(access_code: params[:access_code]),
      style: "display: inline-block; margin-top: 16px; color: #7c3aed; text-decoration: none; font-size: 13px;" %>
</div>
```

- [ ] **Step 5 : Commit**

```bash
git add config/routes.rb app/controllers/student/settings_controller.rb app/views/student/settings/
git commit -m "$(cat <<'EOF'
feat(student): add SettingsController with settings form and test_key action

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : ValidateStudentApiKey service

**Files:**
- Create: `app/services/validate_student_api_key.rb`
- Create: `spec/services/validate_student_api_key_spec.rb`

- [ ] **Step 1 : Créer spec/services/validate_student_api_key_spec.rb**

```ruby
require "rails_helper"

RSpec.describe ValidateStudentApiKey do
  describe ".call" do
    it "returns valid for working key" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return("OK")

      result = described_class.call(provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001")
      expect(result[:valid]).to be true
    end

    it "returns invalid for bad key" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_raise("API error 401: Unauthorized")

      result = described_class.call(provider: "anthropic", api_key: "bad-key", model: "claude-haiku-4-5-20251001")
      expect(result[:valid]).to be false
      expect(result[:error]).to include("401")
    end

    it "returns invalid for unknown provider" do
      result = described_class.call(provider: "unknown", api_key: "sk-test", model: "some-model")
      expect(result[:valid]).to be false
      expect(result[:error]).to include("Provider inconnu")
    end

    it "handles timeout errors" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_raise(Faraday::TimeoutError)

      result = described_class.call(provider: "openai", api_key: "sk-test", model: "gpt-4o-mini")
      expect(result[:valid]).to be false
      expect(result[:error]).to include("Timeout")
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/validate_student_api_key_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ValidateStudentApiKey`

- [ ] **Step 3 : Créer app/services/validate_student_api_key.rb**

```ruby
class ValidateStudentApiKey
  def self.call(provider:, api_key:, model:)
    client = AiClientFactory.build(provider: provider, api_key: api_key)
    client.call(
      messages: [ { role: "user", content: "Réponds OK" } ],
      system: "Réponds uniquement OK.",
      max_tokens: 10,
      temperature: 0
    )
    { valid: true }
  rescue AiClientFactory::UnknownProviderError
    { valid: false, error: "Provider inconnu : #{provider}" }
  rescue Faraday::TimeoutError
    { valid: false, error: "Timeout — le serveur n'a pas répondu." }
  rescue => e
    { valid: false, error: e.message }
  end
end
```

Note : `AiClientFactory` utilise actuellement des modèles en dur dans `build_body`. Pour le MVP, le service valide que la clé fonctionne avec le modèle par défaut du provider. L'adaptation de `AiClientFactory` pour accepter un paramètre `model:` sera faite dans la task 10 (Mode 2 tutorat) quand on en aura réellement besoin.

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/validate_student_api_key_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/validate_student_api_key.rb spec/services/validate_student_api_key_spec.rb
git commit -m "$(cat <<'EOF'
feat(student): add ValidateStudentApiKey service for API key testing

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Stimulus settings controller

**Files:**
- Create: `app/javascript/controllers/settings_controller.js`

- [ ] **Step 1 : Créer app/javascript/controllers/settings_controller.js**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "model", "apiKey", "testButton"]
  static values = { models: Object }

  providerChanged() {
    const provider = this.providerTarget.value
    const models = this.modelsValue[provider] || []
    const select = this.modelTarget

    select.innerHTML = ""
    models.forEach((m, i) => {
      const option = document.createElement("option")
      option.value = m.id
      option.textContent = `${m.cost} ${m.label}${m.note ? ` — ${m.note}` : ""}`
      if (i === 0) option.selected = true
      select.appendChild(option)
    })
  }

  toggleApiKey() {
    const input = this.apiKeyTarget
    input.type = input.type === "password" ? "text" : "password"
  }

  async testKey() {
    const provider = this.providerTarget.value
    const model = this.modelTarget.value
    const apiKey = this.apiKeyTarget.value

    if (!apiKey) {
      document.getElementById("test_key_result").innerHTML =
        '<p style="color: #f59e0b; font-size: 13px;">Entrez une clé API d\'abord.</p>'
      return
    }

    this.testButtonTarget.disabled = true
    this.testButtonTarget.textContent = "Test en cours..."

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(
      window.location.pathname.replace("/settings", "/settings/test_key"),
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token
        },
        body: `provider=${encodeURIComponent(provider)}&api_key=${encodeURIComponent(apiKey)}&model=${encodeURIComponent(model)}`
      }
    )

    const html = await response.text()
    Turbo.renderStreamMessage(html)

    this.testButtonTarget.disabled = false
    this.testButtonTarget.textContent = "Tester la clé"
  }
}
```

- [ ] **Step 2 : Commit**

```bash
git add app/javascript/controllers/settings_controller.js
git commit -m "$(cat <<'EOF'
feat(student): add settings Stimulus controller for dynamic model dropdown and key test

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Lien settings dans la sidebar + subjects index

**Files:**
- Modify: `app/views/student/questions/_sidebar.html.erb`
- Modify: `app/views/student/subjects/index.html.erb`

- [ ] **Step 1 : Ajouter le lien settings dans la sidebar**

À la fin du fichier `app/views/student/questions/_sidebar.html.erb`, juste avant la dernière balise `</div>`, ajouter :

```erb
  <hr style="border-color: #374151; margin: 12px 0;">

  <%= link_to "⚙ Réglages",
      student_settings_path(access_code: access_code),
      style: "display: block; color: #9ca3af; font-size: 13px; text-decoration: none; padding: 6px 8px;" %>
```

- [ ] **Step 2 : Ajouter le lien settings dans la page subjects index**

Dans `app/views/student/subjects/index.html.erb`, remplacer le lien de déconnexion existant :

```erb
<%= link_to "Se déconnecter", student_session_path(access_code: params[:access_code]), data: { turbo_method: :delete } %>
```

par :

```erb
<div style="display: flex; gap: 16px; margin-top: 24px;">
  <%= link_to "⚙ Réglages",
      student_settings_path(access_code: params[:access_code]),
      style: "color: #9ca3af; text-decoration: none;" %>
  <%= link_to "Se déconnecter",
      student_session_path(access_code: params[:access_code]),
      data: { turbo_method: :delete },
      style: "color: #9ca3af; text-decoration: none;" %>
</div>
```

- [ ] **Step 3 : Commit**

```bash
git add app/views/student/questions/_sidebar.html.erb app/views/student/subjects/index.html.erb
git commit -m "$(cat <<'EOF'
feat(student): add settings link to sidebar and subjects index

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Request specs

**Files:**
- Create: `spec/requests/student/settings_spec.rb`

- [ ] **Step 1 : Créer spec/requests/student/settings_spec.rb**

```ruby
require "rails_helper"

RSpec.describe "Student::Settings", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /settings" do
    it "returns 200" do
      get student_settings_path(access_code: classroom.access_code)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /settings" do
    it "updates default_mode" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { default_mode: "tutored" } }
      expect(student.reload.default_mode).to eq("tutored")
      expect(response).to redirect_to(student_settings_path(access_code: classroom.access_code))
    end

    it "updates api_provider and api_model" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { api_provider: "anthropic", api_model: "claude-haiku-4-5-20251001" } }
      student.reload
      expect(student.api_provider).to eq("anthropic")
      expect(student.api_model).to eq("claude-haiku-4-5-20251001")
    end

    it "updates api_key (encrypted)" do
      patch student_settings_path(access_code: classroom.access_code),
            params: { student: { api_key: "sk-test-key-123" } }
      expect(student.reload.api_key).to eq("sk-test-key-123")
    end
  end

  describe "POST /settings/test_key" do
    it "returns turbo stream with valid result" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_return("OK")

      post student_test_key_path(access_code: classroom.access_code),
           params: { provider: "anthropic", api_key: "sk-test", model: "claude-haiku-4-5-20251001" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("valide")
    end

    it "returns turbo stream with error for bad key" do
      fake_client = instance_double(AiClientFactory)
      allow(AiClientFactory).to receive(:build).and_return(fake_client)
      allow(fake_client).to receive(:call).and_raise("API error 401: Unauthorized")

      post student_test_key_path(access_code: classroom.access_code),
           params: { provider: "anthropic", api_key: "bad", model: "claude-haiku-4-5-20251001" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("401")
    end
  end
end
```

- [ ] **Step 2 : Lancer les specs**

```bash
bundle exec rspec spec/requests/student/settings_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 3 : Commit**

```bash
git add spec/requests/student/settings_spec.rb
git commit -m "$(cat <<'EOF'
test(student): add request specs for settings controller

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Smoke test final

- [ ] **Step 1 : Lancer la suite RSpec complète**

```bash
bundle exec rspec spec/models/ spec/requests/ spec/services/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep "settings\|test_key"
```

- [ ] **Step 3 : Rubocop**

```bash
bin/rubocop --no-color 2>&1 | tail -5
```

Résultat attendu : `no offenses detected`

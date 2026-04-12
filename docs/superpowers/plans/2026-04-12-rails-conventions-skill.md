# Rails Conventions Skill + MCP Server — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Claude Code and subagents Rails 8 conventions via a modular skill, live project data via rails-mcp-server, and official docs via context7.

**Architecture:** A SKILL.md entry point with 6 reference files covering models, controllers, services, views/hotwire, jobs, and tests. A `.mcp.json` at project root configures rails-mcp-server for live project introspection.

**Tech Stack:** Claude Code skills (SKILL.md + references/), rails-mcp-server gem (MCP STDIO), context7 MCP

---

### Task 1: Install rails-mcp-server

**Files:**
- Create: `.mcp.json` (project root)

- [ ] **Step 1: Install the gem globally**

Run: `gem install rails-mcp-server`
Expected: `Successfully installed rails-mcp-server-1.x.x`

- [ ] **Step 2: Create `.mcp.json` at project root**

```json
{
  "mcpServers": {
    "rails": {
      "command": "rails-mcp-server",
      "args": ["--single-project"],
      "env": {
        "RAILS_MCP_PROJECT_PATH": "."
      }
    }
  }
}
```

- [ ] **Step 3: Add `.mcp.json` to git**

Run: `git add .mcp.json && git commit -m "chore(mcp): add rails-mcp-server config for project introspection"`

- [ ] **Step 4: Restart Claude Code and verify MCP server loads**

Restart Claude Code (exit and re-enter the project). Verify the `rails` MCP server appears in the available tools. Test with a simple call:
- Call `execute_tool` with `tool_name: "project_info"` — should return Rails version and project structure
- Call `execute_tool` with `tool_name: "get_routes"` — should return the project routes

If the MCP server doesn't load, check:
- `which rails-mcp-server` returns a valid path
- Ruby version is >= 3.2.0
- The gem's dependencies are satisfied (`activesupport >= 7.0`, `puma ~> 7.1`)

---

### Task 2: Create SKILL.md entry point

**Files:**
- Create: `~/.claude/skills/rails-conventions/SKILL.md`

- [ ] **Step 1: Create the skill directory**

Run: `mkdir -p ~/.claude/skills/rails-conventions/references`

- [ ] **Step 2: Write SKILL.md**

```markdown
---
name: rails-conventions
description: Apply Rails 8 conventions and best practices when writing Ruby, ERB, or Stimulus code
---

# Rails Conventions

Apply these conventions when writing or modifying Ruby, ERB, or JavaScript code in a Rails project.

## Principles

1. **Convention over configuration** — follow Rails defaults unless there's a documented reason not to
2. **Code in English, UI in French** — model names, methods, variables in English; user-facing strings in French
3. **Consult context7** (`/websites/guides_rubyonrails_v8_0`) for any non-trivial Rails pattern before implementing
4. **Use MCP `rails` tools** (`execute_tool`, `get_routes`, `analyze_models`) to check current project state before modifying models, routes, or associations
5. **YAGNI** — no premature abstractions, no speculative features

## Service Convention

All new services follow this pattern (existing services are NOT refactored):

- Single public method: `self.call` (class method delegating to instance)
- Naming: verb + noun (`ExtractQuestionsFromPdf`, `GenerateStudentCredentials`)
- Success: return the domain object (Student, Subject, String...)
- Failure: raise a custom exception inheriting from `StandardError`
- DB transactions when creating/modifying multiple models

## Quick Reference — Common Anti-Patterns

| Don't | Do | Reference |
|---|---|---|
| Business logic in controller | Service object | `references/services.md` |
| `where()` in controller | Named scope | `references/models.md` |
| Inline JS in views | Stimulus controller | `references/views-hotwire.md` |
| `after_save` callback | `after_create_commit` or service | `references/models.md` |
| Fixtures | FactoryBot factories | `references/tests.md` |
| N+1 queries | `includes()` / `preload()` | `references/models.md` |
| Mock API calls without VCR | VCR/WebMock cassettes | `references/tests.md` |

## Domain References

- **Models** — ActiveRecord validations, associations, scopes, callbacks, migrations: `references/models.md`
- **Controllers** — RESTful actions, strong params, before_action, routing: `references/controllers.md`
- **Services** — Pattern, exceptions, dependency injection, when to extract: `references/services.md`
- **Views & Hotwire** — ERB partials, Turbo Frames/Streams, ActionCable, caching: `references/views-hotwire.md`
- **Jobs** — Sidekiq, idempotence, retry, queues: `references/jobs.md`
- **Tests** — RSpec, FactoryBot, Capybara, VCR, edge cases: `references/tests.md`

> For Stimulus controller conventions (JS), see the `better-stimulus` skill.
```

- [ ] **Step 3: Verify skill is detected**

Run: `/rails-conventions` in Claude Code. The skill content should load.

- [ ] **Step 4: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/SKILL.md && git commit -m "feat(skill): add rails-conventions skill entry point"`

If `~/.claude` is not a git repo, skip this commit step — the files are local config.

---

### Task 3: Create references/models.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/models.md`

- [ ] **Step 1: Write models.md**

```markdown
# Models — ActiveRecord Conventions

## Validations

- Use built-in validators first (`presence`, `uniqueness`, `numericality`, `inclusion`)
- Custom validators for complex business rules
- DB constraints (NOT NULL, UNIQUE index) for critical validations — belt and suspenders

```ruby
# Good: built-in + DB constraint
validates :email, presence: true, uniqueness: { case_sensitive: false }
# Migration: add_index :users, :email, unique: true
```

## Associations

- Always declare `dependent:` on `has_many` (`:destroy`, `:nullify`, or `:restrict_with_error`)
- `inverse_of` for bidirectional associations
- `counter_cache: true` when displaying counts frequently

```ruby
# Good
has_many :parts, dependent: :destroy, inverse_of: :subject
belongs_to :subject, counter_cache: true
```

## Scopes & Queries

- Named scopes for reusable, chainable queries
- N+1 prevention:
  - `includes()` — associations used in views (lets Rails choose strategy)
  - `preload()` — force separate queries
  - `eager_load()` — force LEFT JOIN (when filtering on association)
- Index foreign keys and columns used in WHERE/ORDER

Bad:
```ruby
# N+1 in controller
@subjects = Subject.all
# View: subject.parts.each → N+1
```

Good:
```ruby
@subjects = Subject.includes(:parts).all
```

## Callbacks

- Limit to `before_validation` and `after_create_commit`
- Everything else → service object
- Never call external services (API, email) from a callback

Bad:
```ruby
after_save :send_notification, :update_stats, :sync_external
```

Good:
```ruby
after_create_commit :broadcast_creation

private

def broadcast_creation
  broadcast_prepend_to "subjects"
end
```

## Migrations

- Always reversible (`change` or explicit `up`/`down`)
- Index foreign keys and frequently queried columns
- Strong types (avoid `string` for everything — use `integer`, `boolean`, `jsonb`, enums)
- Consider impact on existing data before adding NOT NULL without defaults
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/models.md && git commit -m "feat(skill): add models reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 4: Create references/controllers.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/controllers.md`

- [ ] **Step 1: Write controllers.md**

```markdown
# Controllers — RESTful Conventions

## RESTful Design

- Maximum 7 actions: index, show, new, create, edit, update, destroy
- If an action doesn't fit → new controller (e.g., `Students::PasswordResetsController`)
- One controller per resource

## Strong Params

Always in a private method, never inline:

```ruby
private

def student_params
  params.expect(student: [:first_name, :last_name, :password])
end
```

## before_action

- Authentication and authorization
- Setup shared instance variables (`set_subject`, `set_classroom`)
- Keep simple and focused — no business logic

```ruby
before_action :authenticate_teacher!
before_action :set_classroom, only: [:show, :edit, :update, :destroy]

private

def set_classroom
  @classroom = current_user.classrooms.find(params[:id])
end
```

## Responses

- Turbo Stream by default for create/update/destroy
- HTML fallback for classic navigation
- `rescue_from` for service exceptions

```ruby
rescue_from ActiveRecord::RecordNotFound, with: :not_found
rescue_from AuthenticationError, with: :unauthorized

private

def not_found
  redirect_to root_path, alert: "Ressource introuvable"
end
```

## Routing

- `resources` for RESTful routes
- Nesting max 1 level: `resources :classrooms { resources :students }`
- `member` and `collection` sparingly

Bad:
```ruby
# Fat controller with business logic
def create
  @student = Student.new(student_params)
  @student.username = "#{@student.first_name}.#{@student.last_name}".downcase
  @student.password = SecureRandom.hex(4)
  if @student.save
    # ...
  end
end
```

Good:
```ruby
def create
  @student = GenerateStudentCredentials.call(
    classroom: @classroom,
    **student_params
  )
  redirect_to classroom_students_path(@classroom)
end
```
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/controllers.md && git commit -m "feat(skill): add controllers reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 5: Create references/services.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/services.md`

- [ ] **Step 1: Write services.md**

```markdown
# Services — Business Logic Conventions

## Standard Pattern

```ruby
class ExtractQuestionsFromPdf
  def self.call(subject:, pdf_content:)
    new(subject:, pdf_content:).call
  end

  def initialize(subject:, pdf_content:)
    @subject = subject
    @pdf_content = pdf_content
  end

  def call
    api_key = ResolveApiKey.call(user: @subject.owner)
    raw_json = request_extraction(api_key)
    PersistExtractedData.call(subject: @subject, data: raw_json)
  end

  private

  def request_extraction(api_key)
    # ...
  end
end
```

## Rules

- `self.call` as the only public method
- Naming: verb + noun
- Success → return the domain object (Student, Subject, String...)
- Failure → raise a custom exception
- DB transaction when creating/modifying multiple models

## Custom Exceptions

Define inside the service class:

```ruby
class ExtractQuestionsFromPdf
  class ParseError < StandardError; end
  class ApiKeyMissingError < StandardError; end

  def call
    raise ApiKeyMissingError, "Aucune clé API disponible" unless api_key
    # ...
  rescue JSON::ParserError => e
    raise ParseError, "Réponse API invalide : #{e.message}"
  end
end
```

## Dependency Injection

For services calling external APIs — inject the client for testability:

```ruby
class StreamAiResponse
  def self.call(prompt:, client: nil)
    new(prompt:, client:).call
  end

  def initialize(prompt:, client: nil)
    @prompt = prompt
    @client = client || AiClientFactory.build(provider: :anthropic)
  end
end
```

This allows mocking the client in tests without monkey-patching.

## When to Create a Service

- Logic involving multiple models
- External API calls
- Complex operations called from multiple places
- Logic that isn't the model's responsibility

Bad:
```ruby
# Inconsistent return
def call
  return { success: false, error: "not found" } unless @student
  { success: true, data: @student }
end
```

Good:
```ruby
def call
  raise ActiveRecord::RecordNotFound, "Élève introuvable" unless @student
  @student
end
```
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/services.md && git commit -m "feat(skill): add services reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 6: Create references/views-hotwire.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/views-hotwire.md`

- [ ] **Step 1: Write views-hotwire.md**

```markdown
# Views & Hotwire — Server-Side Conventions

> For Stimulus controller conventions (JS), see the `better-stimulus` skill.
> This reference covers server-side ERB, Turbo Frames, Turbo Streams, and ActionCable.

## Partials

- Name after content, not usage (`_student.html.erb`, not `_student_row.html.erb`)
- Collection rendering for lists:

```erb
<%= render partial: "student", collection: @students %>
```

- Fragment caching when relevant:

```erb
<% cache student do %>
  <%= render student %>
<% end %>
```

## Forms

- Always `form_with` (never `form_for` or `form_tag`)
- Explicit labels for accessibility

## Helpers

- For reusable presentation logic only
- No business logic in helpers

## Turbo Frames

- For partial page loads and inline navigation
- `turbo_frame_tag` with a stable ID (`dom_id`)
- Lazy loading with `loading: :lazy`

```erb
<%= turbo_frame_tag dom_id(subject), src: subject_path(subject), loading: :lazy do %>
  <p>Chargement...</p>
<% end %>
```

## Turbo Streams

Controller responses for create/update/destroy:

```erb
<%= turbo_stream.prepend "questions" do %>
  <%= render @question %>
<% end %>
```

Broadcasts from models for real-time updates:

```ruby
after_create_commit { broadcast_prepend_to "questions" }
```

## ActionCable + Turbo Streams

For real-time streaming (e.g., AI tutoring, extraction notifications).

Subscribe in the view:

```erb
<%= turbo_stream_from "student_session_#{@session.id}" %>
```

Broadcast from job/service:

```ruby
Turbo::StreamsChannel.broadcast_append_to(
  "student_session_#{session.id}",
  target: "messages",
  partial: "conversations/message",
  locals: { message: chunk }
)
```

Bad:
```erb
<!-- Business logic in view -->
<% if @student.student_sessions.where(mode: :tutored).count > 3 %>
  <p>Limite atteinte</p>
<% end %>
```

Good:
```erb
<% if @student.tutor_limit_reached? %>
  <p>Limite atteinte</p>
<% end %>
```
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/views-hotwire.md && git commit -m "feat(skill): add views-hotwire reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 7: Create references/jobs.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/jobs.md`

- [ ] **Step 1: Write jobs.md**

```markdown
# Jobs — Sidekiq Conventions

This project uses Sidekiq directly, not ActiveJob.

## Standard Pattern

```ruby
class ExtractQuestionsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(subject_id)
    subject = Subject.find(subject_id)
    ExtractQuestionsFromPdf.call(subject:, pdf_content: extract_pdf(subject))
  end
end
```

## Idempotence — Mandatory

Jobs can be executed multiple times without side effects. Check state before acting:

```ruby
def perform(subject_id)
  subject = Subject.find(subject_id)
  return if subject.extraction_job&.done?
  # ...
end
```

## Retry & Errors

- `retry: 3` by default with exponential backoff (native Sidekiq)
- Fatal errors (bad data) → raise without retry expectations
- Transient errors (API timeout) → let Sidekiq retry

## Arguments

- Always pass IDs, never Ruby objects (Redis serialization)
- Keep arguments simple (scalars only)

## Queue Naming

- `default` — most jobs
- `critical` — time-sensitive jobs
- `low` — maintenance jobs

## Logging

- Log job start and completion
- Include relevant IDs for debugging
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/jobs.md && git commit -m "feat(skill): add jobs reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 8: Create references/tests.md

**Files:**
- Create: `~/.claude/skills/rails-conventions/references/tests.md`

- [ ] **Step 1: Write tests.md**

```markdown
# Tests — RSpec Conventions

Stack: RSpec + FactoryBot + Capybara

## Model Specs

```ruby
RSpec.describe Student, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).scoped_to(:classroom_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:classroom) }
    it { is_expected.to have_many(:student_sessions).dependent(:destroy) }
  end

  describe "#full_name" do
    let(:student) { build(:student, first_name: "Jean", last_name: "Dupont") }
    it { expect(student.full_name).to eq("Jean Dupont") }
  end
end
```

## Request Specs (Controllers)

```ruby
RSpec.describe "Students", type: :request do
  let(:classroom) { create(:classroom) }
  let(:teacher) { classroom.owner }

  before { sign_in teacher }

  describe "POST /classrooms/:id/students" do
    it "creates a student with generated credentials" do
      expect {
        post classroom_students_path(classroom),
          params: { student: { first_name: "Marie", last_name: "Curie" } }
      }.to change(Student, :count).by(1)
    end
  end
end
```

## Feature Specs (Capybara)

```ruby
RSpec.describe "Student login", type: :feature do
  let(:classroom) { create(:classroom, access_code: "term-sin-2026") }
  let(:student) { create(:student, classroom:) }

  it "allows student to log in via access code" do
    visit "/term-sin-2026"
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password"
    click_button "Se connecter"
    expect(page).to have_content("Bienvenue")
  end
end
```

## Factories

- Traits for variants, not duplicate factories
- Minimal data — only what validations require
- `build` over `create` when persistence isn't needed

```ruby
FactoryBot.define do
  factory :student do
    first_name { "Jean" }
    last_name { "Dupont" }
    password { "password" }
    classroom

    trait :with_api_key do
      api_key { "sk-test-123" }
      api_provider { :anthropic }
    end
  end
end
```

## Edge Cases — Always Test

- Nil / empty values
- Boundary conditions (points = 0, max score)
- Invalid inputs
- Authorization failures (student accessing another classroom)
- External API errors (timeout, 500, malformed response)

## VCR/WebMock for External API Calls

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
end

# In test
it "extracts questions from PDF" do
  VCR.use_cassette("anthropic_extraction") do
    result = ExtractQuestionsFromPdf.call(subject: subject, pdf_content: pdf)
    expect(result).to be_a(Subject)
  end
end
```

## Pattern: Arrange-Act-Assert

- Arrange: `let`, `before`, factories
- Act: one action per test
- Assert: clear, targeted expectations
```

- [ ] **Step 2: Commit**

Run: `cd ~/.claude && git add skills/rails-conventions/references/tests.md && git commit -m "feat(skill): add tests reference for rails-conventions"`

If `~/.claude` is not a git repo, skip this commit step.

---

### Task 9: Install better-stimulus (optional)

- [ ] **Step 1: Add the marketplace**

Run in Claude Code: `/plugin marketplace add obie/skills`

- [ ] **Step 2: Install the skill**

Run in Claude Code: `/plugin install better-stimulus@obie-skills`

- [ ] **Step 3: Verify**

Run: `/better-stimulus` in Claude Code. The skill content should load with Stimulus best practices.

---

### Task 10: End-to-end verification

- [ ] **Step 1: Verify skill file structure**

Run: `find ~/.claude/skills/rails-conventions -type f | sort`

Expected:
```
~/.claude/skills/rails-conventions/SKILL.md
~/.claude/skills/rails-conventions/references/controllers.md
~/.claude/skills/rails-conventions/references/jobs.md
~/.claude/skills/rails-conventions/references/models.md
~/.claude/skills/rails-conventions/references/services.md
~/.claude/skills/rails-conventions/references/tests.md
~/.claude/skills/rails-conventions/references/views-hotwire.md
```

- [ ] **Step 2: Verify MCP server responds**

In Claude Code, call the MCP `rails` server:
- `execute_tool("project_info")` — should return Rails version, project name
- `execute_tool("get_routes", params: { controller: "students" })` — should return student-related routes
- `execute_tool("analyze_models")` — should return model list with associations

- [ ] **Step 3: Verify skill activation**

Ask Claude Code: "Create a new service called ValidateExamSession that checks if a student session is still active." Claude Code should follow the conventions from the skill:
- `self.call` pattern
- Raise on failure
- Return domain object on success

Verify the generated code matches the conventions, then discard the test file.

- [ ] **Step 4: Commit .mcp.json if not already committed**

Run: `git status` — verify `.mcp.json` is tracked. If not:
```bash
git add .mcp.json
git commit -m "chore(mcp): add rails-mcp-server config for project introspection"
```

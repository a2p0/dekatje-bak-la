# Vague 1 — Schéma & suppression : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poser le schéma de données de la refonte tuteur, installer les 3 gems requises, supprimer l'ancien code tuteur, et maintenir la CI verte via xfeature-tagging des specs cassées.

**Architecture:** Conversation devient l'entité racine par (student, subject) avec AASM lifecycle. Les messages migrent dans une table dédiée. TutorState est un Data.define Ruby typé, sérialisé via custom ActiveRecord::Type.

**Tech Stack:** Rails 8, PostgreSQL, AASM gem, ruby_llm gem, rack-attack gem, RSpec

---

## Task 1 — Install gem `aasm`

**Files:**
- Modify: `Gemfile`
- Run: `bundle install`
- Commit: `chore(install): add aasm gem for Conversation lifecycle state machine`

### Steps

- [ ] Add to `Gemfile` after the `sidekiq` line:
  ```ruby
  gem "aasm"
  ```

- [ ] Run bundle:
  ```bash
  bundle install
  ```
  Expected output: `Bundle complete!` with `aasm` in the lock file.

- [ ] Verify it resolves:
  ```bash
  bundle exec ruby -e "require 'aasm'; puts AASM::VERSION"
  ```
  Expected: a version string like `5.5.0`.

- [ ] Commit:
  ```bash
  git add Gemfile Gemfile.lock
  git commit -m "chore(install): add aasm gem for Conversation lifecycle state machine"
  ```

---

## Task 2 — Install gem `ruby_llm`

**Files:**
- Modify: `Gemfile`
- Run: `bundle install`
- Commit: `chore(install): add ruby_llm gem for unified LLM client`

### Steps

- [ ] Add to `Gemfile` after `aasm`:
  ```ruby
  gem "ruby_llm"
  ```

- [ ] Run bundle:
  ```bash
  bundle install
  ```
  Expected output: `Bundle complete!` with `ruby_llm` in the lock file.

- [ ] Verify it resolves:
  ```bash
  bundle exec ruby -e "require 'ruby_llm'; puts RubyLLM::VERSION"
  ```
  Expected: a version string.

- [ ] Commit:
  ```bash
  git add Gemfile Gemfile.lock
  git commit -m "chore(install): add ruby_llm gem for unified LLM client"
  ```

---

## Task 3 — Install gem `rack-attack`

**Files:**
- Modify: `Gemfile`
- Run: `bundle install`
- Commit: `chore(install): add rack-attack gem for AI endpoint rate limiting`

### Steps

- [ ] Add to `Gemfile` after `ruby_llm`:
  ```ruby
  gem "rack-attack"
  ```

- [ ] Run bundle:
  ```bash
  bundle install
  ```
  Expected output: `Bundle complete!` with `rack-attack` in the lock file.

- [ ] Verify it resolves:
  ```bash
  bundle exec ruby -e "require 'rack/attack'; puts Rack::Attack::VERSION"
  ```
  Expected: a version string.

- [ ] Commit:
  ```bash
  git add Gemfile Gemfile.lock
  git commit -m "chore(install): add rack-attack gem for AI endpoint rate limiting"
  ```

---

## Task 4 — xfeature-tag all existing tutor specs

**Goal:** Keep CI green throughout the refactor by marking all tutor-related specs as pending with `xdescribe`. Do NOT delete any spec file.

**Files to modify** (change `RSpec.describe` → `RSpec.xdescribe` on the outermost describe block only):
- `spec/features/student_tutor_activation_spec.rb`
- `spec/features/student_tutor_chat_spec.rb`
- `spec/features/student_tutor_spotting_spec.rb`
- `spec/features/student_ai_tutoring_spec.rb`
- `spec/models/conversation_spec.rb`
- `spec/requests/student/conversations_spec.rb`
- `spec/requests/student/subjects/tutor_activations_spec.rb`
- `spec/requests/student/tutor_spec.rb`
- `spec/services/build_tutor_prompt_spec.rb`
- `spec/jobs/tutor_stream_job_spec.rb`
- `spec/channels/tutor_channel_spec.rb`
- `spec/helpers/student/tutor_helper_spec.rb`

### Steps

- [ ] In each file listed above, find the **first** `RSpec.describe` line and change it to `RSpec.xdescribe`. Leave all inner `describe` / `context` / `it` blocks untouched. Example:

  Before (`spec/features/student_tutor_activation_spec.rb`, line 3):
  ```ruby
  RSpec.describe "Student tutor activation banner", type: :feature do
  ```
  After:
  ```ruby
  RSpec.xdescribe "Student tutor activation banner", type: :feature do
  ```

  Before (`spec/models/conversation_spec.rb`, line 3):
  ```ruby
  RSpec.describe Conversation, type: :model do
  ```
  After:
  ```ruby
  RSpec.xdescribe Conversation, type: :model do
  ```

  Apply the same pattern to all 12 files.

- [ ] Verify no spec in those files will run (dry-run):
  ```bash
  bundle exec rspec \
    spec/features/student_tutor_activation_spec.rb \
    spec/features/student_tutor_chat_spec.rb \
    spec/features/student_tutor_spotting_spec.rb \
    spec/features/student_ai_tutoring_spec.rb \
    spec/models/conversation_spec.rb \
    spec/requests/student/conversations_spec.rb \
    spec/requests/student/subjects/tutor_activations_spec.rb \
    spec/requests/student/tutor_spec.rb \
    spec/services/build_tutor_prompt_spec.rb \
    spec/jobs/tutor_stream_job_spec.rb \
    spec/channels/tutor_channel_spec.rb \
    spec/helpers/student/tutor_helper_spec.rb \
    --dry-run 2>&1 | tail -5
  ```
  Expected: `0 examples, 0 failures, N pending` (all examples shown as pending/skipped).

- [ ] Run the full suite dry-run to confirm no other breakage:
  ```bash
  bundle exec rspec --dry-run 2>&1 | tail -5
  ```
  Expected: exit code 0, 0 failures.

- [ ] Commit all 12 files:
  ```bash
  git add \
    spec/features/student_tutor_activation_spec.rb \
    spec/features/student_tutor_chat_spec.rb \
    spec/features/student_tutor_spotting_spec.rb \
    spec/features/student_ai_tutoring_spec.rb \
    spec/models/conversation_spec.rb \
    spec/requests/student/conversations_spec.rb \
    spec/requests/student/subjects/tutor_activations_spec.rb \
    spec/requests/student/tutor_spec.rb \
    spec/services/build_tutor_prompt_spec.rb \
    spec/jobs/tutor_stream_job_spec.rb \
    spec/channels/tutor_channel_spec.rb \
    spec/helpers/student/tutor_helper_spec.rb
  git commit -m "test(tutor): xfeature-tag all tutor specs to keep CI green during refactor"
  ```

---

## Task 5 — Migration: modify `conversations` table

**Goal:** Transform `conversations` from a per-question chat log into the per-(student, subject) lifecycle container. Remove `messages` (JSONB array) and `streaming` columns, remove the `question_id` FK, add `subject_id` FK, add `lifecycle_state` string, add `tutor_state` JSONB.

**Files:**
- Create: `db/migrate/TIMESTAMP_refactor_conversations_for_tutor_redesign.rb`
- Modify: `db/schema.rb` (auto-updated by migrate)
- Commit: `refactor(migration): restructure conversations table for tutor redesign`

### Steps

- [ ] Generate the migration:
  ```bash
  bundle exec rails generate migration RefactorConversationsForTutorRedesign
  ```

- [ ] Open the generated file and replace its `change` method with:
  ```ruby
  def change
    # Remove old JSONB message store and streaming flag
    remove_column :conversations, :messages, :jsonb
    remove_column :conversations, :streaming, :boolean

    # Remove old per-question unique index before changing the FK
    remove_index :conversations, column: [:student_id, :question_id],
                 name: "index_conversations_on_student_id_and_question_id"

    # Change question_id from NOT NULL FK to nullable (conversations no longer
    # belong directly to a question — messages carry the question reference)
    change_column_null :conversations, :question_id, true

    # Add subject reference (the new root association)
    add_reference :conversations, :subject, null: false, foreign_key: true,
                  index: true

    # Add AASM lifecycle column
    add_column :conversations, :lifecycle_state, :string,
               null: false, default: "disabled"

    # Add typed TutorState column (JSONB, serialised by TutorStateType)
    add_column :conversations, :tutor_state, :jsonb, null: false, default: {}

    # New unique index: one conversation per (student, subject)
    add_index :conversations, [:student_id, :subject_id], unique: true,
              name: "index_conversations_on_student_id_and_subject_id"
  end
  ```

- [ ] Run the migration:
  ```bash
  bundle exec rails db:migrate
  ```
  Expected: `== RefactorConversationsForTutorRedesign: migrated` with no errors.

- [ ] Dump schema to verify:
  ```bash
  bundle exec rails db:schema:dump
  ```
  Then confirm `db/schema.rb` contains:
  - `t.string "lifecycle_state", default: "disabled", null: false`
  - `t.jsonb "tutor_state", default: {}, null: false`
  - `t.bigint "subject_id", null: false`
  - index on `["student_id", "subject_id"]` with `unique: true`
  - no `messages` column, no `streaming` column

- [ ] Commit:
  ```bash
  git add db/migrate/*_refactor_conversations_for_tutor_redesign.rb db/schema.rb
  git commit -m "refactor(migration): restructure conversations table for tutor redesign"
  ```

---

## Task 6 — Migration: create `messages` table

**Goal:** Create the new first-class `messages` table that stores individual chat messages with per-message token accounting and streaming metadata.

**Files:**
- Create: `db/migrate/TIMESTAMP_create_messages.rb`
- Modify: `db/schema.rb` (auto-updated)
- Commit: `feat(migration): create messages table for tutor chat`

### Steps

- [ ] Generate the migration:
  ```bash
  bundle exec rails generate migration CreateMessages
  ```

- [ ] Open the generated file and replace its `change` method with:
  ```ruby
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true, index: true
      t.integer    :role,         null: false                    # enum: user/assistant/system
      t.text       :content,      null: false
      t.bigint     :question_id,  null: true                     # nullable: context link
      t.integer    :tokens_in,    default: 0, null: false
      t.integer    :tokens_out,   default: 0, null: false
      t.integer    :chunk_index,  default: 0, null: false
      t.datetime   :streaming_finished_at
      t.timestamps
    end

    add_foreign_key :messages, :questions, column: :question_id
    add_index :messages, :question_id
  end
  ```

- [ ] Run the migration:
  ```bash
  bundle exec rails db:migrate
  ```
  Expected: `== CreateMessages: migrated` with no errors.

- [ ] Dump schema:
  ```bash
  bundle exec rails db:schema:dump
  ```
  Confirm `db/schema.rb` contains the `messages` table with all columns above.

- [ ] Commit:
  ```bash
  git add db/migrate/*_create_messages.rb db/schema.rb
  git commit -m "feat(migration): create messages table for tutor chat"
  ```

---

## Task 7 — Migration: add columns to `classrooms`, `users`, `students`

**Goal:** Add `tutor_free_mode_enabled` to classrooms (teacher controls whether students can use tutor without personal API key), `openrouter_api_key` to users (teacher key for free mode), and `use_personal_key` to students.

**Files:**
- Create: `db/migrate/TIMESTAMP_add_tutor_columns_to_classrooms_users_students.rb`
- Modify: `db/schema.rb` (auto-updated)
- Commit: `feat(migration): add tutor free-mode columns to classrooms, users, students`

### Steps

- [ ] Generate the migration:
  ```bash
  bundle exec rails generate migration AddTutorColumnsToClassroomsUsersStudents
  ```

- [ ] Open the generated file and replace its `change` method with:
  ```ruby
  def change
    # Classroom: allow teacher to enable key-free tutor mode for their class
    add_column :classrooms, :tutor_free_mode_enabled, :boolean,
               default: false, null: false

    # User: OpenRouter key used when tutor_free_mode_enabled on one of their classrooms.
    # Encrypted via `encrypts :openrouter_api_key` in the User model (Rails native encryption
    # stores ciphertext in the same column — matches the existing `api_key` pattern).
    add_column :users, :openrouter_api_key, :string

    # Student: whether this student uses their own API key (true) or the classroom
    # free-mode key provided by the teacher (false).
    add_column :students, :use_personal_key, :boolean,
               default: true, null: false
  end
  ```

- [ ] Run the migration:
  ```bash
  bundle exec rails db:migrate
  ```
  Expected: `== AddTutorColumnsToClassroomsUsersStudents: migrated` with no errors.

- [ ] Dump schema:
  ```bash
  bundle exec rails db:schema:dump
  ```
  Confirm `db/schema.rb` contains:
  - `t.boolean "tutor_free_mode_enabled", default: false, null: false` in classrooms
  - `t.string "openrouter_api_key"` in users
  - `t.boolean "use_personal_key", default: true, null: false` in students

- [ ] Commit:
  ```bash
  git add db/migrate/*_add_tutor_columns_to_classrooms_users_students.rb db/schema.rb
  git commit -m "feat(migration): add tutor free-mode columns to classrooms, users, students"
  ```

---

## Task 8 — Migration: remove `tutor_state` from `student_sessions`

**Goal:** The `tutor_state` JSONB column moves from `student_sessions` to `conversations`. Remove it from `student_sessions` once the column exists on `conversations` (Task 5 already added it there).

**Files:**
- Create: `db/migrate/TIMESTAMP_remove_tutor_state_from_student_sessions.rb`
- Modify: `db/schema.rb` (auto-updated)
- Commit: `refactor(migration): remove tutor_state from student_sessions (moved to conversations)`

### Steps

- [ ] Generate the migration:
  ```bash
  bundle exec rails generate migration RemoveTutorStateFromStudentSessions
  ```

- [ ] Open the generated file and replace its `change` method with:
  ```ruby
  def change
    remove_column :student_sessions, :tutor_state, :jsonb
  end
  ```

- [ ] Run the migration:
  ```bash
  bundle exec rails db:migrate
  ```
  Expected: `== RemoveTutorStateFromStudentSessions: migrated` with no errors.

- [ ] Dump schema:
  ```bash
  bundle exec rails db:schema:dump
  ```
  Confirm `db/schema.rb` no longer contains `tutor_state` in the `student_sessions` table.

- [ ] Commit:
  ```bash
  git add db/migrate/*_remove_tutor_state_from_student_sessions.rb db/schema.rb
  git commit -m "refactor(migration): remove tutor_state from student_sessions (moved to conversations)"
  ```

---

## Task 9 — Create `TutorState` + `QuestionState` Data classes + `TutorStateType`

**Goal:** Replace the ad-hoc JSONB hash with a typed Ruby Data class hierarchy. Add a custom `ActiveRecord::Type::Value` so Rails serializes/deserializes automatically.

**Files:**
- Create: `app/models/tutor_state.rb`
- Create: `app/models/types/tutor_state_type.rb`
- Create (test first): `spec/models/tutor_state_spec.rb`

### Steps

#### 9a — Write the spec first (TDD)

- [ ] Create `spec/models/tutor_state_spec.rb`:
  ```ruby
  # spec/models/tutor_state_spec.rb
  require "rails_helper"

  RSpec.describe TutorState do
    describe ".default" do
      subject(:state) { described_class.default }

      it "returns a TutorState instance" do
        expect(state).to be_a(TutorState)
      end

      it "has current_phase = 'idle'" do
        expect(state.current_phase).to eq("idle")
      end

      it "has nil current_question_id" do
        expect(state.current_question_id).to be_nil
      end

      it "has empty concepts_mastered array" do
        expect(state.concepts_mastered).to eq([])
      end

      it "has empty concepts_to_revise array" do
        expect(state.concepts_to_revise).to eq([])
      end

      it "has discouragement_level = 0" do
        expect(state.discouragement_level).to eq(0)
      end

      it "has empty question_states hash" do
        expect(state.question_states).to eq({})
      end
    end

    describe "immutability" do
      it "is frozen (Data classes are value objects)" do
        expect(described_class.default).to be_frozen
      end

      it "raises when trying to modify question_states in place" do
        state = described_class.default
        expect { state.question_states["42"] = {} }.to raise_error(FrozenError)
      end
    end
  end

  RSpec.describe QuestionState do
    describe "construction" do
      subject(:qs) do
        QuestionState.new(
          step: 1,
          hints_used: 2,
          last_confidence: 4,
          error_types: ["calcul"],
          completed_at: nil
        )
      end

      it "stores step" do
        expect(qs.step).to eq(1)
      end

      it "stores hints_used" do
        expect(qs.hints_used).to eq(2)
      end

      it "stores last_confidence" do
        expect(qs.last_confidence).to eq(4)
      end

      it "stores error_types" do
        expect(qs.error_types).to eq(["calcul"])
      end
    end
  end
  ```

- [ ] Run it to confirm red:
  ```bash
  bundle exec rspec spec/models/tutor_state_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: failures because `TutorState` and `QuestionState` are not defined yet.

#### 9b — Create the Data classes

- [ ] Create `app/models/tutor_state.rb`:
  ```ruby
  # app/models/tutor_state.rb

  QuestionState = Data.define(
    :step,             # Integer — current tutoring step for this question
    :hints_used,       # Integer 0-5
    :last_confidence,  # Integer 1-5, or nil
    :error_types,      # Array<String>
    :completed_at      # String ISO8601 or nil
  )

  TutorState = Data.define(
    :current_phase,        # String — e.g. "idle", "spotting", "chat"
    :current_question_id,  # Integer or nil
    :concepts_mastered,    # Array<String>
    :concepts_to_revise,   # Array<String>
    :discouragement_level, # Integer 0-3
    :question_states       # Hash<String, QuestionState>
  ) do
    def self.default
      new(
        current_phase:        "idle",
        current_question_id:  nil,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {}
      )
    end
  end
  ```

- [ ] Run spec to confirm green:
  ```bash
  bundle exec rspec spec/models/tutor_state_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: all examples pass, 0 failures.

#### 9c — Write spec for TutorStateType (TDD)

- [ ] Create `spec/models/types/tutor_state_type_spec.rb`:
  ```ruby
  # spec/models/types/tutor_state_type_spec.rb
  require "rails_helper"

  RSpec.describe TutorStateType do
    subject(:type) { described_class.new }

    describe "#cast" do
      context "when given nil" do
        it "returns TutorState.default" do
          result = type.cast(nil)
          expect(result).to eq(TutorState.default)
        end
      end

      context "when given a TutorState instance" do
        it "returns it unchanged" do
          state = TutorState.default
          expect(type.cast(state)).to be(state)
        end
      end

      context "when given a Hash" do
        it "builds a TutorState from the hash" do
          hash = {
            "current_phase"        => "chat",
            "current_question_id"  => 42,
            "concepts_mastered"    => ["énergie"],
            "concepts_to_revise"   => [],
            "discouragement_level" => 1,
            "question_states"      => {}
          }
          result = type.cast(hash)
          expect(result).to be_a(TutorState)
          expect(result.current_phase).to eq("chat")
          expect(result.current_question_id).to eq(42)
          expect(result.concepts_mastered).to eq(["énergie"])
          expect(result.discouragement_level).to eq(1)
        end

        it "builds nested QuestionState objects from question_states hash" do
          hash = {
            "current_phase"        => "chat",
            "current_question_id"  => 1,
            "concepts_mastered"    => [],
            "concepts_to_revise"   => [],
            "discouragement_level" => 0,
            "question_states"      => {
              "1" => {
                "step" => 2, "hints_used" => 1,
                "last_confidence" => 3, "error_types" => [], "completed_at" => nil
              }
            }
          }
          result = type.cast(hash)
          qs = result.question_states["1"]
          expect(qs).to be_a(QuestionState)
          expect(qs.step).to eq(2)
          expect(qs.hints_used).to eq(1)
        end
      end
    end

    describe "#serialize" do
      it "converts TutorState to a plain Hash" do
        state = TutorState.default
        result = type.serialize(state)
        expect(result).to be_a(Hash)
        expect(result["current_phase"]).to eq("idle")
        expect(result["question_states"]).to eq({})
      end

      it "converts nested QuestionState to a hash" do
        qs = QuestionState.new(
          step: 1, hints_used: 0, last_confidence: nil,
          error_types: [], completed_at: nil
        )
        state = TutorState.new(
          current_phase: "chat", current_question_id: 5,
          concepts_mastered: [], concepts_to_revise: [],
          discouragement_level: 0,
          question_states: { "5" => qs }
        )
        result = type.serialize(state)
        expect(result["question_states"]["5"]).to be_a(Hash)
        expect(result["question_states"]["5"]["step"]).to eq(1)
      end
    end

    describe "#deserialize" do
      it "parses a JSON string and casts to TutorState" do
        json = TutorState.default.then { |s| type.serialize(s).to_json }
        result = type.deserialize(json)
        expect(result).to be_a(TutorState)
        expect(result.current_phase).to eq("idle")
      end
    end
  end
  ```

- [ ] Run it to confirm red:
  ```bash
  bundle exec rspec spec/models/types/tutor_state_type_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: failures because `TutorStateType` is not defined yet.

#### 9d — Create TutorStateType

- [ ] Create directory and file `app/models/types/tutor_state_type.rb`:
  ```ruby
  # app/models/types/tutor_state_type.rb
  class TutorStateType < ActiveRecord::Type::Value
    def cast(value)
      case value
      when TutorState
        value
      when Hash
        cast_from_hash(value)
      when NilClass
        TutorState.default
      else
        TutorState.default
      end
    end

    def serialize(value)
      return {} if value.nil?

      tutor_state = cast(value)
      {
        "current_phase"        => tutor_state.current_phase,
        "current_question_id"  => tutor_state.current_question_id,
        "concepts_mastered"    => tutor_state.concepts_mastered,
        "concepts_to_revise"   => tutor_state.concepts_to_revise,
        "discouragement_level" => tutor_state.discouragement_level,
        "question_states"      => serialize_question_states(tutor_state.question_states)
      }
    end

    def deserialize(value)
      return TutorState.default if value.nil?

      parsed = value.is_a?(String) ? JSON.parse(value) : value
      cast(parsed)
    end

    private

    def cast_from_hash(hash)
      raw_states = hash["question_states"] || {}
      question_states = raw_states.transform_values do |qs_hash|
        next qs_hash if qs_hash.is_a?(QuestionState)

        QuestionState.new(
          step:             qs_hash["step"],
          hints_used:       qs_hash["hints_used"] || 0,
          last_confidence:  qs_hash["last_confidence"],
          error_types:      Array(qs_hash["error_types"]),
          completed_at:     qs_hash["completed_at"]
        )
      end

      TutorState.new(
        current_phase:        hash["current_phase"] || "idle",
        current_question_id:  hash["current_question_id"],
        concepts_mastered:    Array(hash["concepts_mastered"]),
        concepts_to_revise:   Array(hash["concepts_to_revise"]),
        discouragement_level: hash["discouragement_level"] || 0,
        question_states:      question_states
      )
    end

    def serialize_question_states(question_states)
      question_states.transform_values do |qs|
        {
          "step"            => qs.step,
          "hints_used"      => qs.hints_used,
          "last_confidence" => qs.last_confidence,
          "error_types"     => qs.error_types,
          "completed_at"    => qs.completed_at
        }
      end
    end
  end
  ```

- [ ] Run the type spec to confirm green:
  ```bash
  bundle exec rspec spec/models/types/tutor_state_type_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: all examples pass, 0 failures.

- [ ] Run TutorState spec too:
  ```bash
  bundle exec rspec spec/models/tutor_state_spec.rb --format documentation 2>&1 | tail -5
  ```
  Expected: still green.

- [ ] Commit:
  ```bash
  git add \
    app/models/tutor_state.rb \
    app/models/types/tutor_state_type.rb \
    spec/models/tutor_state_spec.rb \
    spec/models/types/tutor_state_type_spec.rb
  git commit -m "feat(tutor): add TutorState + QuestionState Data classes and TutorStateType AR type"
  ```

---

## Task 10 — Update `Conversation` model (AASM + new associations + TutorStateType)

**Goal:** Rewrite `Conversation` to reflect the new schema: belongs to subject (not question), has many messages, uses AASM for lifecycle, and uses the typed TutorStateType.

**Files:**
- Modify: `app/models/conversation.rb`
- Modify: `app/models/user.rb` (add `encrypts :openrouter_api_key`)
- Modify: `app/models/classroom.rb` (add `tutor_free_mode_enabled` accessor mention)
- Create (test first): `spec/models/conversation_aasm_spec.rb`

### Steps

#### 10a — Write the AASM spec first (TDD)

- [ ] Create `spec/models/conversation_aasm_spec.rb`:
  ```ruby
  # spec/models/conversation_aasm_spec.rb
  require "rails_helper"

  RSpec.describe Conversation, type: :model do
    let(:classroom) { create(:classroom) }
    let(:student)   { create(:student, classroom: classroom) }
    let(:subject_record) { create(:subject, status: :published) }

    describe "associations" do
      it { is_expected.to belong_to(:student) }
      it { is_expected.to belong_to(:subject) }
      it { is_expected.to have_many(:messages).dependent(:destroy) }
    end

    describe "AASM lifecycle" do
      subject(:conversation) do
        create(:conversation, student: student, subject: subject_record)
      end

      it "starts in the disabled state" do
        expect(conversation.lifecycle_state).to eq("disabled")
        expect(conversation).to be_disabled
      end

      context "when student has a personal API key" do
        before { student.update!(api_key: "sk-test-key", api_provider: :anthropic) }

        it "transitions to active via activate!" do
          expect { conversation.activate! }.to change {
            conversation.lifecycle_state
          }.from("disabled").to("active")
        end
      end

      context "when classroom has free mode enabled" do
        before { classroom.update!(tutor_free_mode_enabled: true) }

        it "allows activation without a student API key" do
          student.update!(api_key: nil)
          expect { conversation.activate! }.to change {
            conversation.lifecycle_state
          }.from("disabled").to("active")
        end
      end

      context "when student has no key and free mode is disabled" do
        before do
          student.update!(api_key: nil)
          classroom.update!(tutor_free_mode_enabled: false)
        end

        it "raises AASM::InvalidTransition on activate!" do
          expect { conversation.activate! }.to raise_error(AASM::InvalidTransition)
        end
      end

      context "when conversation is active" do
        before do
          student.update!(api_key: "sk-test-key", api_provider: :anthropic)
          conversation.activate!
        end

        it "transitions to ended via end_chat!" do
          expect { conversation.end_chat! }.to change {
            conversation.lifecycle_state
          }.from("active").to("ended")
        end
      end
    end

    describe "tutor_state attribute" do
      subject(:conversation) do
        create(:conversation, student: student, subject: subject_record)
      end

      it "returns a TutorState instance" do
        expect(conversation.tutor_state).to be_a(TutorState)
      end

      it "defaults to TutorState.default" do
        expect(conversation.tutor_state).to eq(TutorState.default)
      end

      it "persists a modified TutorState" do
        new_state = TutorState.new(
          current_phase:        "chat",
          current_question_id:  nil,
          concepts_mastered:    ["énergie"],
          concepts_to_revise:   [],
          discouragement_level: 0,
          question_states:      {}
        )
        conversation.update!(tutor_state: new_state)
        conversation.reload
        expect(conversation.tutor_state.current_phase).to eq("chat")
        expect(conversation.tutor_state.concepts_mastered).to eq(["énergie"])
      end
    end
  end
  ```

- [ ] Run it to confirm red:
  ```bash
  bundle exec rspec spec/models/conversation_aasm_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: failures (Conversation still has old associations).

#### 10b — Rewrite the Conversation model

- [ ] Rewrite `app/models/conversation.rb`:
  ```ruby
  # app/models/conversation.rb
  class Conversation < ApplicationRecord
    include AASM

    belongs_to :student
    belongs_to :subject
    has_many :messages, dependent: :destroy

    attribute :tutor_state, TutorStateType.new

    aasm column: :lifecycle_state do
      state :disabled, initial: true
      state :active
      state :ended

      event :activate do
        transitions from: :disabled, to: :active,
                    guard: :student_has_api_key_or_free_mode?
      end

      event :end_chat do
        transitions from: :active, to: :ended
      end
    end

    private

    def student_has_api_key_or_free_mode?
      student.api_key.present? ||
        student.classroom.tutor_free_mode_enabled?
    end
  end
  ```

#### 10c — Add `encrypts :openrouter_api_key` to User

- [ ] Edit `app/models/user.rb`, add the new encrypted attribute after the existing `encrypts :api_key` line:
  ```ruby
  encrypts :api_key
  encrypts :openrouter_api_key
  ```

- [ ] Run the Conversation AASM spec to confirm green:
  ```bash
  bundle exec rspec spec/models/conversation_aasm_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected: all examples pass, 0 failures.

- [ ] Commit:
  ```bash
  git add \
    app/models/conversation.rb \
    app/models/user.rb \
    spec/models/conversation_aasm_spec.rb
  git commit -m "feat(tutor): rewrite Conversation model with AASM lifecycle and TutorStateType"
  ```

---

## Task 11 — Create `Message` model + factory

**Goal:** Create the `Message` ActiveRecord model and its FactoryBot factory.

**Files:**
- Create (test first): `spec/models/message_spec.rb`
- Create: `app/models/message.rb`
- Create: `spec/factories/messages.rb`

### Steps

#### 11a — Write the spec first (TDD)

- [ ] Create `spec/models/message_spec.rb`:
  ```ruby
  # spec/models/message_spec.rb
  require "rails_helper"

  RSpec.describe Message, type: :model do
    describe "associations" do
      it { is_expected.to belong_to(:conversation) }
      it { is_expected.to belong_to(:question).optional }
    end

    describe "validations" do
      it { is_expected.to validate_presence_of(:content) }
    end

    describe "enums" do
      it { is_expected.to define_enum_for(:role).with_values(user: 0, assistant: 1, system: 2) }
    end

    describe "factory" do
      it "creates a valid message" do
        message = build(:message)
        expect(message).to be_valid
      end

      it "defaults to user role" do
        message = build(:message)
        expect(message.role).to eq("user")
      end

      it "creates a message with assistant role" do
        message = build(:message, role: :assistant)
        expect(message.role).to eq("assistant")
      end

      it "creates a message linked to a question" do
        question = create(:question)
        message  = create(:message, question: question)
        expect(message.question).to eq(question)
      end
    end

    describe "chunk_index default" do
      it "defaults to 0" do
        message = create(:message)
        expect(message.chunk_index).to eq(0)
      end
    end
  end
  ```

- [ ] Run it to confirm red:
  ```bash
  bundle exec rspec spec/models/message_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: failures because `Message` model does not exist yet.

#### 11b — Create the Message model

- [ ] Create `app/models/message.rb`:
  ```ruby
  # app/models/message.rb
  class Message < ApplicationRecord
    belongs_to :conversation
    belongs_to :question, optional: true

    enum :role, { user: 0, assistant: 1, system: 2 }

    validates :content, presence: true
  end
  ```

#### 11c — Create the factory

- [ ] Create `spec/factories/messages.rb`:
  ```ruby
  # spec/factories/messages.rb
  FactoryBot.define do
    factory :message do
      association :conversation
      role        { :user }
      content     { "Test message" }
      chunk_index { 0 }
    end
  end
  ```

- [ ] Run the spec to confirm green:
  ```bash
  bundle exec rspec spec/models/message_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: all examples pass, 0 failures.

- [ ] Commit:
  ```bash
  git add \
    app/models/message.rb \
    spec/models/message_spec.rb \
    spec/factories/messages.rb
  git commit -m "feat(tutor): add Message model and factory"
  ```

---

## Task 12 — Remove tutor methods from `StudentSession`

**Goal:** Delete the 6 tutor-state helper methods from `StudentSession`. They relied on the `tutor_state` JSONB column that no longer exists on `student_sessions` (removed in Task 8).

**Files:**
- Modify: `app/models/student_session.rb`
- Modify: `spec/models/student_session_spec.rb` (remove or xdescribe any examples for these methods — use `xdescribe` to mark them rather than delete)

### Steps

- [ ] In `app/models/student_session.rb`, remove the entire `# Tutor state helpers` section (lines 92–125 in the current file):
  - `question_step`
  - `set_question_step!`
  - `store_spotting!`
  - `spotting_data`
  - `spotting_completed?`
  - `tutored_active?`

  The section to remove in full:
  ```ruby
  # Tutor state helpers

  def question_step(question_id)
    tutor_state.dig("question_states", question_id.to_s, "step")
  end

  def set_question_step!(question_id, step)
    key = question_id.to_s
    states = tutor_state["question_states"] ||= {}
    states[key] ||= {}
    states[key]["step"] = step
    update!(tutor_state: tutor_state)
  end

  def store_spotting!(question_id, data)
    key = question_id.to_s
    states = tutor_state["question_states"] ||= {}
    states[key] ||= {}
    states[key]["spotting"] = data
    update!(tutor_state: tutor_state)
  end

  def spotting_data(question_id)
    tutor_state.dig("question_states", question_id.to_s, "spotting")
  end

  def spotting_completed?(question_id)
    %w[feedback skipped].include?(question_step(question_id))
  end

  def tutored_active?
    return false unless tutored?
    tutor_state.dig("question_states").present?
  end
  ```

- [ ] Check `spec/models/student_session_spec.rb` for any examples that test these methods and wrap them in `xdescribe "tutor state helpers (removed in vague1)" do ... end` to preserve them without breaking CI.

- [ ] Run the student_session spec to confirm no failures from the deletion:
  ```bash
  bundle exec rspec spec/models/student_session_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected: all remaining (non-xdescribed) examples pass.

- [ ] Commit:
  ```bash
  git add app/models/student_session.rb spec/models/student_session_spec.rb
  git commit -m "refactor(student-session): remove tutor_state helper methods (moved to Conversation)"
  ```

---

## Task 13 — Delete old tutor files

**Goal:** Remove all code that belonged to the old tutor system. This is a clean deletion step — no new code is added here.

**Files to delete:**

| File | Type |
|---|---|
| `app/services/build_tutor_prompt.rb` | Service |
| `app/services/ai_client_factory.rb` | Service |
| `app/jobs/tutor_stream_job.rb` | Job |
| `app/channels/tutor_channel.rb` | Channel |
| `app/controllers/student/tutor_controller.rb` | Controller |
| `app/controllers/student/subjects/tutor_activations_controller.rb` | Controller |
| `app/helpers/student/tutor_helper.rb` | Helper |
| `app/views/student/tutor/` | View directory (entire) |
| `app/views/student/questions/_chat_drawer.html.erb` | View partial |
| `app/javascript/controllers/chat_controller.js` | Stimulus controller |
| `app/javascript/controllers/spotting_controller.js` | Stimulus controller |

**Routes to remove from `config/routes.rb`:**
- The `subject_tutor_activation` resource (tutor_activations controller)
- The `scope "/subjects/:subject_id/questions/:question_id/tutor"` block (verify_spotting / skip_spotting)

### Steps

- [ ] Delete files:
  ```bash
  rm app/services/build_tutor_prompt.rb
  rm app/services/ai_client_factory.rb
  rm app/jobs/tutor_stream_job.rb
  rm app/channels/tutor_channel.rb
  rm app/controllers/student/tutor_controller.rb
  rm app/controllers/student/subjects/tutor_activations_controller.rb
  rm app/helpers/student/tutor_helper.rb
  rm -r app/views/student/tutor/
  rm app/views/student/questions/_chat_drawer.html.erb
  rm app/javascript/controllers/chat_controller.js
  rm app/javascript/controllers/spotting_controller.js
  ```

- [ ] Remove from `config/routes.rb` the following two blocks:
  ```ruby
  resource :subject_tutor_activation, only: [ :create ], path: "subjects/:subject_id/tutor_activation",
    controller: "student/subjects/tutor_activations"
  ```
  and:
  ```ruby
  scope "/subjects/:subject_id/questions/:question_id/tutor", as: :tutor_question do
    post :verify_spotting, to: "student/tutor#verify_spotting"
    post :skip_spotting,   to: "student/tutor#skip_spotting"
  end
  ```

- [ ] Verify routes file is syntactically valid:
  ```bash
  bundle exec rails routes 2>&1 | tail -5
  ```
  Expected: no Ruby syntax errors, routes load successfully.

- [ ] Boot the app briefly to detect any missing constant errors from the deletions:
  ```bash
  bundle exec rails runner "puts 'boot ok'" 2>&1
  ```
  Expected: `boot ok` with no `NameError` / `LoadError`.

- [ ] Commit all deletions and route changes:
  ```bash
  git add -u
  git commit -m "refactor(tutor): delete old tutor services, job, channel, controllers, views, and JS"
  ```

---

## Task 14 — Update factories + write model specs for TutorState, Conversation AASM, Message

**Goal:** Update the `conversations` factory to match the new schema (subject instead of question, lifecycle_state, tutor_state). The model specs for TutorState, Conversation, and Message were already written in Tasks 9, 10, and 11. This task only updates the factory and runs the full suite.

**Files:**
- Modify: `spec/factories/conversations.rb`

### Steps

- [ ] Rewrite `spec/factories/conversations.rb`:
  ```ruby
  # spec/factories/conversations.rb
  FactoryBot.define do
    factory :conversation do
      association :student
      association :subject
      lifecycle_state { "disabled" }
      tutor_state     { TutorState.default }
    end
  end
  ```

- [ ] Run the three new model specs together to confirm all green:
  ```bash
  bundle exec rspec \
    spec/models/tutor_state_spec.rb \
    spec/models/types/tutor_state_type_spec.rb \
    spec/models/conversation_aasm_spec.rb \
    spec/models/message_spec.rb \
    --format documentation 2>&1 | tail -15
  ```
  Expected: 0 failures.

- [ ] Run the full RSpec suite to confirm CI-equivalent state:
  ```bash
  bundle exec rspec --format progress 2>&1 | tail -10
  ```
  Expected: 0 failures, 0 errors. Pending count from xdescribed blocks is acceptable.

- [ ] Commit:
  ```bash
  git add spec/factories/conversations.rb
  git commit -m "test(factories): update conversations factory for new tutor schema"
  ```

---

## Final CI check

- [ ] Run the complete suite one last time and confirm:
  ```bash
  bundle exec rspec 2>&1 | tail -5
  ```
  Expected output form: `N examples, 0 failures, M pending`
  - 0 failures, 0 errors
  - Pending examples are exclusively the xdescribed tutor specs (acceptable)

- [ ] Confirm `db/schema.rb` is committed and up to date:
  ```bash
  git status db/schema.rb
  ```
  Expected: `nothing to commit` (schema was committed with each migration task).

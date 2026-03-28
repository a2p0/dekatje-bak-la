# Extraction Pipeline — Plan A: Migrations, Modèles, Configuration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Créer les modèles Part, Question, Answer et configurer Sidekiq + ActionCable Redis pour le pipeline d'extraction.

**Architecture:** Trois migrations (parts, questions, answers) avec modèles TDD. Configuration Sidekiq comme queue adapter ActiveJob, ActionCable Redis pour les Turbo Streams temps réel.

**Tech Stack:** Rails 8.1, Sidekiq, Redis, RSpec + FactoryBot

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_create_parts.rb` | Créer | Table parts |
| `db/migrate/TIMESTAMP_create_questions.rb` | Créer | Table questions |
| `db/migrate/TIMESTAMP_create_answers.rb` | Créer | Table answers |
| `app/models/part.rb` | Créer | Modèle Part + enums |
| `app/models/question.rb` | Créer | Modèle Question + enums + soft delete |
| `app/models/answer.rb` | Créer | Modèle Answer + jsonb |
| `app/models/subject.rb` | Modifier | Ajouter has_many :parts |
| `config/sidekiq.yml` | Créer | Queues default + extraction |
| `config/application.rb` | Modifier | queue_adapter = :sidekiq |
| `config/cable.yml` | Modifier | Redis adapter |
| `spec/factories/parts.rb` | Créer | Factory Part |
| `spec/factories/questions.rb` | Créer | Factory Question |
| `spec/factories/answers.rb` | Créer | Factory Answer |
| `spec/models/part_spec.rb` | Créer | Tests Part |
| `spec/models/question_spec.rb` | Créer | Tests Question |
| `spec/models/answer_spec.rb` | Créer | Tests Answer |

---

## Task 1 : Migration parts

**Files:**
- Create: `db/migrate/TIMESTAMP_create_parts.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateParts number:integer title:string objective_text:text section_type:integer position:integer subject:references
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts do |t|
      t.integer    :number,        null: false
      t.string     :title,         null: false
      t.text       :objective_text
      t.integer    :section_type,  null: false, default: 0
      t.integer    :position,      null: false, default: 0
      t.references :subject,       null: false, foreign_key: true
      t.timestamps
    end

    add_index :parts, [ :subject_id, :position ]
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateParts: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(extraction): create parts migration

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Migration questions

**Files:**
- Create: `db/migrate/TIMESTAMP_create_questions.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateQuestions number:string label:text context_text:text points:decimal answer_type:integer position:integer status:integer discarded_at:datetime part:references
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.string     :number,       null: false
      t.text       :label,        null: false
      t.text       :context_text
      t.decimal    :points
      t.integer    :answer_type,  null: false, default: 0
      t.integer    :position,     null: false, default: 0
      t.integer    :status,       null: false, default: 0
      t.datetime   :discarded_at
      t.references :part,         null: false, foreign_key: true
      t.timestamps
    end

    add_index :questions, :discarded_at
    add_index :questions, [ :part_id, :position ]
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateQuestions: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(extraction): create questions migration with soft delete

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Migration answers

**Files:**
- Create: `db/migrate/TIMESTAMP_create_answers.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateAnswers correction_text:text explanation_text:text key_concepts:jsonb data_hints:jsonb question:references
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class CreateAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :answers do |t|
      t.text       :correction_text
      t.text       :explanation_text
      t.jsonb      :key_concepts, default: []
      t.jsonb      :data_hints,   default: []
      t.references :question,     null: false, foreign_key: true
      t.timestamps
    end
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateAnswers: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(extraction): create answers migration with jsonb fields

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Modèle Part (TDD)

**Files:**
- Create: `spec/factories/parts.rb`
- Create: `spec/models/part_spec.rb`
- Create: `app/models/part.rb`
- Modify: `app/models/subject.rb`

- [ ] **Step 1 : Créer la factory**

```ruby
# spec/factories/parts.rb
FactoryBot.define do
  factory :part do
    number       { 1 }
    title        { "Partie #{Faker::Number.number(digits: 1)}" }
    objective_text { "Comparer les modes de transport" }
    section_type { :common }
    position     { 1 }
    association  :subject
  end
end
```

- [ ] **Step 2 : Écrire les tests**

```ruby
# spec/models/part_spec.rb
require "rails_helper"

RSpec.describe Part, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      part = build(:part)
      expect(part).to be_valid
    end

    it "requires number" do
      part = build(:part, number: nil)
      expect(part).not_to be_valid
    end

    it "requires title" do
      part = build(:part, title: nil)
      expect(part).not_to be_valid
    end
  end

  describe "enums" do
    it "defines section_type enum" do
      expect(Part.section_types).to eq("common" => 0, "specific" => 1)
    end
  end

  describe "associations" do
    it "belongs to subject" do
      part = build(:part)
      expect(part.subject).to be_a(Subject)
    end

    it "has many questions" do
      part = create(:part)
      expect(part).to respond_to(:questions)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/part_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Part`

- [ ] **Step 4 : Créer le modèle Part**

```ruby
# app/models/part.rb
class Part < ApplicationRecord
  belongs_to :subject
  has_many :questions, dependent: :destroy

  enum :section_type, { common: 0, specific: 1 }

  validates :number, :title, presence: true
end
```

- [ ] **Step 5 : Ajouter has_many :parts à Subject**

Lire `app/models/subject.rb` et ajouter après `has_one :extraction_job, dependent: :destroy` :

```ruby
has_many :parts, dependent: :destroy
```

- [ ] **Step 6 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/part_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 7 : Commit**

```bash
git add app/models/part.rb app/models/subject.rb spec/models/part_spec.rb spec/factories/parts.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add Part model with section_type enum

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Modèle Question (TDD)

**Files:**
- Create: `spec/factories/questions.rb`
- Create: `spec/models/question_spec.rb`
- Create: `app/models/question.rb`

- [ ] **Step 1 : Créer la factory**

```ruby
# spec/factories/questions.rb
FactoryBot.define do
  factory :question do
    number      { "1.1" }
    label       { "Calculer la consommation en litres pour 186 km." }
    points      { 2.0 }
    answer_type { :calculation }
    position    { 1 }
    status      { :draft }
    association :part
  end
end
```

- [ ] **Step 2 : Écrire les tests**

```ruby
# spec/models/question_spec.rb
require "rails_helper"

RSpec.describe Question, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      question = build(:question)
      expect(question).to be_valid
    end

    it "requires number" do
      question = build(:question, number: nil)
      expect(question).not_to be_valid
    end

    it "requires label" do
      question = build(:question, label: nil)
      expect(question).not_to be_valid
    end
  end

  describe "enums" do
    it "defines answer_type enum" do
      expect(Question.answer_types).to eq(
        "text" => 0, "calculation" => 1, "argumentation" => 2,
        "dr_reference" => 3, "completion" => 4, "choice" => 5
      )
    end

    it "defines status enum with draft as default" do
      question = build(:question)
      expect(question.status).to eq("draft")
    end
  end

  describe "scopes" do
    it "kept excludes soft-deleted questions" do
      kept = create(:question)
      deleted = create(:question, discarded_at: Time.current)
      expect(Question.kept).to include(kept)
      expect(Question.kept).not_to include(deleted)
    end
  end

  describe "associations" do
    it "belongs to part" do
      question = build(:question)
      expect(question.part).to be_a(Part)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/question_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Question`

- [ ] **Step 4 : Créer le modèle Question**

```ruby
# app/models/question.rb
class Question < ApplicationRecord
  belongs_to :part
  has_one :answer, dependent: :destroy

  enum :answer_type, {
    text: 0, calculation: 1, argumentation: 2,
    dr_reference: 3, completion: 4, choice: 5
  }
  enum :status, { draft: 0, validated: 1 }

  validates :number, :label, presence: true

  scope :kept, -> { where(discarded_at: nil) }
end
```

- [ ] **Step 5 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/question_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 6 : Commit**

```bash
git add app/models/question.rb spec/models/question_spec.rb spec/factories/questions.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add Question model with answer_type enum and soft delete

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Modèle Answer (TDD)

**Files:**
- Create: `spec/factories/answers.rb`
- Create: `spec/models/answer_spec.rb`
- Create: `app/models/answer.rb`

- [ ] **Step 1 : Créer la factory**

```ruby
# spec/factories/answers.rb
FactoryBot.define do
  factory :answer do
    correction_text  { "Car = 56,73 l / Van = 38,68 kWh" }
    explanation_text { "On utilise la formule Consommation × Distance / 100" }
    key_concepts     { [ "énergie primaire", "rendement" ] }
    data_hints       { [ { "source" => "DT", "location" => "tableau Consommation" } ] }
    association :question
  end
end
```

- [ ] **Step 2 : Écrire les tests**

```ruby
# spec/models/answer_spec.rb
require "rails_helper"

RSpec.describe Answer, type: :model do
  describe "associations" do
    it "belongs to question" do
      answer = build(:answer)
      expect(answer.question).to be_a(Question)
    end
  end

  describe "jsonb fields" do
    it "stores key_concepts as array" do
      answer = create(:answer, key_concepts: [ "rendement", "puissance" ])
      answer.reload
      expect(answer.key_concepts).to eq([ "rendement", "puissance" ])
    end

    it "stores data_hints as array of hashes" do
      hints = [ { "source" => "DT", "location" => "tableau ligne 3" } ]
      answer = create(:answer, data_hints: hints)
      answer.reload
      expect(answer.data_hints).to eq(hints)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/answer_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Answer`

- [ ] **Step 4 : Créer le modèle Answer**

```ruby
# app/models/answer.rb
class Answer < ApplicationRecord
  belongs_to :question
end
```

- [ ] **Step 5 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/answer_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 6 : Commit**

```bash
git add app/models/answer.rb spec/models/answer_spec.rb spec/factories/answers.rb
git commit -m "$(cat <<'EOF'
feat(extraction): add Answer model with jsonb key_concepts and data_hints

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Configuration Sidekiq + ActionCable Redis

**Files:**
- Create: `config/sidekiq.yml`
- Modify: `config/application.rb`
- Modify: `config/cable.yml`

- [ ] **Step 1 : Créer config/sidekiq.yml**

```yaml
# config/sidekiq.yml
:queues:
  - default
  - extraction
```

- [ ] **Step 2 : Ajouter queue_adapter dans config/application.rb**

Lire `config/application.rb`, puis ajouter dans le bloc `class Application < Rails::Application` :

```ruby
config.active_job.queue_adapter = :sidekiq
```

- [ ] **Step 3 : Mettre à jour config/cable.yml**

```yaml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV["REDIS_URL"] %>
```

- [ ] **Step 4 : Vérifier que Sidekiq est configuré**

```bash
bin/rails runner "puts ActiveJob::Base.queue_adapter"
```

Résultat attendu : `#<ActiveJob::QueueAdapters::SidekiqAdapter:...>`

- [ ] **Step 5 : Commit**

```bash
git add config/sidekiq.yml config/application.rb config/cable.yml
git commit -m "$(cat <<'EOF'
chore(config): sidekiq as ActiveJob adapter and Redis for ActionCable

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8 : Smoke test Plan A

- [ ] **Step 1 : Lancer la suite RSpec modèles**

```bash
bundle exec rspec spec/models/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier le schema**

```bash
bin/rails db:migrate:status
```

Résultat attendu : toutes les migrations `up`

- [ ] **Step 3 : Rubocop**

```bash
bin/rubocop --no-color 2>&1 | tail -5
```

Résultat attendu : `no offenses detected`

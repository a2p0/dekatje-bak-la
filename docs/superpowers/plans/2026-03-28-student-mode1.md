# Student Mode 1 — Navigation & Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow students to navigate questions by part, reveal corrections with data_hints, and track their progression via StudentSession.

**Architecture:** Migration StudentSession (progression JSON), Student::SubjectsController (list + show redirect), Student::QuestionsController (show + reveal via Turbo Frame), responsive sidebar (Stimulus), progression tracking.

**Tech Stack:** Rails 8.1, Hotwire/Turbo Frames, Stimulus, RSpec

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_create_student_sessions.rb` | Créer | Table StudentSession |
| `app/models/student_session.rb` | Créer | Modèle progression |
| `app/models/student.rb` | Modifier | has_many :student_sessions |
| `app/models/subject.rb` | Modifier | has_many :student_sessions |
| `config/routes.rb` | Modifier | Routes student subjects + questions |
| `app/controllers/student/subjects_controller.rb` | Créer | index + show |
| `app/controllers/student/questions_controller.rb` | Créer | show + reveal |
| `app/views/student/subjects/index.html.erb` | Créer | Liste sujets assignés |
| `app/views/student/questions/show.html.erb` | Créer | Page question + sidebar |
| `app/views/student/questions/_correction.html.erb` | Créer | Turbo Frame correction |
| `app/views/student/questions/_sidebar.html.erb` | Créer | Sidebar/drawer navigation |
| `app/javascript/controllers/sidebar_controller.js` | Créer | Toggle drawer mobile |
| `spec/models/student_session_spec.rb` | Créer | Tests modèle |
| `spec/factories/student_sessions.rb` | Créer | Factory |
| `spec/requests/student/subjects_spec.rb` | Créer | Tests request |
| `spec/requests/student/questions_spec.rb` | Créer | Tests request |

---

## Task 1 : Migration StudentSession + modèle

**Files:**
- Create: `db/migrate/TIMESTAMP_create_student_sessions.rb`
- Create: `app/models/student_session.rb`
- Create: `spec/models/student_session_spec.rb`
- Create: `spec/factories/student_sessions.rb`
- Modify: `app/models/student.rb`
- Modify: `app/models/subject.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateStudentSessions student:references subject:references mode:integer progression:jsonb started_at:datetime last_activity_at:datetime
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class CreateStudentSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :student_sessions do |t|
      t.references :student, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.integer :mode, default: 0, null: false
      t.jsonb :progression, default: {}, null: false
      t.datetime :started_at
      t.datetime :last_activity_at
      t.timestamps
    end

    add_index :student_sessions, [ :student_id, :subject_id ], unique: true
  end
end
```

- [ ] **Step 3 : Migrer**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateStudentSessions: migrated`

- [ ] **Step 4 : Créer spec/factories/student_sessions.rb**

```ruby
FactoryBot.define do
  factory :student_session do
    association :student
    association :subject
    mode { :autonomous }
    progression { {} }
    started_at { Time.current }
    last_activity_at { Time.current }
  end
end
```

- [ ] **Step 5 : Créer spec/models/student_session_spec.rb**

```ruby
require "rails_helper"

RSpec.describe StudentSession, type: :model do
  describe "associations" do
    it "belongs to student" do
      ss = build(:student_session)
      expect(ss.student).to be_a(Student)
    end

    it "belongs to subject" do
      ss = build(:student_session)
      expect(ss.subject).to be_a(Subject)
    end
  end

  describe "uniqueness" do
    it "prevents duplicate student-subject pairs" do
      student = create(:student)
      subject = create(:subject)
      create(:student_session, student: student, subject: subject)
      duplicate = build(:student_session, student: student, subject: subject)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#mark_seen!" do
    it "sets seen to true for question" do
      ss = create(:student_session)
      question = create(:question)
      ss.mark_seen!(question.id)
      expect(ss.reload.progression[question.id.to_s]["seen"]).to be true
    end
  end

  describe "#mark_answered!" do
    it "sets answered to true for question" do
      ss = create(:student_session)
      question = create(:question)
      ss.mark_answered!(question.id)
      expect(ss.reload.progression[question.id.to_s]["answered"]).to be true
    end
  end

  describe "#answered?" do
    it "returns false for unseen question" do
      ss = create(:student_session)
      expect(ss.answered?(999)).to be false
    end

    it "returns true for answered question" do
      ss = create(:student_session, progression: { "42" => { "answered" => true } })
      expect(ss.answered?(42)).to be true
    end
  end

  describe "#first_undone_question" do
    it "returns first unanswered question in part" do
      ss = create(:student_session)
      part = create(:part, subject: ss.subject)
      q1 = create(:question, part: part, position: 1)
      q2 = create(:question, part: part, number: "1.2", position: 2)
      ss.update!(progression: { q1.id.to_s => { "answered" => true } })
      expect(ss.first_undone_question(part)).to eq(q2)
    end

    it "returns first question when all done" do
      ss = create(:student_session)
      part = create(:part, subject: ss.subject)
      q1 = create(:question, part: part, position: 1)
      ss.update!(progression: { q1.id.to_s => { "answered" => true } })
      expect(ss.first_undone_question(part)).to eq(q1)
    end
  end
end
```

- [ ] **Step 6 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/student_session_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant StudentSession`

- [ ] **Step 7 : Créer app/models/student_session.rb**

```ruby
class StudentSession < ApplicationRecord
  belongs_to :student
  belongs_to :subject

  enum :mode, { autonomous: 0, tutored: 1 }

  validates :student_id, uniqueness: { scope: :subject_id }

  def mark_seen!(question_id)
    key = question_id.to_s
    progression[key] ||= {}
    progression[key]["seen"] = true
    update!(last_activity_at: Time.current)
  end

  def mark_answered!(question_id)
    key = question_id.to_s
    progression[key] ||= {}
    progression[key]["answered"] = true
    update!(last_activity_at: Time.current)
  end

  def answered?(question_id)
    progression.dig(question_id.to_s, "answered") == true
  end

  def first_undone_question(part)
    questions = part.questions.kept.order(:position)
    questions.detect { |q| !answered?(q.id) } || questions.first
  end
end
```

- [ ] **Step 8 : Mettre à jour app/models/student.rb**

Ajouter après `has_secure_password` :

```ruby
has_many :student_sessions, dependent: :destroy
```

- [ ] **Step 9 : Mettre à jour app/models/subject.rb**

Ajouter après `has_many :classrooms, through: :classroom_subjects` :

```ruby
has_many :student_sessions, dependent: :destroy
```

- [ ] **Step 10 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/student_session_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 11 : Commit**

```bash
git add db/migrate/ db/schema.rb app/models/student_session.rb app/models/student.rb app/models/subject.rb spec/models/student_session_spec.rb spec/factories/student_sessions.rb
git commit -m "$(cat <<'EOF'
feat(student): add StudentSession model with progression tracking

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Routes + Student::SubjectsController

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/student/subjects_controller.rb`
- Create: `app/views/student/subjects/index.html.erb`

- [ ] **Step 1 : Mettre à jour config/routes.rb**

Remplacer le bloc `scope "/:access_code"` par :

```ruby
scope "/:access_code", as: :student do
  get    "/",        to: "student/sessions#new",     as: :login
  post   "/session", to: "student/sessions#create",  as: :session
  delete "/session", to: "student/sessions#destroy"
  get "/subjects", to: "student/subjects#index", as: :root
  get "/subjects/:id", to: "student/subjects#show", as: :subject
  get "/subjects/:subject_id/questions/:id", to: "student/questions#show", as: :question
  patch "/subjects/:subject_id/questions/:id/reveal", to: "student/questions#reveal", as: :reveal_question
end
```

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep "student.*subject\|student.*question"
```

Résultat attendu : routes `student_root`, `student_subject`, `student_question`, `student_reveal_question`

- [ ] **Step 3 : Créer app/controllers/student/subjects_controller.rb**

```ruby
class Student::SubjectsController < Student::BaseController
  def index
    @subjects = @classroom.subjects.published.order(:title)
  end

  def show
    @subject = @classroom.subjects.published.find_by(id: params[:id])
    unless @subject
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Sujet introuvable."
    end

    session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |ss|
      ss.mode = :autonomous
      ss.started_at = Time.current
      ss.last_activity_at = Time.current
    end

    first_part = @subject.parts.order(:position).first
    unless first_part
      return redirect_to student_root_path(access_code: params[:access_code]),
                         alert: "Ce sujet n'a pas encore de questions."
    end

    question = session_record.first_undone_question(first_part)
    redirect_to student_question_path(
      access_code: params[:access_code],
      subject_id: @subject.id,
      id: question.id
    )
  end
end
```

- [ ] **Step 4 : Créer app/views/student/subjects/index.html.erb**

```erb
<h1>Mes sujets — <%= @classroom.name %></h1>

<% if @subjects.empty? %>
  <p>Aucun sujet n'a encore été assigné à votre classe.</p>
<% else %>
  <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px;">
    <% @subjects.each do |subject| %>
      <%
        session_record = current_student.student_sessions.find_by(subject: subject)
        total = subject.parts.joins(:questions).merge(Question.kept).count
        answered = session_record ? session_record.progression.count { |_k, v| v["answered"] } : 0
        progress = total > 0 ? (answered * 100.0 / total).round : 0
      %>
      <div style="border: 1px solid #334155; border-radius: 8px; padding: 16px; background: #1e293b;">
        <h3 style="margin: 0 0 8px;"><%= subject.title %></h3>
        <p style="color: #94a3b8; margin: 0 0 8px;">
          <%= subject.specialty %> — <%= subject.year %> — <%= subject.region %>
        </p>
        <div style="background: #0f172a; border-radius: 4px; height: 8px; margin-bottom: 12px;">
          <div style="background: #7c3aed; height: 100%; border-radius: 4px; width: <%= progress %>%;"></div>
        </div>
        <p style="color: #94a3b8; font-size: 13px; margin: 0 0 12px;">
          <%= answered %>/<%= total %> questions — <%= progress %>%
        </p>
        <%= link_to(session_record ? "Continuer" : "Commencer",
            student_subject_path(access_code: params[:access_code], id: subject.id),
            style: "display: inline-block; padding: 8px 20px; background: #7c3aed; color: white; border-radius: 6px; text-decoration: none;") %>
      </div>
    <% end %>
  </div>
<% end %>

<%= link_to "Se déconnecter", student_session_path(access_code: params[:access_code]), data: { turbo_method: :delete } %>
```

- [ ] **Step 5 : Commit**

```bash
git add config/routes.rb app/controllers/student/subjects_controller.rb app/views/student/subjects/index.html.erb
git commit -m "$(cat <<'EOF'
feat(student): add SubjectsController with index and show-redirect

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Sidebar Stimulus controller

**Files:**
- Create: `app/javascript/controllers/sidebar_controller.js`

- [ ] **Step 1 : Créer app/javascript/controllers/sidebar_controller.js**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.classList.remove("translate-x-[-100%]")
    this.drawerTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.drawerTarget.classList.add("translate-x-[-100%]")
    this.drawerTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
  }
}
```

- [ ] **Step 2 : Commit**

```bash
git add app/javascript/controllers/sidebar_controller.js
git commit -m "$(cat <<'EOF'
feat(student): add sidebar Stimulus controller for mobile drawer toggle

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Student::QuestionsController + vues

**Files:**
- Create: `app/controllers/student/questions_controller.rb`
- Create: `app/views/student/questions/show.html.erb`
- Create: `app/views/student/questions/_correction.html.erb`
- Create: `app/views/student/questions/_sidebar.html.erb`

- [ ] **Step 1 : Créer app/controllers/student/questions_controller.rb**

```ruby
class Student::QuestionsController < Student::BaseController
  before_action :set_subject
  before_action :set_question
  before_action :set_session_record

  def show
    @part = @question.part
    @parts = @subject.parts.order(:position)
    @questions_in_part = @part.questions.kept.order(:position)
    @session_record.mark_seen!(@question.id)
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
end
```

- [ ] **Step 2 : Créer app/views/student/questions/_sidebar.html.erb**

```erb
<%# Sidebar content — used in both persistent desktop sidebar and mobile drawer %>
<div style="padding: 16px;">
  <details open style="margin-bottom: 12px;">
    <summary style="color: #9ca3af; font-size: 12px; text-transform: uppercase; cursor: pointer;">
      Mise en situation
    </summary>
    <p style="color: #d1d5db; font-size: 13px; line-height: 1.5; margin-top: 6px;">
      <%= subject.presentation_text %>
    </p>
  </details>

  <div style="margin-bottom: 16px;">
    <p style="color: #9ca3af; font-size: 12px; text-transform: uppercase; margin-bottom: 4px;">Objectif</p>
    <p style="color: #d1d5db; font-size: 13px; line-height: 1.5;">
      <%= current_part.objective_text %>
    </p>
  </div>

  <hr style="border-color: #374151; margin: 12px 0;">

  <p style="color: #9ca3af; font-size: 12px; text-transform: uppercase; margin-bottom: 8px;">
    <%= current_part.title %>
  </p>
  <% questions_in_part.each do |q| %>
    <% answered = session_record.answered?(q.id) %>
    <%= link_to student_question_path(access_code: access_code, subject_id: subject.id, id: q.id),
        style: "display: block; padding: 6px 8px; margin: 2px 0; border-radius: 4px; text-decoration: none; color: #{q == current_question ? 'white' : '#9ca3af'}; background: #{q == current_question ? '#7c3aed33' : 'transparent'}; font-size: 13px;",
        data: { action: "click->sidebar#close" } do %>
      <%= answered ? "✓" : "○" %>
      Q<%= q.number %> (<%= q.points %> pts)
    <% end %>
  <% end %>

  <hr style="border-color: #374151; margin: 12px 0;">

  <p style="color: #9ca3af; font-size: 12px; text-transform: uppercase; margin-bottom: 8px;">Autres parties</p>
  <% parts.each do |p| %>
    <% next if p == current_part %>
    <% part_questions = p.questions.kept %>
    <% part_answered = part_questions.count { |q| session_record.answered?(q.id) } %>
    <%= link_to student_subject_path(access_code: access_code, id: subject.id, part_id: p.id),
        style: "display: block; padding: 6px 8px; margin: 2px 0; color: #d1d5db; font-size: 13px; text-decoration: none;" do %>
      <%= p.title %> (<%= part_answered %>/<%= part_questions.size %>)
    <% end %>
  <% end %>

  <hr style="border-color: #374151; margin: 12px 0;">

  <p style="color: #9ca3af; font-size: 12px; text-transform: uppercase; margin-bottom: 8px;">Documents</p>
  <% if subject.dt_file.attached? %>
    <%= link_to "📄 Documents Techniques (DT)",
        rails_blob_path(subject.dt_file, disposition: "inline"),
        target: "_blank",
        style: "display: block; color: #60a5fa; font-size: 13px; margin: 4px 0; text-decoration: none;" %>
  <% end %>
  <% if subject.dr_vierge_file.attached? %>
    <%= link_to "📄 DR vierge",
        rails_blob_path(subject.dr_vierge_file, disposition: "attachment"),
        style: "display: block; color: #60a5fa; font-size: 13px; margin: 4px 0; text-decoration: none;" %>
  <% end %>
  <% if session_record.answered?(current_question.id) %>
    <% if subject.dr_corrige_file.attached? %>
      <%= link_to "📄 DR corrigé",
          rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
          target: "_blank",
          style: "display: block; color: #60a5fa; font-size: 13px; margin: 4px 0; text-decoration: none;" %>
    <% end %>
    <% if subject.questions_corrigees_file.attached? %>
      <%= link_to "📄 Questions corrigées",
          rails_blob_path(subject.questions_corrigees_file, disposition: "inline"),
          target: "_blank",
          style: "display: block; color: #60a5fa; font-size: 13px; margin: 4px 0; text-decoration: none;" %>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 3 : Créer app/views/student/questions/_correction.html.erb**

```erb
<div style="margin-top: 16px;">
  <%# Correction %>
  <div style="border-left: 3px solid #22c55e; background: #14532d22; border-radius: 0 8px 8px 0; padding: 14px; margin-bottom: 12px;">
    <p style="color: #22c55e; font-weight: 600; font-size: 13px; margin: 0 0 8px; text-transform: uppercase;">✓ Correction</p>
    <p style="color: #e2e8f0; font-size: 14px; line-height: 1.5; margin: 0;"><%= question.answer&.correction_text %></p>
  </div>

  <%# Explication %>
  <% if question.answer&.explanation_text.present? %>
    <div style="background: #1e293b; border-radius: 8px; padding: 14px; margin-bottom: 12px;">
      <p style="color: #60a5fa; font-weight: 600; font-size: 13px; margin: 0 0 8px;">Explication</p>
      <p style="color: #cbd5e1; font-size: 13px; line-height: 1.5; margin: 0;"><%= question.answer.explanation_text %></p>
    </div>
  <% end %>

  <%# Data hints %>
  <% if question.answer&.data_hints.present? %>
    <div style="background: #1e293b; border-radius: 8px; padding: 14px; margin-bottom: 12px;">
      <p style="color: #f59e0b; font-weight: 600; font-size: 13px; margin: 0 0 8px;">Où trouver les données ?</p>
      <% question.answer.data_hints.each do |hint| %>
        <div style="margin-bottom: 6px;">
          <span style="background: #f59e0b22; color: #fbbf24; font-size: 11px; padding: 2px 8px; border-radius: 4px; font-weight: 600;"><%= hint["source"] %></span>
          <span style="color: #cbd5e1; font-size: 13px; margin-left: 6px;"><%= hint["location"] %></span>
        </div>
      <% end %>
    </div>
  <% end %>

  <%# Key concepts %>
  <% if question.answer&.key_concepts.present? %>
    <div style="background: #1e293b; border-radius: 8px; padding: 14px; margin-bottom: 12px;">
      <p style="color: #a78bfa; font-weight: 600; font-size: 13px; margin: 0 0 8px;">Concepts clés</p>
      <div style="display: flex; gap: 6px; flex-wrap: wrap;">
        <% question.answer.key_concepts.each do |concept| %>
          <span style="background: #7c3aed33; color: #c4b5fd; font-size: 12px; padding: 4px 10px; border-radius: 12px;"><%= concept %></span>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Documents correction %>
  <% if subject.dr_corrige_file.attached? || subject.questions_corrigees_file.attached? %>
    <div style="border: 1px solid #334155; border-radius: 8px; padding: 14px; margin-bottom: 12px;">
      <p style="color: #94a3b8; font-weight: 600; font-size: 13px; margin: 0 0 8px;">Documents correction</p>
      <% if subject.dr_corrige_file.attached? %>
        <%= link_to "DR corrigé ↗",
            rails_blob_path(subject.dr_corrige_file, disposition: "inline"),
            target: "_blank",
            style: "display: block; color: #60a5fa; font-size: 13px; margin: 2px 0; text-decoration: none;" %>
      <% end %>
      <% if subject.questions_corrigees_file.attached? %>
        <%= link_to "Questions corrigées ↗",
            rails_blob_path(subject.questions_corrigees_file, disposition: "inline"),
            target: "_blank",
            style: "display: block; color: #60a5fa; font-size: 13px; margin: 2px 0; text-decoration: none;" %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4 : Créer app/views/student/questions/show.html.erb**

```erb
<div data-controller="sidebar" style="display: flex; min-height: 100vh;">
  <%# Backdrop (mobile only) %>
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
</div>
```

- [ ] **Step 5 : Commit**

```bash
git add app/controllers/student/questions_controller.rb app/views/student/questions/
git commit -m "$(cat <<'EOF'
feat(student): add QuestionsController with show, reveal, sidebar and correction views

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Request specs

**Files:**
- Create: `spec/requests/student/subjects_spec.rb`
- Create: `spec/requests/student/questions_spec.rb`

- [ ] **Step 1 : Créer spec/requests/student/subjects_spec.rb**

```ruby
require "rails_helper"

RSpec.describe "Student::Subjects", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /subjects (index)" do
    it "returns 200 and shows assigned subjects" do
      get student_root_path(access_code: classroom.access_code)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(subject_obj.title)
    end

    it "does not show unassigned subjects" do
      other_subject = create(:subject, status: :published)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include(other_subject.title)
    end

    it "does not show draft subjects" do
      draft = create(:subject, status: :draft)
      create(:classroom_subject, classroom: classroom, subject: draft)
      get student_root_path(access_code: classroom.access_code)
      expect(response.body).not_to include(draft.title)
    end
  end

  describe "GET /subjects/:id (show)" do
    it "creates a student session and redirects to first question" do
      part = create(:part, subject: subject_obj, position: 1)
      question = create(:question, part: part, position: 1)
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
      expect(response).to redirect_to(
        student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      )
      expect(StudentSession.where(student: student, subject: subject_obj).count).to eq(1)
    end

    it "redirects with alert for subject without parts" do
      get student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
      expect(flash[:alert]).to include("pas encore de questions")
    end

    it "redirects for unassigned subject" do
      other = create(:subject, status: :published)
      get student_subject_path(access_code: classroom.access_code, id: other.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
    end
  end
end
```

- [ ] **Step 2 : Créer spec/requests/student/questions_spec.rb**

```ruby
require "rails_helper"

RSpec.describe "Student::Questions", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, subject: subject_obj, position: 1) }
  let(:question) { create(:question, part: part, position: 1) }
  let!(:answer) { create(:answer, question: question) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /subjects/:subject_id/questions/:id (show)" do
    it "returns 200" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      expect(response).to have_http_status(:ok)
    end

    it "marks question as seen" do
      get student_question_path(access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id)
      ss = StudentSession.find_by(student: student, subject: subject_obj)
      expect(ss.progression[question.id.to_s]["seen"]).to be true
    end

    it "redirects for question from unassigned subject" do
      other_subject = create(:subject, status: :published)
      other_part = create(:part, subject: other_subject)
      other_q = create(:question, part: other_part)
      get student_question_path(access_code: classroom.access_code, subject_id: other_subject.id, id: other_q.id)
      expect(response).to redirect_to(student_root_path(access_code: classroom.access_code))
    end
  end

  describe "PATCH /subjects/:subject_id/questions/:id/reveal" do
    it "marks question as answered" do
      patch student_reveal_question_path(
        access_code: classroom.access_code, subject_id: subject_obj.id, id: question.id
      ), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      ss = StudentSession.find_by(student: student, subject: subject_obj)
      expect(ss.progression[question.id.to_s]["answered"]).to be true
    end
  end
end
```

- [ ] **Step 3 : Lancer les specs**

```bash
bundle exec rspec spec/requests/student/subjects_spec.rb spec/requests/student/questions_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 4 : Commit**

```bash
git add spec/requests/student/subjects_spec.rb spec/requests/student/questions_spec.rb
git commit -m "$(cat <<'EOF'
test(student): add request specs for student subjects and questions controllers

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Smoke test final

- [ ] **Step 1 : Lancer la suite RSpec complète**

```bash
bundle exec rspec spec/models/ spec/requests/ spec/services/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep "student"
```

- [ ] **Step 3 : Rubocop**

```bash
bin/rubocop --no-color 2>&1 | tail -5
```

Résultat attendu : `no offenses detected`

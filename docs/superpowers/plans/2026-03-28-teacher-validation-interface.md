# Teacher Validation Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'enseignant de valider les questions extraites par partie, éditer inline via Turbo Frames, publier et assigner aux classes.

**Architecture:** Migration ClassroomSubject (jointure), modèles mis à jour, Teacher::PartsController (vue côte-à-côte), Teacher::QuestionsController (CRUD + validate/invalidate via Turbo Frames), updates SubjectsController (unpublish/assign).

**Tech Stack:** Rails 8.1, Hotwire/Turbo Frames, Turbo Streams, RSpec

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_create_classroom_subjects.rb` | Créer | Jointure Classroom ↔ Subject |
| `app/models/classroom_subject.rb` | Créer | Modèle jointure |
| `app/models/subject.rb` | Modifier | has_many classrooms, publishable?, validated_questions_count |
| `app/models/classroom.rb` | Modifier | has_many subjects through classroom_subjects |
| `config/routes.rb` | Modifier | Parts nested + assign/unpublish sur subjects |
| `app/controllers/teacher/parts_controller.rb` | Créer | Show partie + questions |
| `app/controllers/teacher/questions_controller.rb` | Créer | update/destroy/validate/invalidate |
| `app/controllers/teacher/subjects_controller.rb` | Modifier | unpublish + assign GET/PATCH |
| `app/views/teacher/parts/show.html.erb` | Créer | Vue deux colonnes |
| `app/views/teacher/questions/_question.html.erb` | Créer | Turbo Frame lecture |
| `app/views/teacher/questions/_question_form.html.erb` | Créer | Turbo Frame édition |
| `app/views/teacher/subjects/_stats.html.erb` | Créer | Compteur + bouton Publier |
| `app/views/teacher/subjects/assign.html.erb` | Créer | Checkboxes classes |
| `app/views/teacher/subjects/show.html.erb` | Modifier | Lien vers parties + stats |
| `spec/models/classroom_subject_spec.rb` | Créer | Tests modèle |
| `spec/factories/classroom_subjects.rb` | Créer | Factory |
| `spec/requests/teacher/parts_spec.rb` | Créer | Tests request |
| `spec/requests/teacher/questions_spec.rb` | Créer | Tests request |

---

## Task 1 : Migration ClassroomSubject + modèle

**Files:**
- Create: `db/migrate/TIMESTAMP_create_classroom_subjects.rb`
- Create: `app/models/classroom_subject.rb`
- Modify: `app/models/subject.rb`
- Modify: `app/models/classroom.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateClassroomSubjects classroom:references subject:references
```

- [ ] **Step 2 : Éditer la migration**

```ruby
class CreateClassroomSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_subjects do |t|
      t.references :classroom, null: false, foreign_key: true
      t.references :subject,   null: false, foreign_key: true
      t.timestamps
    end

    add_index :classroom_subjects, [ :classroom_id, :subject_id ], unique: true
  end
end
```

- [ ] **Step 3 : Migrer**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateClassroomSubjects: migrated`

- [ ] **Step 4 : Créer spec/factories/classroom_subjects.rb**

```ruby
FactoryBot.define do
  factory :classroom_subject do
    association :classroom
    association :subject
  end
end
```

- [ ] **Step 5 : Créer spec/models/classroom_subject_spec.rb**

```ruby
require "rails_helper"

RSpec.describe ClassroomSubject, type: :model do
  describe "associations" do
    it "belongs to classroom" do
      cs = build(:classroom_subject)
      expect(cs.classroom).to be_a(Classroom)
    end

    it "belongs to subject" do
      cs = build(:classroom_subject)
      expect(cs.subject).to be_a(Subject)
    end
  end

  describe "uniqueness" do
    it "prevents duplicate classroom-subject pairs" do
      classroom = create(:classroom)
      subject = create(:subject)
      create(:classroom_subject, classroom: classroom, subject: subject)
      duplicate = build(:classroom_subject, classroom: classroom, subject: subject)
      expect(duplicate).not_to be_valid
    end
  end
end
```

- [ ] **Step 6 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/classroom_subject_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ClassroomSubject`

- [ ] **Step 7 : Créer app/models/classroom_subject.rb**

```ruby
class ClassroomSubject < ApplicationRecord
  belongs_to :classroom
  belongs_to :subject

  validates :classroom_id, uniqueness: { scope: :subject_id }
end
```

- [ ] **Step 8 : Mettre à jour app/models/subject.rb**

Lire `app/models/subject.rb`, puis ajouter après `has_many :parts, dependent: :destroy` :

```ruby
has_many :classroom_subjects, dependent: :destroy
has_many :classrooms, through: :classroom_subjects
```

Et ajouter ces méthodes avant `private` :

```ruby
def validated_questions_count
  parts.joins(:questions).merge(Question.where(status: :validated).kept).count
end

def publishable?
  validated_questions_count > 0
end
```

- [ ] **Step 9 : Mettre à jour app/models/classroom.rb**

Lire `app/models/classroom.rb`, puis ajouter :

```ruby
has_many :classroom_subjects, dependent: :destroy
has_many :subjects, through: :classroom_subjects
```

- [ ] **Step 10 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/classroom_subject_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 11 : Commit**

```bash
git add db/migrate/ db/schema.rb app/models/classroom_subject.rb app/models/subject.rb app/models/classroom.rb spec/models/classroom_subject_spec.rb spec/factories/classroom_subjects.rb
git commit -m "$(cat <<'EOF'
feat(validation): add ClassroomSubject jointure and Subject#publishable? helper

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Routes + Teacher::PartsController + vue

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/teacher/parts_controller.rb`
- Create: `app/views/teacher/parts/show.html.erb`

- [ ] **Step 1 : Mettre à jour config/routes.rb**

Lire `config/routes.rb`, puis remplacer le bloc `resources :subjects` par :

```ruby
resources :subjects, only: [ :index, :new, :create, :show ] do
  resources :parts, only: [ :show ] do
    resources :questions, only: [ :update, :destroy ] do
      member do
        patch :validate
        patch :invalidate
      end
    end
  end
  member do
    patch :publish
    patch :archive
    patch :unpublish
    post  :retry_extraction
    get   :assign
    patch :assign
  end
end
```

- [ ] **Step 2 : Créer app/controllers/teacher/parts_controller.rb**

```ruby
class Teacher::PartsController < Teacher::BaseController
  before_action :set_subject
  before_action :set_part

  def show
    @questions = @part.questions.kept.order(:position)
    @parts = @subject.parts.order(:position)
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def set_part
    @part = @subject.parts.find_by(id: params[:id])
    redirect_to teacher_subject_path(@subject), alert: "Partie introuvable." unless @part
  end
end
```

- [ ] **Step 3 : Créer app/views/teacher/parts/show.html.erb**

```erb
<h1><%= @subject.title %> — <%= @part.title %></h1>

<p>Objectif : <%= @part.objective_text %></p>

<nav>
  <% @parts.each do |part| %>
    <%= link_to part.title,
        teacher_subject_part_path(@subject, part),
        style: part == @part ? "font-weight: bold" : "" %>
  <% end %>
</nav>

<div style="display: flex; gap: 20px;">
  <div style="flex: 1;">
    <h2>Questions (<%= @questions.count %>)</h2>

    <% if @questions.empty? %>
      <p>Aucune question dans cette partie.</p>
    <% else %>
      <% @questions.each do |question| %>
        <%= render "teacher/questions/question", question: question, subject: @subject, part: @part %>
      <% end %>
    <% end %>
  </div>

  <div style="flex: 1;">
    <h2>PDF Énoncé</h2>
    <% if @subject.enonce_file.attached? %>
      <iframe
        src="<%= rails_blob_path(@subject.enonce_file) %>"
        width="100%"
        height="800px"
        style="border: 1px solid #ccc;">
      </iframe>
    <% end %>
  </div>
</div>

<%= link_to "Retour au sujet", teacher_subject_path(@subject) %>
```

- [ ] **Step 4 : Vérifier les routes**

```bash
bin/rails routes | grep "teacher.*part"
```

Résultat attendu : `teacher_subject_part` présente

- [ ] **Step 5 : Commit**

```bash
git add config/routes.rb app/controllers/teacher/parts_controller.rb app/views/teacher/parts/
git commit -m "$(cat <<'EOF'
feat(validation): add PartsController with two-column validation view

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Teacher::QuestionsController + partials Turbo Frame

**Files:**
- Create: `app/controllers/teacher/questions_controller.rb`
- Create: `app/views/teacher/questions/_question.html.erb`
- Create: `app/views/teacher/questions/_question_form.html.erb`

- [ ] **Step 1 : Créer app/controllers/teacher/questions_controller.rb**

```ruby
class Teacher::QuestionsController < Teacher::BaseController
  before_action :set_subject
  before_action :set_part
  before_action :set_question

  def update
    if @question.update(question_params)
      @question.answer&.update(answer_params) if answer_params.values.any?(&:present?)
      render turbo_stream: turbo_stream.replace(
        dom_id(@question),
        partial: "teacher/questions/question",
        locals: { question: @question, subject: @subject, part: @part }
      )
    else
      render turbo_stream: turbo_stream.replace(
        "#{dom_id(@question)}_form",
        partial: "teacher/questions/question_form",
        locals: { question: @question, subject: @subject, part: @part }
      )
    end
  end

  def destroy
    @question.update!(discarded_at: Time.current)
    render turbo_stream: turbo_stream.remove(dom_id(@question))
  end

  def validate
    @question.update!(status: :validated)
    render turbo_stream: turbo_stream.replace(
      dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: @subject, part: @part }
    )
  end

  def invalidate
    @question.update!(status: :draft)
    render turbo_stream: turbo_stream.replace(
      dom_id(@question),
      partial: "teacher/questions/question",
      locals: { question: @question, subject: @subject, part: @part }
    )
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def set_part
    @part = @subject.parts.find_by(id: params[:part_id])
    redirect_to teacher_subject_path(@subject), alert: "Partie introuvable." unless @part
  end

  def set_question
    @question = @part.questions.kept.find_by(id: params[:id])
    redirect_to teacher_subject_part_path(@subject, @part), alert: "Question introuvable." unless @question
  end

  def question_params
    params.require(:question).permit(:label, :context_text, :points, :answer_type)
  end

  def answer_params
    params.fetch(:answer, {}).permit(:correction_text, :explanation_text)
  end
end
```

- [ ] **Step 2 : Créer app/views/teacher/questions/_question.html.erb**

```erb
<%= turbo_frame_tag dom_id(question) do %>
  <div style="border: 1px solid <%= question.validated? ? '#28a745' : '#ccc' %>; padding: 10px; margin: 8px 0;">
    <div style="display: flex; justify-content: space-between; align-items: center;">
      <span>
        <strong>Q<%= question.number %></strong>
        <span style="color: <%= question.validated? ? 'green' : 'gray' %>;">
          [<%= question.status %>]
        </span>
        (<%= question.points %> pts)
      </span>
      <span>
        <% if question.validated? %>
          <%= button_to "Invalider",
              invalidate_teacher_subject_part_question_path(subject, part, question),
              method: :patch, form: { data: { turbo_frame: dom_id(question) } } %>
        <% else %>
          <%= button_to "Valider",
              validate_teacher_subject_part_question_path(subject, part, question),
              method: :patch, form: { data: { turbo_frame: dom_id(question) } } %>
        <% end %>
        <%= link_to "Modifier",
            "#",
            data: { action: "click->toggle#toggle", toggle_target: "content" } %>
        <%= button_to "Supprimer",
            teacher_subject_part_question_path(subject, part, question),
            method: :delete,
            data: { turbo_confirm: "Supprimer cette question ?" },
            form: { data: { turbo_frame: "_top" } } %>
      </span>
    </div>

    <p><%= question.label %></p>
    <% if question.answer&.correction_text.present? %>
      <p><em>Correction : <%= question.answer.correction_text %></em></p>
    <% end %>

    <%= turbo_frame_tag "#{dom_id(question)}_form" do %>
      <%= render "teacher/questions/question_form", question: question, subject: subject, part: part %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 3 : Créer app/views/teacher/questions/_question_form.html.erb**

```erb
<%= form_with url: teacher_subject_part_question_path(subject, part, question),
              method: :patch,
              data: { turbo_frame: dom_id(question) } do |f| %>
  <div>
    <%= f.label :label, "Énoncé" %>
    <%= f.text_area :label, value: question.label, rows: 3, style: "width:100%" %>
  </div>

  <div>
    <%= f.label :points, "Points" %>
    <%= f.number_field :points, value: question.points, step: 0.5 %>
  </div>

  <% if question.answer %>
    <%= fields_for :answer, question.answer do |af| %>
      <div>
        <%= af.label :correction_text, "Correction" %>
        <%= af.text_area :correction_text, rows: 3, style: "width:100%" %>
      </div>
      <div>
        <%= af.label :explanation_text, "Explication" %>
        <%= af.text_area :explanation_text, rows: 2, style: "width:100%" %>
      </div>
    <% end %>
  <% end %>

  <%= f.submit "Sauvegarder" %>
<% end %>
```

- [ ] **Step 4 : Commit**

```bash
git add app/controllers/teacher/questions_controller.rb app/views/teacher/questions/
git commit -m "$(cat <<'EOF'
feat(validation): add QuestionsController with inline Turbo Frame editing and validate actions

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : SubjectsController updates + vue assign + show update

**Files:**
- Modify: `app/controllers/teacher/subjects_controller.rb`
- Create: `app/views/teacher/subjects/assign.html.erb`
- Create: `app/views/teacher/subjects/_stats.html.erb`
- Modify: `app/views/teacher/subjects/show.html.erb`

- [ ] **Step 1 : Lire et mettre à jour subjects_controller.rb**

Lire `app/controllers/teacher/subjects_controller.rb`, puis :

1. Ajouter `:unpublish, :assign` au `before_action :set_subject`
2. Modifier `publish` pour rediriger vers `assign` :

```ruby
def publish
  unless @subject.publishable?
    return redirect_to teacher_subject_path(@subject),
                       alert: "Publiez au moins une question validée avant de publier."
  end
  @subject.update!(status: :published)
  redirect_to assign_teacher_subject_path(@subject),
              notice: "Sujet publié. Assignez-le maintenant aux classes."
end
```

3. Ajouter les nouvelles actions :

```ruby
def unpublish
  unless @subject.published?
    return redirect_to teacher_subject_path(@subject),
                       alert: "Seul un sujet publié peut être dépublié."
  end
  @subject.update!(status: :draft)
  redirect_to teacher_subject_path(@subject), notice: "Sujet dépublié."
end

def assign
  @classrooms = current_teacher.classrooms.order(:name)
  @assigned_ids = @subject.classroom_ids

  if request.patch?
    selected_ids = Array(params[:classroom_ids]).map(&:to_i)
    @subject.classroom_ids = selected_ids
    redirect_to teacher_subject_path(@subject), notice: "Assignation mise à jour."
  end
end
```

- [ ] **Step 2 : Créer app/views/teacher/subjects/_stats.html.erb**

```erb
<div id="subject-stats">
  <p>
    Questions validées : <strong><%= subject.validated_questions_count %></strong>
    / <%= subject.parts.joins(:questions).merge(Question.kept).count %>
  </p>

  <% if subject.draft? || subject.pending_validation? %>
    <% if subject.publishable? %>
      <%= button_to "Publier le sujet",
          publish_teacher_subject_path(subject),
          method: :patch,
          data: { turbo_confirm: "Publier ce sujet ?" } %>
    <% else %>
      <button disabled>Publier le sujet (validez au moins une question)</button>
    <% end %>
  <% end %>

  <% if subject.published? %>
    <%= button_to "Dépublier",
        unpublish_teacher_subject_path(subject),
        method: :patch,
        data: { turbo_confirm: "Dépublier ce sujet ?" } %>
    <%= link_to "Gérer l'assignation", assign_teacher_subject_path(subject) %>
  <% end %>
</div>
```

- [ ] **Step 3 : Créer app/views/teacher/subjects/assign.html.erb**

```erb
<h1>Assigner "<%= @subject.title %>" aux classes</h1>

<%= form_with url: assign_teacher_subject_path(@subject), method: :patch do |f| %>
  <% if @classrooms.empty? %>
    <p>Vous n'avez pas encore de classe.</p>
  <% else %>
    <% @classrooms.each do |classroom| %>
      <div>
        <label>
          <input type="checkbox"
                 name="classroom_ids[]"
                 value="<%= classroom.id %>"
                 <%= "checked" if @assigned_ids.include?(classroom.id) %>>
          <%= classroom.name %> (<%= classroom.school_year %>)
        </label>
      </div>
    <% end %>
  <% end %>

  <%= f.submit "Enregistrer" %>
<% end %>

<%= link_to "Retour au sujet", teacher_subject_path(@subject) %>
```

- [ ] **Step 4 : Mettre à jour app/views/teacher/subjects/show.html.erb**

Lire `app/views/teacher/subjects/show.html.erb`, puis ajouter après les infos du sujet :

1. Navigation vers les parties :

```erb
<% if @subject.parts.any? %>
  <h2>Valider par partie</h2>
  <ul>
    <% @subject.parts.order(:position).each do |part| %>
      <li>
        <%= link_to part.title, teacher_subject_part_path(@subject, part) %>
        (section <%= part.section_type %>)
      </li>
    <% end %>
  </ul>
<% end %>
```

2. Remplacer les boutons publish/archive existants par le partial stats :

```erb
<%= render "stats", subject: @subject %>
```

- [ ] **Step 5 : Commit**

```bash
git add app/controllers/teacher/subjects_controller.rb app/views/teacher/subjects/
git commit -m "$(cat <<'EOF'
feat(validation): add unpublish, assign actions and stats partial to SubjectsController

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Request specs

**Files:**
- Create: `spec/requests/teacher/parts_spec.rb`
- Create: `spec/requests/teacher/questions_spec.rb`

- [ ] **Step 1 : Créer spec/requests/teacher/parts_spec.rb**

```ruby
require "rails_helper"

RSpec.describe "Teacher::Parts", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, subject: subject_obj) }

  before { sign_in user }

  describe "GET /teacher/subjects/:subject_id/parts/:id" do
    it "returns 200" do
      get teacher_subject_part_path(subject_obj, part)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for subject owned by another teacher" do
      other_subject = create(:subject)
      other_part = create(:part, subject: other_subject)
      get teacher_subject_part_path(other_subject, other_part)
      expect(response).to redirect_to(teacher_subjects_path)
    end
  end
end
```

- [ ] **Step 2 : Créer spec/requests/teacher/questions_spec.rb**

```ruby
require "rails_helper"

RSpec.describe "Teacher::Questions", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:subject_obj) { create(:subject, owner: user) }
  let(:part) { create(:part, subject: subject_obj) }
  let(:question) { create(:question, part: part) }
  let(:answer) { create(:answer, question: question) }

  before { sign_in user }

  describe "PATCH /teacher/subjects/:subject_id/parts/:part_id/questions/:id" do
    it "updates the question" do
      patch teacher_subject_part_question_path(subject_obj, part, question),
            params: { question: { label: "Nouveau label" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.label).to eq("Nouveau label")
    end
  end

  describe "DELETE /teacher/subjects/:subject_id/parts/:part_id/questions/:id" do
    it "soft deletes the question" do
      delete teacher_subject_part_question_path(subject_obj, part, question),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.discarded_at).not_to be_nil
    end
  end

  describe "PATCH validate" do
    it "validates the question" do
      patch validate_teacher_subject_part_question_path(subject_obj, part, question),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.status).to eq("validated")
    end
  end

  describe "PATCH invalidate" do
    let(:question) { create(:question, part: part, status: :validated) }

    it "invalidates the question" do
      patch invalidate_teacher_subject_part_question_path(subject_obj, part, question),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(question.reload.status).to eq("draft")
    end
  end
end
```

- [ ] **Step 3 : Lancer les specs**

```bash
bundle exec rspec spec/requests/teacher/parts_spec.rb spec/requests/teacher/questions_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 4 : Commit**

```bash
git add spec/requests/teacher/parts_spec.rb spec/requests/teacher/questions_spec.rb
git commit -m "$(cat <<'EOF'
test(validation): add request specs for parts and questions controllers

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Smoke test final

- [ ] **Step 1 : Lancer la suite RSpec complète**

```bash
bundle exec rspec spec/models/ spec/requests/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep -E "part|question|assign|unpublish"
```

- [ ] **Step 3 : Rubocop**

```bash
bin/rubocop --no-color 2>&1 | tail -5
```

Résultat attendu : `no offenses detected`

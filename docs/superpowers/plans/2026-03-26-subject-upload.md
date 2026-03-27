# Subject Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'enseignant d'uploader un sujet BAC avec 5 PDFs obligatoires via ActiveStorage.

**Architecture:** Deux migrations (subjects, extraction_jobs), modèles avec enums et validations ActiveStorage, Teacher::SubjectsController avec CRUD + actions publish/archive, vues Hotwire. ExtractionJob créé automatiquement à la création du sujet (pending, pipeline en tâche #4).

**Tech Stack:** Rails 8.1, ActiveStorage (disk local), RSpec + FactoryBot

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/TIMESTAMP_create_subjects.rb` | Créer | Table subjects |
| `db/migrate/TIMESTAMP_create_extraction_jobs.rb` | Créer | Table extraction_jobs |
| `app/models/subject.rb` | Créer | Modèle Subject + enums + validations + ActiveStorage |
| `app/models/extraction_job.rb` | Créer | Modèle ExtractionJob + enum |
| `app/models/user.rb` | Modifier | Ajouter has_many :subjects |
| `config/routes.rb` | Modifier | Ajouter resources :subjects dans namespace teacher |
| `app/controllers/teacher/subjects_controller.rb` | Créer | CRUD + publish + archive |
| `app/views/teacher/subjects/index.html.erb` | Créer | Liste sujets |
| `app/views/teacher/subjects/new.html.erb` | Créer | Formulaire upload |
| `app/views/teacher/subjects/show.html.erb` | Créer | Détail sujet + PDFs + extraction |
| `spec/factories/subjects.rb` | Créer | Factory Subject |
| `spec/factories/extraction_jobs.rb` | Créer | Factory ExtractionJob |
| `spec/models/subject_spec.rb` | Créer | Tests modèle |
| `spec/models/extraction_job_spec.rb` | Créer | Tests modèle |
| `spec/requests/teacher/subjects_spec.rb` | Créer | Tests request |

---

## Task 1 : Migration subjects

**Files:**
- Create: `db/migrate/TIMESTAMP_create_subjects.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateSubjects title:string year:string exam_type:integer specialty:integer region:integer status:integer presentation_text:text discarded_at:datetime owner:references
```

- [ ] **Step 2 : Éditer la migration générée**

```ruby
class CreateSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :subjects do |t|
      t.string   :title,             null: false
      t.string   :year,              null: false
      t.integer  :exam_type,         null: false, default: 0
      t.integer  :specialty,         null: false, default: 0
      t.integer  :region,            null: false, default: 0
      t.integer  :status,            null: false, default: 0
      t.text     :presentation_text
      t.datetime :discarded_at
      t.references :owner,           null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :subjects, :discarded_at
    add_index :subjects, :status
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateSubjects: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(subjects): create subjects migration with enums and soft delete

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Migration extraction_jobs

**Files:**
- Create: `db/migrate/TIMESTAMP_create_extraction_jobs.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateExtractionJobs status:integer raw_json:jsonb error_message:text provider_used:integer subject:references
```

- [ ] **Step 2 : Éditer la migration générée**

```ruby
class CreateExtractionJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :extraction_jobs do |t|
      t.integer    :status,        null: false, default: 0
      t.jsonb      :raw_json
      t.text       :error_message
      t.integer    :provider_used, null: false, default: 0
      t.references :subject,       null: false, foreign_key: true
      t.timestamps
    end

    add_index :extraction_jobs, :status
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateExtractionJobs: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "$(cat <<'EOF'
feat(subjects): create extraction_jobs migration

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Modèle Subject (TDD)

**Files:**
- Create: `spec/factories/subjects.rb`
- Create: `spec/models/subject_spec.rb`
- Create: `app/models/subject.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1 : Créer la factory subjects**

```ruby
# spec/factories/subjects.rb
FactoryBot.define do
  factory :subject do
    title       { "Sujet BAC STI2D #{Faker::Number.number(digits: 4)}" }
    year        { "2026" }
    exam_type   { :bac }
    specialty   { :SIN }
    region      { :metropole }
    status      { :draft }
    association :owner, factory: :user

    after(:build) do |subject|
      subject.enonce_file.attach(
        io: StringIO.new("%PDF-1.4 fake enonce"),
        filename: "enonce.pdf",
        content_type: "application/pdf"
      )
      subject.dt_file.attach(
        io: StringIO.new("%PDF-1.4 fake dt"),
        filename: "dt.pdf",
        content_type: "application/pdf"
      )
      subject.dr_vierge_file.attach(
        io: StringIO.new("%PDF-1.4 fake dr vierge"),
        filename: "dr_vierge.pdf",
        content_type: "application/pdf"
      )
      subject.dr_corrige_file.attach(
        io: StringIO.new("%PDF-1.4 fake dr corrige"),
        filename: "dr_corrige.pdf",
        content_type: "application/pdf"
      )
      subject.questions_corrigees_file.attach(
        io: StringIO.new("%PDF-1.4 fake questions corrigees"),
        filename: "questions_corrigees.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
```

- [ ] **Step 2 : Écrire les tests Subject**

```ruby
# spec/models/subject_spec.rb
require "rails_helper"

RSpec.describe Subject, type: :model do
  describe "validations" do
    it "is valid with all required attributes and files" do
      subject_obj = build(:subject)
      expect(subject_obj).to be_valid
    end

    it "requires title" do
      subject_obj = build(:subject, title: nil)
      expect(subject_obj).not_to be_valid
      expect(subject_obj.errors[:title]).to be_present
    end

    it "requires year" do
      subject_obj = build(:subject, year: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires exam_type" do
      subject_obj = build(:subject, exam_type: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires specialty" do
      subject_obj = build(:subject, specialty: nil)
      expect(subject_obj).not_to be_valid
    end

    it "requires region" do
      subject_obj = build(:subject, region: nil)
      expect(subject_obj).not_to be_valid
    end
  end

  describe "enums" do
    it "defines exam_type enum" do
      expect(Subject.exam_types).to eq("bac" => 0, "bts" => 1, "autre" => 2)
    end

    it "defines specialty enum" do
      expect(Subject.specialties).to eq(
        "tronc_commun" => 0, "SIN" => 1, "ITEC" => 2, "EC" => 3, "AC" => 4
      )
    end

    it "defines region enum" do
      expect(Subject.regions).to eq(
        "metropole" => 0, "drom_com" => 1, "polynesie" => 2, "candidat_libre" => 3
      )
    end

    it "defines status enum with draft as default" do
      subject_obj = build(:subject)
      expect(subject_obj.status).to eq("draft")
    end
  end

  describe "associations" do
    it "belongs to owner" do
      subject_obj = build(:subject)
      expect(subject_obj.owner).to be_a(User)
    end
  end

  describe "scopes" do
    it "kept excludes soft-deleted subjects" do
      kept = create(:subject)
      deleted = create(:subject, discarded_at: Time.current)
      expect(Subject.kept).to include(kept)
      expect(Subject.kept).not_to include(deleted)
    end
  end

  describe "ActiveStorage attachments" do
    it "has enonce_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.enonce_file).to be_attached
    end

    it "has dt_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dt_file).to be_attached
    end

    it "has dr_vierge_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dr_vierge_file).to be_attached
    end

    it "has dr_corrige_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.dr_corrige_file).to be_attached
    end

    it "has questions_corrigees_file attached" do
      subject_obj = create(:subject)
      expect(subject_obj.questions_corrigees_file).to be_attached
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/subject_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Subject`

- [ ] **Step 4 : Créer le modèle Subject**

```ruby
# app/models/subject.rb
class Subject < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_one :extraction_job, dependent: :destroy

  has_one_attached :enonce_file
  has_one_attached :dt_file
  has_one_attached :dr_vierge_file
  has_one_attached :dr_corrige_file
  has_one_attached :questions_corrigees_file

  enum :exam_type, { bac: 0, bts: 1, autre: 2 }
  enum :specialty, { tronc_commun: 0, SIN: 1, ITEC: 2, EC: 3, AC: 4 }
  enum :region,    { metropole: 0, drom_com: 1, polynesie: 2, candidat_libre: 3 }
  enum :status,    { draft: 0, pending_validation: 1, published: 2, archived: 3 }

  validates :title, :year, :exam_type, :specialty, :region, presence: true

  validates :enonce_file, attached: true,
    content_type: "application/pdf",
    size: { less_than: 20.megabytes }
  validates :dt_file, attached: true,
    content_type: "application/pdf",
    size: { less_than: 20.megabytes }
  validates :dr_vierge_file, attached: true,
    content_type: "application/pdf",
    size: { less_than: 20.megabytes }
  validates :dr_corrige_file, attached: true,
    content_type: "application/pdf",
    size: { less_than: 20.megabytes }
  validates :questions_corrigees_file, attached: true,
    content_type: "application/pdf",
    size: { less_than: 20.megabytes }

  scope :kept, -> { where(discarded_at: nil) }
end
```

- [ ] **Step 5 : Ajouter has_many :subjects à User**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  enum :api_provider, { anthropic: 0, openrouter: 1, openai: 2, google: 3 }

  has_many :classrooms, foreign_key: :owner_id, dependent: :destroy
  has_many :subjects,   foreign_key: :owner_id, dependent: :destroy

  validates :first_name, :last_name, presence: true
end
```

- [ ] **Step 6 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/subject_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 7 : Commit**

```bash
git add app/models/subject.rb app/models/user.rb spec/models/subject_spec.rb spec/factories/subjects.rb
git commit -m "$(cat <<'EOF'
feat(subjects): add Subject model with ActiveStorage attachments and enums

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Modèle ExtractionJob (TDD)

**Files:**
- Create: `spec/factories/extraction_jobs.rb`
- Create: `spec/models/extraction_job_spec.rb`
- Create: `app/models/extraction_job.rb`

- [ ] **Step 1 : Créer la factory**

```ruby
# spec/factories/extraction_jobs.rb
FactoryBot.define do
  factory :extraction_job do
    status       { :pending }
    provider_used { :server }
    association :subject
  end
end
```

- [ ] **Step 2 : Écrire les tests ExtractionJob**

```ruby
# spec/models/extraction_job_spec.rb
require "rails_helper"

RSpec.describe ExtractionJob, type: :model do
  describe "enums" do
    it "defines status enum with pending as default" do
      job = build(:extraction_job)
      expect(job.status).to eq("pending")
    end

    it "defines all status values" do
      expect(ExtractionJob.statuses).to eq(
        "pending" => 0, "processing" => 1, "done" => 2, "failed" => 3
      )
    end

    it "defines provider_used enum" do
      expect(ExtractionJob.provider_useds).to eq("teacher" => 0, "server" => 1)
    end
  end

  describe "associations" do
    it "belongs to subject" do
      job = build(:extraction_job)
      expect(job.subject).to be_a(Subject)
    end
  end
end
```

- [ ] **Step 3 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/models/extraction_job_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ExtractionJob`

- [ ] **Step 4 : Créer le modèle ExtractionJob**

```ruby
# app/models/extraction_job.rb
class ExtractionJob < ApplicationRecord
  belongs_to :subject

  enum :status,        { pending: 0, processing: 1, done: 2, failed: 3 }
  enum :provider_used, { teacher: 0, server: 1 }
end
```

- [ ] **Step 5 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/models/extraction_job_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 6 : Commit**

```bash
git add app/models/extraction_job.rb spec/models/extraction_job_spec.rb spec/factories/extraction_jobs.rb
git commit -m "$(cat <<'EOF'
feat(subjects): add ExtractionJob model with status and provider_used enums

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Routes + Teacher::SubjectsController + vues

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/teacher/subjects_controller.rb`
- Create: `app/views/teacher/subjects/index.html.erb`
- Create: `app/views/teacher/subjects/new.html.erb`
- Create: `app/views/teacher/subjects/show.html.erb`

- [ ] **Step 1 : Ajouter les routes subjects dans le namespace teacher**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  namespace :teacher do
    root to: "classrooms#index"

    resources :classrooms, only: [ :index, :new, :create, :show ] do
      resources :students, only: [ :index, :new, :create ] do
        collection do
          get  :bulk_new
          post :bulk_create
        end
        member do
          post :reset_password
        end
      end
      member do
        get :export_pdf
        get :export_markdown
      end
    end

    resources :subjects, only: [ :index, :new, :create, :show ] do
      member do
        patch :publish
        patch :archive
      end
    end
  end

  # Auth élève via access_code
  scope "/:access_code", as: :student do
    get    "/",        to: "student/sessions#new",     as: :login
    post   "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    get "/subjects", to: "student/subjects#index", as: :root
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 2 : Vérifier les routes**

```bash
bin/rails routes | grep "teacher.*subject"
```

Résultat attendu : `teacher_subjects`, `teacher_subject`, `publish_teacher_subject`, `archive_teacher_subject`

- [ ] **Step 3 : Créer Teacher::SubjectsController**

```ruby
# app/controllers/teacher/subjects_controller.rb
class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :publish, :archive ]

  def index
    @subjects = current_teacher.subjects.kept.order(created_at: :desc)
  end

  def new
    @subject = Subject.new
  end

  def create
    @subject = current_teacher.subjects.build(subject_params)

    if @subject.save
      @subject.create_extraction_job!(status: :pending, provider_used: :server)
      redirect_to teacher_subject_path(@subject),
                  notice: "Sujet créé. L'extraction démarrera automatiquement."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @extraction_job = @subject.extraction_job
  end

  def publish
    unless @subject.draft? || @subject.pending_validation?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Ce sujet ne peut pas être publié."
    end

    @subject.update!(status: :published)
    redirect_to teacher_subject_path(@subject), notice: "Sujet publié."
  end

  def archive
    unless @subject.published?
      return redirect_to teacher_subject_path(@subject),
                         alert: "Seul un sujet publié peut être archivé."
    end

    @subject.update!(status: :archived)
    redirect_to teacher_subject_path(@subject), notice: "Sujet archivé."
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def subject_params
    params.require(:subject).permit(
      :title, :year, :exam_type, :specialty, :region,
      :enonce_file, :dt_file, :dr_vierge_file, :dr_corrige_file, :questions_corrigees_file
    )
  end
end
```

- [ ] **Step 4 : Vue index**

```erb
<%# app/views/teacher/subjects/index.html.erb %>
<h1>Mes sujets</h1>

<%= link_to "Nouveau sujet", new_teacher_subject_path %>

<% if @subjects.empty? %>
  <p>Aucun sujet pour l'instant.</p>
<% else %>
  <table>
    <thead>
      <tr>
        <th>Titre</th>
        <th>Spécialité</th>
        <th>Région</th>
        <th>Année</th>
        <th>Statut</th>
        <th>Créé le</th>
      </tr>
    </thead>
    <tbody>
      <% @subjects.each do |subject| %>
        <tr>
          <td><%= link_to subject.title, teacher_subject_path(subject) %></td>
          <td><%= subject.specialty %></td>
          <td><%= subject.region %></td>
          <td><%= subject.year %></td>
          <td><span><%= subject.status %></span></td>
          <td><%= subject.created_at.strftime("%d/%m/%Y") %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

- [ ] **Step 5 : Vue new**

```erb
<%# app/views/teacher/subjects/new.html.erb %>
<h1>Nouveau sujet</h1>

<%= form_with model: [:teacher, @subject], multipart: true do |f| %>
  <% if @subject.errors.any? %>
    <div>
      <ul>
        <% @subject.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <h2>Informations</h2>

  <div>
    <%= f.label :title, "Titre" %>
    <%= f.text_field :title, required: true %>
  </div>

  <div>
    <%= f.label :year, "Année" %>
    <%= f.text_field :year, placeholder: "2026", required: true %>
  </div>

  <div>
    <%= f.label :exam_type, "Type d'examen" %>
    <%= f.select :exam_type, Subject.exam_types.keys.map { |k| [k.humanize, k] }, {}, required: true %>
  </div>

  <div>
    <%= f.label :specialty, "Spécialité" %>
    <%= f.select :specialty, Subject.specialties.keys.map { |k| [k, k] }, {}, required: true %>
  </div>

  <div>
    <%= f.label :region, "Région" %>
    <%= f.select :region, [
      ["Métropole", "metropole"],
      ["DROM-COM", "drom_com"],
      ["Polynésie", "polynesie"],
      ["Candidat libre", "candidat_libre"]
    ], {}, required: true %>
  </div>

  <h2>Documents PDF</h2>

  <div>
    <%= f.label :enonce_file, "Énoncé du sujet (PDF, max 20 MB)" %>
    <%= f.file_field :enonce_file, accept: "application/pdf", required: true %>
  </div>

  <div>
    <%= f.label :dt_file, "Documents Techniques — DT (PDF, max 20 MB)" %>
    <%= f.file_field :dt_file, accept: "application/pdf", required: true %>
  </div>

  <div>
    <%= f.label :dr_vierge_file, "Document Réponse vierge — DR (PDF, max 20 MB)" %>
    <%= f.file_field :dr_vierge_file, accept: "application/pdf", required: true %>
  </div>

  <div>
    <%= f.label :dr_corrige_file, "Document Réponse corrigé (PDF, max 20 MB)" %>
    <%= f.file_field :dr_corrige_file, accept: "application/pdf", required: true %>
  </div>

  <div>
    <%= f.label :questions_corrigees_file, "Questions corrigées (PDF, max 20 MB)" %>
    <%= f.file_field :questions_corrigees_file, accept: "application/pdf", required: true %>
  </div>

  <%= f.submit "Créer le sujet" %>
<% end %>
```

- [ ] **Step 6 : Vue show**

```erb
<%# app/views/teacher/subjects/show.html.erb %>
<h1><%= @subject.title %></h1>

<p>
  Spécialité : <%= @subject.specialty %> |
  Région : <%= @subject.region %> |
  Année : <%= @subject.year %> |
  Type : <%= @subject.exam_type %> |
  Statut : <strong><%= @subject.status %></strong>
</p>

<h2>Documents PDF</h2>
<ul>
  <% if @subject.enonce_file.attached? %>
    <li><%= link_to "Énoncé", rails_blob_path(@subject.enonce_file, disposition: "attachment") %></li>
  <% end %>
  <% if @subject.dt_file.attached? %>
    <li><%= link_to "Documents Techniques (DT)", rails_blob_path(@subject.dt_file, disposition: "attachment") %></li>
  <% end %>
  <% if @subject.dr_vierge_file.attached? %>
    <li><%= link_to "Document Réponse vierge", rails_blob_path(@subject.dr_vierge_file, disposition: "attachment") %></li>
  <% end %>
  <% if @subject.dr_corrige_file.attached? %>
    <li><%= link_to "Document Réponse corrigé", rails_blob_path(@subject.dr_corrige_file, disposition: "attachment") %></li>
  <% end %>
  <% if @subject.questions_corrigees_file.attached? %>
    <li><%= link_to "Questions corrigées", rails_blob_path(@subject.questions_corrigees_file, disposition: "attachment") %></li>
  <% end %>
</ul>

<h2>Extraction</h2>
<% if @extraction_job %>
  <p>Statut : <strong><%= @extraction_job.status %></strong></p>
  <% if @extraction_job.failed? %>
    <p style="color: red;">Erreur : <%= @extraction_job.error_message %></p>
  <% end %>
<% else %>
  <p>Aucun job d'extraction.</p>
<% end %>

<div>
  <% if @subject.pending_validation? %>
    <%= button_to "Publier", publish_teacher_subject_path(@subject), method: :patch %>
  <% end %>
  <% if @subject.published? %>
    <%= button_to "Archiver", archive_teacher_subject_path(@subject), method: :patch %>
  <% end %>
</div>

<%= link_to "Retour aux sujets", teacher_subjects_path %>
```

- [ ] **Step 7 : Commit**

```bash
git add config/routes.rb app/controllers/teacher/subjects_controller.rb app/views/teacher/subjects/
git commit -m "$(cat <<'EOF'
feat(subjects): add SubjectsController with CRUD, publish and archive actions

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Request specs Teacher::Subjects

**Files:**
- Create: `spec/requests/teacher/subjects_spec.rb`

- [ ] **Step 1 : Créer les specs**

```ruby
# spec/requests/teacher/subjects_spec.rb
require "rails_helper"

RSpec.describe "Teacher::Subjects", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before { sign_in user }

  describe "GET /teacher/subjects" do
    it "returns 200" do
      get teacher_subjects_path
      expect(response).to have_http_status(:ok)
    end

    it "only shows subjects owned by current teacher" do
      own_subject = create(:subject, owner: user)
      other_subject = create(:subject)
      get teacher_subjects_path
      expect(response.body).to include(own_subject.title)
      expect(response.body).not_to include(other_subject.title)
    end
  end

  describe "GET /teacher/subjects/new" do
    it "returns 200" do
      get new_teacher_subject_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/subjects" do
    def pdf_upload(filename)
      Rack::Test::UploadedFile.new(
        StringIO.new("%PDF-1.4 fake content"),
        "application/pdf",
        original_filename: filename
      )
    end

    let(:valid_params) do
      {
        subject: {
          title: "Sujet SIN 2026",
          year: "2026",
          exam_type: "bac",
          specialty: "SIN",
          region: "metropole",
          enonce_file: pdf_upload("enonce.pdf"),
          dt_file: pdf_upload("dt.pdf"),
          dr_vierge_file: pdf_upload("dr_vierge.pdf"),
          dr_corrige_file: pdf_upload("dr_corrige.pdf"),
          questions_corrigees_file: pdf_upload("questions_corrigees.pdf")
        }
      }
    end

    it "creates a subject and an extraction job" do
      expect {
        post teacher_subjects_path, params: valid_params
      }.to change(Subject, :count).by(1).and change(ExtractionJob, :count).by(1)
      expect(response).to redirect_to(teacher_subject_path(Subject.last))
    end

    it "does not create subject with missing files" do
      expect {
        post teacher_subjects_path, params: {
          subject: { title: "Test", year: "2026", exam_type: "bac", specialty: "SIN", region: "metropole" }
        }
      }.not_to change(Subject, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /teacher/subjects/:id" do
    let(:subject) { create(:subject, owner: user) }

    it "returns 200" do
      get teacher_subject_path(subject)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for subject owned by another teacher" do
      other_subject = create(:subject)
      get teacher_subject_path(other_subject)
      expect(response).to redirect_to(teacher_subjects_path)
    end
  end

  describe "PATCH /teacher/subjects/:id/publish" do
    it "publishes a pending_validation subject" do
      subject = create(:subject, owner: user, status: :pending_validation)
      patch publish_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("published")
    end

    it "does not publish an archived subject" do
      subject = create(:subject, owner: user, status: :archived)
      patch publish_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("archived")
    end
  end

  describe "PATCH /teacher/subjects/:id/archive" do
    it "archives a published subject" do
      subject = create(:subject, owner: user, status: :published)
      patch archive_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("archived")
    end

    it "does not archive a draft subject" do
      subject = create(:subject, owner: user, status: :draft)
      patch archive_teacher_subject_path(subject)
      expect(subject.reload.status).to eq("draft")
    end
  end
end
```

- [ ] **Step 2 : Lancer les specs**

```bash
bundle exec rspec spec/requests/teacher/subjects_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 3 : Commit**

```bash
git add spec/requests/teacher/subjects_spec.rb
git commit -m "$(cat <<'EOF'
test(subjects): add request specs for teacher subjects controller

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Smoke test final

- [ ] **Step 1 : Lancer toute la suite RSpec**

```bash
bundle exec rspec spec/models/ spec/requests/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes subjects**

```bash
bin/rails routes | grep "teacher.*subject"
```

Résultat attendu : `teacher_subjects`, `teacher_subject`, `new_teacher_subject`, `publish_teacher_subject`, `archive_teacher_subject`

- [ ] **Step 3 : Vérifier rubocop**

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
chore: finalize subject upload implementation

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

# Teacher Classroom & Student Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter l'interface enseignant complète : CRUD classes, gestion élèves, Devise confirmable avec Resend, export PDF/Markdown des fiches de connexion.

**Architecture:** Namespace `teacher/` avec `Teacher::BaseController` (Devise auth + confirmed check), controllers classrooms et students, trois services export/reset, vues Hotwire/Turbo. Mots de passe en clair affichés une seule fois via `session[:generated_credentials]`.

**Tech Stack:** Rails 8.1, Devise :confirmable, letter_opener (dev), Resend SMTP (prod), Prawn + prawn-table, RSpec + FactoryBot

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `Gemfile` | Modifier | Ajouter letter_opener, prawn, prawn-table |
| `db/migrate/TIMESTAMP_add_confirmable_to_users.rb` | Créer | Colonnes Devise confirmable |
| `app/models/user.rb` | Modifier | Ajouter :confirmable |
| `config/environments/development.rb` | Modifier | letter_opener + mailer config |
| `config/environments/production.rb` | Modifier | Resend SMTP config |
| `config/routes.rb` | Modifier | Namespace teacher |
| `app/controllers/teacher/base_controller.rb` | Créer | Auth guard + confirmed check |
| `app/controllers/teacher/classrooms_controller.rb` | Créer | CRUD + exports |
| `app/controllers/teacher/students_controller.rb` | Créer | CRUD + bulk + reset |
| `app/views/layouts/teacher.html.erb` | Créer | Layout nav enseignant |
| `app/views/teacher/classrooms/index.html.erb` | Créer | Liste classes |
| `app/views/teacher/classrooms/new.html.erb` | Créer | Formulaire nouvelle classe |
| `app/views/teacher/classrooms/show.html.erb` | Créer | Détail classe + élèves |
| `app/views/teacher/students/new.html.erb` | Créer | Formulaire nouvel élève |
| `app/views/teacher/students/bulk_new.html.erb` | Créer | Formulaire masse |
| `app/views/teacher/students/_credentials.html.erb` | Créer | Partial credentials (1 seule fois) |
| `app/services/reset_student_password.rb` | Créer | Reset password élève |
| `app/services/export_student_credentials_pdf.rb` | Créer | PDF Prawn A4 |
| `app/services/export_student_credentials_markdown.rb` | Créer | Export Markdown |
| `spec/services/reset_student_password_spec.rb` | Créer | Tests service |
| `spec/services/export_student_credentials_pdf_spec.rb` | Créer | Tests service |
| `spec/services/export_student_credentials_markdown_spec.rb` | Créer | Tests service |
| `spec/requests/teacher/classrooms_spec.rb` | Créer | Tests request |
| `spec/requests/teacher/students_spec.rb` | Créer | Tests request |

---

## Task 1 : Gems letter_opener, prawn, prawn-table

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1 : Ajouter letter_opener**

```ruby
# Dans group :development (après gem "web-console")
gem "letter_opener"
```

- [ ] **Step 2 : Installer**

```bash
bundle install
```

Résultat attendu : `Installing letter_opener`

- [ ] **Step 3 : Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "$(cat <<'EOF'
chore(install): letter_opener to preview emails in browser during development

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4 : Ajouter prawn**

```ruby
# Dans le bloc principal du Gemfile (après faraday-multipart)
gem "prawn"
```

- [ ] **Step 5 : Installer**

```bash
bundle install
```

- [ ] **Step 6 : Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "$(cat <<'EOF'
chore(install): prawn to generate PDF login credential sheets for students

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7 : Ajouter prawn-table**

```ruby
# Dans le bloc principal du Gemfile (après gem "prawn")
gem "prawn-table"
```

- [ ] **Step 8 : Installer**

```bash
bundle install
```

- [ ] **Step 9 : Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "$(cat <<'EOF'
chore(install): prawn-table to render tables in PDF credential sheets

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Devise Confirmable — migration + modèle + mailer config

**Files:**
- Create: `db/migrate/TIMESTAMP_add_confirmable_to_users.rb`
- Modify: `app/models/user.rb`
- Modify: `config/environments/development.rb`
- Modify: `config/environments/production.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration AddConfirmableToUsers confirmation_token:string confirmed_at:datetime confirmation_sent_at:datetime unconfirmed_email:string
```

- [ ] **Step 2 : Éditer la migration pour ajouter l'index**

```ruby
class AddConfirmableToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `AddConfirmableToUsers: migrated`

- [ ] **Step 4 : Activer :confirmable dans User**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  enum :api_provider, { anthropic: 0, openrouter: 1, openai: 2, google: 3 }

  validates :first_name, :last_name, presence: true
end
```

- [ ] **Step 5 : Configurer letter_opener en développement**

Ajouter dans `config/environments/development.rb` après la ligne `config.action_mailer.default_url_options`:

```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

- [ ] **Step 6 : Configurer Resend en production**

Ajouter dans `config/environments/production.rb` :

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.resend.com",
  port: 587,
  user_name: "resend",
  password: Rails.application.credentials.resend_api_key
}
config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost") }
```

- [ ] **Step 7 : Commit**

```bash
git add db/migrate/ db/schema.rb app/models/user.rb config/environments/
git commit -m "$(cat <<'EOF'
feat(auth): add Devise confirmable with letter_opener (dev) and Resend SMTP (prod)

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Routes namespace teacher + Teacher::BaseController

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/teacher/base_controller.rb`

- [ ] **Step 1 : Ajouter le namespace teacher dans routes.rb**

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
bin/rails routes | grep teacher
```

Résultat attendu : routes `teacher_root`, `teacher_classrooms`, `teacher_classroom_students`, etc.

- [ ] **Step 3 : Créer Teacher::BaseController**

```ruby
# app/controllers/teacher/base_controller.rb
class Teacher::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_confirmed!

  helper_method :current_teacher

  private

  def current_teacher
    current_user
  end

  def require_confirmed!
    return if current_user.confirmed?

    sign_out current_user
    redirect_to new_user_session_path,
                alert: "Veuillez confirmer votre adresse email avant de vous connecter."
  end
end
```

- [ ] **Step 4 : Commit**

```bash
git add config/routes.rb app/controllers/teacher/base_controller.rb
git commit -m "$(cat <<'EOF'
feat(teacher): add teacher namespace routes and BaseController with confirmed? guard

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Teacher::ClassroomsController + vues

**Files:**
- Create: `app/controllers/teacher/classrooms_controller.rb`
- Create: `app/views/layouts/teacher.html.erb`
- Create: `app/views/teacher/classrooms/index.html.erb`
- Create: `app/views/teacher/classrooms/new.html.erb`
- Create: `app/views/teacher/classrooms/show.html.erb`

- [ ] **Step 1 : Créer le controller**

```ruby
# app/controllers/teacher/classrooms_controller.rb
class Teacher::ClassroomsController < Teacher::BaseController
  before_action :set_classroom, only: [ :show, :export_pdf, :export_markdown ]

  def index
    @classrooms = current_teacher.classrooms.order(created_at: :desc)
  end

  def new
    @classroom = Classroom.new
  end

  def create
    access_code = GenerateAccessCode.call(
      specialty: classroom_params[:specialty],
      school_year: classroom_params[:school_year]
    )
    @classroom = current_teacher.classrooms.build(classroom_params.merge(access_code: access_code))

    if @classroom.save
      redirect_to teacher_classroom_path(@classroom),
                  notice: "Classe créée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @students = @classroom.students.order(:last_name, :first_name)
    @generated_credentials = session.delete(:generated_credentials)
  end

  def export_pdf
    pdf = ExportStudentCredentialsPdf.call(classroom: @classroom)
    send_data pdf.render,
              filename: "fiches-connexion-#{@classroom.access_code}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def export_markdown
    markdown = ExportStudentCredentialsMarkdown.call(classroom: @classroom)
    send_data markdown,
              filename: "fiches-connexion-#{@classroom.access_code}.md",
              type: "text/markdown",
              disposition: "attachment"
  end

  private

  def set_classroom
    @classroom = current_teacher.classrooms.find_by(id: params[:id])
    redirect_to teacher_root_path, alert: "Classe introuvable." unless @classroom
  end

  def classroom_params
    params.require(:classroom).permit(:name, :school_year, :specialty)
  end
end
```

- [ ] **Step 2 : Ajouter `classrooms` association à User**

```ruby
# app/models/user.rb
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  enum :api_provider, { anthropic: 0, openrouter: 1, openai: 2, google: 3 }

  has_many :classrooms, foreign_key: :owner_id, dependent: :destroy

  validates :first_name, :last_name, presence: true
end
```

- [ ] **Step 3 : Créer le layout teacher**

```erb
<%# app/views/layouts/teacher.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <title>DekatjeBakLa — Espace enseignant</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body>
    <nav>
      <strong>DekatjeBakLa</strong>
      <%= link_to "Mes classes", teacher_root_path %>
      <%= link_to "Déconnexion", destroy_user_session_path, data: { turbo_method: :delete } %>
    </nav>

    <% if notice %>
      <p style="color: green;"><%= notice %></p>
    <% end %>
    <% if alert %>
      <p style="color: red;"><%= alert %></p>
    <% end %>

    <%= yield %>
  </body>
</html>
```

- [ ] **Step 4 : Vue index**

```erb
<%# app/views/teacher/classrooms/index.html.erb %>
<h1>Mes classes</h1>

<%= link_to "Nouvelle classe", new_teacher_classroom_path %>

<% if @classrooms.empty? %>
  <p>Vous n'avez pas encore de classe.</p>
<% else %>
  <ul>
    <% @classrooms.each do |classroom| %>
      <li>
        <%= link_to classroom.name, teacher_classroom_path(classroom) %>
        — <%= classroom.school_year %>
        (<%= classroom.students.count %> élèves)
      </li>
    <% end %>
  </ul>
<% end %>
```

- [ ] **Step 5 : Vue new**

```erb
<%# app/views/teacher/classrooms/new.html.erb %>
<h1>Nouvelle classe</h1>

<%= form_with model: [:teacher, @classroom] do |f| %>
  <div>
    <%= f.label :name, "Nom de la classe" %>
    <%= f.text_field :name, required: true %>
  </div>

  <div>
    <%= f.label :school_year, "Année scolaire" %>
    <%= f.text_field :school_year, placeholder: "2026", required: true %>
  </div>

  <div>
    <%= f.label :specialty, "Spécialité" %>
    <%= f.text_field :specialty, placeholder: "SIN, ITEC, EC..." %>
  </div>

  <%= f.submit "Créer la classe" %>
<% end %>
```

- [ ] **Step 6 : Vue show**

```erb
<%# app/views/teacher/classrooms/show.html.erb %>
<h1><%= @classroom.name %></h1>
<p>Année : <%= @classroom.school_year %> | Spécialité : <%= @classroom.specialty %></p>
<p>Code d'accès élèves : <strong><%= @classroom.access_code %></strong></p>

<p>
  <%= link_to "Ajouter un élève", new_teacher_classroom_student_path(@classroom) %> |
  <%= link_to "Ajouter en masse", bulk_new_teacher_classroom_students_path(@classroom) %> |
  <%= link_to "Export PDF", export_pdf_teacher_classroom_path(@classroom) %> |
  <%= link_to "Export Markdown", export_markdown_teacher_classroom_path(@classroom) %>
</p>

<% if @generated_credentials.present? %>
  <div id="generated-credentials">
    <h2>Identifiants générés — à noter maintenant !</h2>
    <table>
      <thead><tr><th>Nom</th><th>Identifiant</th><th>Mot de passe</th></tr></thead>
      <tbody>
        <% @generated_credentials.each do |cred| %>
          <tr>
            <td><%= cred["name"] %></td>
            <td><%= cred["username"] %></td>
            <td><%= cred["password"] %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
<% end %>

<h2>Élèves (<%= @students.count %>)</h2>
<% if @students.empty? %>
  <p>Aucun élève dans cette classe.</p>
<% else %>
  <table id="students-table">
    <thead><tr><th>Nom</th><th>Identifiant</th><th>Actions</th></tr></thead>
    <tbody>
      <% @students.each do |student| %>
        <tr id="student-<%= student.id %>">
          <td><%= student.last_name %> <%= student.first_name %></td>
          <td><%= student.username %></td>
          <td>
            <%= button_to "Réinitialiser mot de passe",
                reset_password_teacher_classroom_student_path(@classroom, student),
                method: :post,
                data: { confirm: "Réinitialiser le mot de passe de #{student.first_name} #{student.last_name} ?" } %>
          </td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

- [ ] **Step 7 : Commit**

```bash
git add app/controllers/teacher/classrooms_controller.rb app/models/user.rb app/views/layouts/teacher.html.erb app/views/teacher/
git commit -m "$(cat <<'EOF'
feat(teacher): add ClassroomsController with CRUD, export actions and views

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Teacher::StudentsController + vues

**Files:**
- Create: `app/controllers/teacher/students_controller.rb`
- Create: `app/views/teacher/students/new.html.erb`
- Create: `app/views/teacher/students/bulk_new.html.erb`

- [ ] **Step 1 : Créer le controller**

```ruby
# app/controllers/teacher/students_controller.rb
class Teacher::StudentsController < Teacher::BaseController
  before_action :set_classroom
  before_action :set_student, only: [ :reset_password ]

  def new
    @student = Student.new
  end

  def create
    credentials = GenerateStudentCredentials.call(
      first_name: student_params[:first_name],
      last_name: student_params[:last_name],
      classroom: @classroom
    )

    student = @classroom.students.build(
      first_name: student_params[:first_name],
      last_name: student_params[:last_name],
      username: credentials[:username],
      password: credentials[:password]
    )

    if student.save
      session[:generated_credentials] = [
        { "name" => "#{student.first_name} #{student.last_name}",
          "username" => credentials[:username],
          "password" => credentials[:password] }
      ]
      redirect_to teacher_classroom_path(@classroom),
                  notice: "Élève ajouté. Notez les identifiants ci-dessous."
    else
      @student = student
      render :new, status: :unprocessable_entity
    end
  end

  def bulk_new
  end

  def bulk_create
    lines = params[:students_list].to_s.split("\n").map(&:strip).reject(&:empty?)
    generated = []
    errors = []

    lines.each do |line|
      parts = line.split(" ", 2)
      if parts.length < 2
        errors << "Ligne ignorée (format invalide) : #{line}"
        next
      end

      first_name, last_name = parts[0], parts[1]
      credentials = GenerateStudentCredentials.call(
        first_name: first_name,
        last_name: last_name,
        classroom: @classroom
      )

      student = @classroom.students.build(
        first_name: first_name,
        last_name: last_name,
        username: credentials[:username],
        password: credentials[:password]
      )

      if student.save
        generated << { "name" => "#{first_name} #{last_name}",
                       "username" => credentials[:username],
                       "password" => credentials[:password] }
      else
        errors << "Erreur pour #{line} : #{student.errors.full_messages.join(", ")}"
      end
    end

    session[:generated_credentials] = generated if generated.any?

    if errors.any?
      flash[:alert] = errors.join(" | ")
    else
      flash[:notice] = "#{generated.count} élèves ajoutés. Notez les identifiants ci-dessous."
    end

    redirect_to teacher_classroom_path(@classroom)
  end

  def reset_password
    result = ResetStudentPassword.call(student: @student)
    session[:generated_credentials] = [
      { "name" => "#{@student.first_name} #{@student.last_name}",
        "username" => @student.username,
        "password" => result[:password] }
    ]
    redirect_to teacher_classroom_path(@classroom),
                notice: "Mot de passe réinitialisé. Notez le nouveau mot de passe ci-dessous."
  end

  private

  def set_classroom
    @classroom = current_teacher.classrooms.find_by(id: params[:classroom_id])
    redirect_to teacher_root_path, alert: "Classe introuvable." unless @classroom
  end

  def set_student
    @student = @classroom.students.find_by(id: params[:id])
    redirect_to teacher_classroom_path(@classroom), alert: "Élève introuvable." unless @student
  end

  def student_params
    params.require(:student).permit(:first_name, :last_name)
  end
end
```

- [ ] **Step 2 : Vue new**

```erb
<%# app/views/teacher/students/new.html.erb %>
<h1>Ajouter un élève — <%= @classroom.name %></h1>

<%= form_with model: [:teacher, @classroom, @student] do |f| %>
  <div>
    <%= f.label :first_name, "Prénom" %>
    <%= f.text_field :first_name, required: true %>
  </div>

  <div>
    <%= f.label :last_name, "Nom" %>
    <%= f.text_field :last_name, required: true %>
  </div>

  <%= f.submit "Ajouter l'élève" %>
<% end %>

<%= link_to "Retour à la classe", teacher_classroom_path(@classroom) %>
```

- [ ] **Step 3 : Vue bulk_new**

```erb
<%# app/views/teacher/students/bulk_new.html.erb %>
<h1>Ajouter des élèves en masse — <%= @classroom.name %></h1>

<p>Saisissez un élève par ligne, au format : <strong>Prénom Nom</strong></p>

<%= form_with url: bulk_create_teacher_classroom_students_path(@classroom), method: :post do |f| %>
  <div>
    <%= f.label :students_list, "Liste des élèves" %>
    <%= f.text_area :students_list,
        rows: 15,
        cols: 40,
        placeholder: "Jean Dupont\nMarie Martin\nPaul Bernard" %>
  </div>

  <%= f.submit "Créer les comptes" %>
<% end %>

<%= link_to "Retour à la classe", teacher_classroom_path(@classroom) %>
```

- [ ] **Step 4 : Commit**

```bash
git add app/controllers/teacher/students_controller.rb app/views/teacher/students/
git commit -m "$(cat <<'EOF'
feat(teacher): add StudentsController with create, bulk_create and reset_password actions

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Service ResetStudentPassword (TDD)

**Files:**
- Create: `spec/services/reset_student_password_spec.rb`
- Create: `app/services/reset_student_password.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/reset_student_password_spec.rb
require "rails_helper"

RSpec.describe ResetStudentPassword do
  let(:classroom) { create(:classroom) }
  let(:student) { create(:student, classroom: classroom, password: "oldpassword") }

  describe ".call" do
    it "returns a new password" do
      result = described_class.call(student: student)
      expect(result[:password]).to be_present
      expect(result[:password].length).to eq(8)
    end

    it "updates the student password" do
      result = described_class.call(student: student)
      student.reload
      expect(student.authenticate(result[:password])).to eq(student)
    end

    it "invalidates the old password" do
      described_class.call(student: student)
      student.reload
      expect(student.authenticate("oldpassword")).to be_falsey
    end

    it "returns password with only unambiguous alphanumeric characters" do
      result = described_class.call(student: student)
      expect(result[:password]).to match(/\A[a-km-np-z2-9]+\z/)
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/reset_student_password_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ResetStudentPassword`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/reset_student_password.rb
class ResetStudentPassword
  CHARSET = GenerateStudentCredentials::CHARSET

  def self.call(student:)
    password = Array.new(8) { CHARSET.sample }.join
    student.update!(password: password)
    { password: password }
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/reset_student_password_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/reset_student_password.rb spec/services/reset_student_password_spec.rb
git commit -m "$(cat <<'EOF'
feat(teacher): add ResetStudentPassword service

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Service ExportStudentCredentialsMarkdown (TDD)

**Files:**
- Create: `spec/services/export_student_credentials_markdown_spec.rb`
- Create: `app/services/export_student_credentials_markdown.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/export_student_credentials_markdown_spec.rb
require "rails_helper"

RSpec.describe ExportStudentCredentialsMarkdown do
  let(:owner) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN", school_year: "2026", access_code: "terminale-sin-2026", owner: owner) }

  before do
    create(:student, first_name: "Jean", last_name: "Dupont", username: "jean.dupont", classroom: classroom)
    create(:student, first_name: "Marie", last_name: "Martin", username: "marie.martin", classroom: classroom)
  end

  describe ".call" do
    subject(:result) { described_class.call(classroom: classroom) }

    it "returns a string" do
      expect(result).to be_a(String)
    end

    it "includes the classroom name" do
      expect(result).to include("Terminale SIN")
    end

    it "includes the access code URL" do
      expect(result).to include("terminale-sin-2026")
    end

    it "includes a markdown table header" do
      expect(result).to include("| Nom | Identifiant | Mot de passe |")
    end

    it "includes all student usernames" do
      expect(result).to include("jean.dupont")
      expect(result).to include("marie.martin")
    end

    it "includes student full names" do
      expect(result).to include("Dupont Jean")
      expect(result).to include("Martin Marie")
    end

    it "marks password column as to distribute" do
      expect(result).to include("_(à distribuer)_")
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/export_student_credentials_markdown_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ExportStudentCredentialsMarkdown`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/export_student_credentials_markdown.rb
class ExportStudentCredentialsMarkdown
  def self.call(classroom:)
    students = classroom.students.order(:last_name, :first_name)

    lines = []
    lines << "# Classe : #{classroom.name} #{classroom.school_year}"
    lines << "# Code d'accès : /#{classroom.access_code}"
    lines << ""
    lines << "| Nom | Identifiant | Mot de passe |"
    lines << "|-----|-------------|--------------|"

    students.each do |student|
      lines << "| #{student.last_name} #{student.first_name} | #{student.username} | _(à distribuer)_ |"
    end

    lines.join("\n")
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/export_student_credentials_markdown_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/export_student_credentials_markdown.rb spec/services/export_student_credentials_markdown_spec.rb
git commit -m "$(cat <<'EOF'
feat(teacher): add ExportStudentCredentialsMarkdown service

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8 : Service ExportStudentCredentialsPdf (TDD)

**Files:**
- Create: `spec/services/export_student_credentials_pdf_spec.rb`
- Create: `app/services/export_student_credentials_pdf.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/export_student_credentials_pdf_spec.rb
require "rails_helper"

RSpec.describe ExportStudentCredentialsPdf do
  let(:owner) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN", school_year: "2026", access_code: "terminale-sin-2026", owner: owner) }

  before do
    create(:student, first_name: "Jean", last_name: "Dupont", username: "jean.dupont", classroom: classroom)
  end

  describe ".call" do
    subject(:result) { described_class.call(classroom: classroom) }

    it "returns a Prawn::Document" do
      expect(result).to be_a(Prawn::Document)
    end

    it "can render to binary string" do
      expect(result.render).to be_a(String)
      expect(result.render.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "produces a non-empty PDF" do
      expect(result.render.length).to be > 1000
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/export_student_credentials_pdf_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant ExportStudentCredentialsPdf`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/export_student_credentials_pdf.rb
require "prawn"
require "prawn/table"

class ExportStudentCredentialsPdf
  def self.call(classroom:)
    students = classroom.students.order(:last_name, :first_name)

    Prawn::Document.new(page_size: "A4") do |pdf|
      pdf.font_size 12

      pdf.text "Classe : #{classroom.name} #{classroom.school_year}", size: 16, style: :bold
      pdf.text "Code d'accès élèves : /#{classroom.access_code}"
      pdf.move_down 10

      table_data = [ [ "Nom", "Identifiant", "Mot de passe" ] ]
      students.each do |student|
        table_data << [ "#{student.last_name} #{student.first_name}", student.username, "" ]
      end

      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = "DDDDDD"
        self.cell_style = { padding: [ 6, 8 ] }
      end
    end
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/export_student_credentials_pdf_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/export_student_credentials_pdf.rb spec/services/export_student_credentials_pdf_spec.rb
git commit -m "$(cat <<'EOF'
feat(teacher): add ExportStudentCredentialsPdf service with Prawn A4 table

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9 : Tests request controllers teacher

**Files:**
- Create: `spec/requests/teacher/classrooms_spec.rb`
- Create: `spec/requests/teacher/students_spec.rb`

- [ ] **Step 1 : Créer spec/requests/teacher/classrooms_spec.rb**

```ruby
# spec/requests/teacher/classrooms_spec.rb
require "rails_helper"

RSpec.describe "Teacher::Classrooms", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before { sign_in user }

  describe "GET /teacher" do
    it "returns 200" do
      get teacher_root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /teacher/classrooms/new" do
    it "returns 200" do
      get new_teacher_classroom_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms" do
    it "creates a classroom and redirects" do
      expect {
        post teacher_classrooms_path, params: { classroom: { name: "Terminale SIN", school_year: "2026", specialty: "SIN" } }
      }.to change(Classroom, :count).by(1)
      expect(response).to redirect_to(teacher_classroom_path(Classroom.last))
    end
  end

  describe "GET /teacher/classrooms/:id" do
    let(:classroom) { create(:classroom, owner: user) }

    it "returns 200" do
      get teacher_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
    end

    it "returns 302 for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      get teacher_classroom_path(other_classroom)
      expect(response).to redirect_to(teacher_root_path)
    end
  end

  describe "unauthenticated" do
    before { sign_out user }

    it "redirects to login" do
      get teacher_root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "unconfirmed user" do
    let(:unconfirmed) { create(:user, confirmed_at: nil) }
    before { sign_in unconfirmed }

    it "redirects to login with alert" do
      get teacher_root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

- [ ] **Step 2 : Créer spec/requests/teacher/students_spec.rb**

```ruby
# spec/requests/teacher/students_spec.rb
require "rails_helper"

RSpec.describe "Teacher::Students", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:classroom) { create(:classroom, owner: user) }

  before { sign_in user }

  describe "GET /teacher/classrooms/:id/students/new" do
    it "returns 200" do
      get new_teacher_classroom_student_path(classroom)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms/:id/students" do
    it "creates a student and redirects" do
      expect {
        post teacher_classroom_students_path(classroom),
             params: { student: { first_name: "Jean", last_name: "Dupont" } }
      }.to change(Student, :count).by(1)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end
  end

  describe "GET /teacher/classrooms/:id/students/bulk_new" do
    it "returns 200" do
      get bulk_new_teacher_classroom_students_path(classroom)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /teacher/classrooms/:id/students/bulk_create" do
    it "creates multiple students" do
      expect {
        post bulk_create_teacher_classroom_students_path(classroom),
             params: { students_list: "Jean Dupont\nMarie Martin" }
      }.to change(Student, :count).by(2)
    end
  end

  describe "POST /teacher/classrooms/:id/students/:id/reset_password" do
    let(:student) { create(:student, classroom: classroom) }

    it "resets password and redirects" do
      post reset_password_teacher_classroom_student_path(classroom, student)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end
  end
end
```

- [ ] **Step 3 : Lancer tous les tests request**

```bash
bundle exec rspec spec/requests/teacher/
```

Résultat attendu : tous PASS

- [ ] **Step 4 : Commit**

```bash
git add spec/requests/
git commit -m "$(cat <<'EOF'
test(teacher): add request specs for classrooms and students controllers

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10 : Smoke test final

- [ ] **Step 1 : Lancer toute la suite RSpec**

```bash
bundle exec rspec spec/models/ spec/services/ spec/requests/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier les routes teacher**

```bash
bin/rails routes | grep teacher
```

Résultat attendu : `teacher_root`, `teacher_classrooms`, `teacher_classroom_students`, `bulk_new_teacher_classroom_students`, `reset_password_teacher_classroom_student`, `export_pdf_teacher_classroom`, `export_markdown_teacher_classroom`

- [ ] **Step 3 : Commit final si tout passe**

```bash
git status
# S'il reste des fichiers non commités :
git add .
git commit -m "$(cat <<'EOF'
chore: finalize teacher classroom management implementation

Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

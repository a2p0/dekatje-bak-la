# Classroom + Student + Auth élève Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter les modèles Classroom et Student avec auth élève custom bcrypt via `/{access_code}`.

**Architecture:** Deux migrations indépendantes (classrooms, students) avec modèles ActiveRecord. Trois services (GenerateAccessCode, GenerateStudentCredentials, AuthenticateStudent). Un namespace student avec BaseController et SessionsController.

**Tech Stack:** Rails 8.1, bcrypt (has_secure_password), RSpec + FactoryBot, Faker

---

## Fichiers créés/modifiés

| Fichier | Action | Responsabilité |
|---------|--------|----------------|
| `db/migrate/XXXXXX_create_classrooms.rb` | Créer | Table classrooms |
| `db/migrate/XXXXXX_create_students.rb` | Créer | Table students |
| `app/models/classroom.rb` | Créer | Modèle Classroom |
| `app/models/student.rb` | Créer | Modèle Student + has_secure_password |
| `app/services/generate_access_code.rb` | Créer | Génération slug access_code |
| `app/services/generate_student_credentials.rb` | Créer | Génération username + password |
| `app/services/authenticate_student.rb` | Créer | Auth bcrypt élève |
| `app/controllers/student/base_controller.rb` | Créer | current_student, before_actions |
| `app/controllers/student/sessions_controller.rb` | Créer | Login/logout élève |
| `app/views/student/sessions/new.html.erb` | Créer | Formulaire login |
| `config/routes.rb` | Modifier | Routes student auth |
| `spec/factories/users.rb` | Modifier | Factory User complète |
| `spec/factories/classrooms.rb` | Créer | Factory Classroom |
| `spec/factories/students.rb` | Créer | Factory Student |
| `spec/models/classroom_spec.rb` | Créer | Tests modèle Classroom |
| `spec/models/student_spec.rb` | Créer | Tests modèle Student |
| `spec/services/generate_access_code_spec.rb` | Créer | Tests service |
| `spec/services/generate_student_credentials_spec.rb` | Créer | Tests service |
| `spec/services/authenticate_student_spec.rb` | Créer | Tests service |

---

## Task 1 : Migration Classroom

**Files:**
- Create: `db/migrate/TIMESTAMP_create_classrooms.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateClassrooms name:string school_year:string specialty:string access_code:string owner:references
```

- [ ] **Step 2 : Éditer la migration générée** pour ajouter les contraintes

```ruby
class CreateClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :classrooms do |t|
      t.string :name, null: false
      t.string :school_year, null: false
      t.string :specialty
      t.string :access_code, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :classrooms, :access_code, unique: true
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateClassrooms: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "chore(install): create classrooms migration with access_code unique index"
```

---

## Task 2 : Migration Student

**Files:**
- Create: `db/migrate/TIMESTAMP_create_students.rb`

- [ ] **Step 1 : Générer la migration**

```bash
bin/rails generate migration CreateStudents first_name:string last_name:string username:string password_digest:string encrypted_api_key:string encrypted_api_key_iv:string api_provider:integer classroom:references
```

- [ ] **Step 2 : Éditer la migration générée**

```ruby
class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :username, null: false
      t.string :password_digest, null: false
      t.string :encrypted_api_key
      t.string :encrypted_api_key_iv
      t.integer :api_provider, null: false, default: 0
      t.references :classroom, null: false, foreign_key: true
      t.timestamps
    end

    add_index :students, [:username, :classroom_id], unique: true
  end
end
```

- [ ] **Step 3 : Lancer la migration**

```bash
bin/rails db:migrate
```

Résultat attendu : `CreateStudents: migrated`

- [ ] **Step 4 : Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "chore(install): create students migration with composite unique index username+classroom"
```

---

## Task 3 : Factories + Modèle Classroom (TDD)

**Files:**
- Modify: `spec/factories/users.rb`
- Create: `spec/factories/classrooms.rb`
- Create: `spec/models/classroom_spec.rb`
- Create: `app/models/classroom.rb`

- [ ] **Step 1 : Compléter la factory User**

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    email      { Faker::Internet.unique.email }
    password   { "password123" }
  end
end
```

- [ ] **Step 2 : Créer la factory Classroom**

```ruby
# spec/factories/classrooms.rb
FactoryBot.define do
  factory :classroom do
    name        { "Terminale SIN" }
    school_year { "2026" }
    specialty   { "SIN" }
    access_code { "terminale-sin-#{SecureRandom.hex(3)}" }
    association :owner, factory: :user
  end
end
```

- [ ] **Step 3 : Écrire les tests Classroom**

```ruby
# spec/models/classroom_spec.rb
require "rails_helper"

RSpec.describe Classroom, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:school_year) }
    it { is_expected.to validate_presence_of(:access_code) }
    it { is_expected.to validate_uniqueness_of(:access_code) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to have_many(:students) }
  end
end
```

- [ ] **Step 4 : Lancer les tests (ils doivent échouer)**

```bash
bundle exec rspec spec/models/classroom_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Classroom`

- [ ] **Step 5 : Créer le modèle Classroom**

```ruby
# app/models/classroom.rb
class Classroom < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :students, dependent: :destroy

  validates :name, :school_year, :access_code, presence: true
  validates :access_code, uniqueness: true
end
```

- [ ] **Step 6 : Lancer les tests (ils doivent passer)**

```bash
bundle exec rspec spec/models/classroom_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 7 : Commit**

```bash
git add app/models/classroom.rb spec/models/classroom_spec.rb spec/factories/classrooms.rb spec/factories/users.rb
git commit -m "feat(auth): add Classroom model with validations and associations"
```

---

## Task 4 : Modèle Student (TDD)

**Files:**
- Create: `spec/factories/students.rb`
- Create: `spec/models/student_spec.rb`
- Create: `app/models/student.rb`

- [ ] **Step 1 : Créer la factory Student**

```ruby
# spec/factories/students.rb
FactoryBot.define do
  factory :student do
    first_name { Faker::Name.first_name }
    last_name  { Faker::Name.last_name }
    username   { "#{Faker::Name.first_name.downcase}.#{Faker::Name.last_name.downcase}" }
    password   { "password123" }
    api_provider { 0 }
    association :classroom
  end
end
```

- [ ] **Step 2 : Écrire les tests Student**

```ruby
# spec/models/student_spec.rb
require "rails_helper"

RSpec.describe Student, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to have_secure_password }

    it "validates uniqueness of username scoped to classroom" do
      classroom = create(:classroom)
      create(:student, username: "jean.dupont", classroom: classroom)
      duplicate = build(:student, username: "jean.dupont", classroom: classroom)
      expect(duplicate).not_to be_valid
    end

    it "allows same username in different classrooms" do
      create(:student, username: "jean.dupont", classroom: create(:classroom))
      other = build(:student, username: "jean.dupont", classroom: create(:classroom))
      expect(other).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:classroom) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:api_provider).with_values(openrouter: 0, anthropic: 1, openai: 2, google: 3) }
  end
end
```

- [ ] **Step 3 : Lancer les tests (ils doivent échouer)**

```bash
bundle exec rspec spec/models/student_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant Student`

- [ ] **Step 4 : Créer le modèle Student**

```ruby
# app/models/student.rb
class Student < ApplicationRecord
  belongs_to :classroom
  has_secure_password

  enum :api_provider, { openrouter: 0, anthropic: 1, openai: 2, google: 3 }

  validates :first_name, :last_name, :username, presence: true
  validates :username, uniqueness: { scope: :classroom_id }
end
```

- [ ] **Step 5 : Lancer les tests (ils doivent passer)**

```bash
bundle exec rspec spec/models/student_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 6 : Commit**

```bash
git add app/models/student.rb spec/models/student_spec.rb spec/factories/students.rb
git commit -m "feat(auth): add Student model with bcrypt and scoped username uniqueness"
```

---

## Task 5 : Service GenerateAccessCode (TDD)

**Files:**
- Create: `spec/services/generate_access_code_spec.rb`
- Create: `app/services/generate_access_code.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/generate_access_code_spec.rb
require "rails_helper"

RSpec.describe GenerateAccessCode do
  describe ".call" do
    it "generates a slug from specialty and school_year" do
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026")
    end

    it "adds numeric suffix on collision" do
      create(:classroom, access_code: "sin-2026")
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026-2")
    end

    it "increments suffix until unique" do
      create(:classroom, access_code: "sin-2026")
      create(:classroom, access_code: "sin-2026-2")
      result = described_class.call(specialty: "SIN", school_year: "2026")
      expect(result).to eq("sin-2026-3")
    end

    it "handles nil specialty" do
      result = described_class.call(specialty: nil, school_year: "2026")
      expect(result).to eq("2026")
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/generate_access_code_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant GenerateAccessCode`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/generate_access_code.rb
class GenerateAccessCode
  def self.call(specialty:, school_year:)
    base = [specialty, school_year].compact.join("-").parameterize
    candidate = base
    counter = 2

    while Classroom.exists?(access_code: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    candidate
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/generate_access_code_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/generate_access_code.rb spec/services/generate_access_code_spec.rb
git commit -m "feat(auth): add GenerateAccessCode service with collision handling"
```

---

## Task 6 : Service GenerateStudentCredentials (TDD)

**Files:**
- Create: `spec/services/generate_student_credentials_spec.rb`
- Create: `app/services/generate_student_credentials.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/generate_student_credentials_spec.rb
require "rails_helper"

RSpec.describe GenerateStudentCredentials do
  let(:classroom) { create(:classroom) }

  describe ".call" do
    it "generates username from first and last name" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont")
    end

    it "adds numeric suffix on username collision within same classroom" do
      create(:student, username: "jean.dupont", classroom: classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont2")
    end

    it "increments suffix until unique" do
      create(:student, username: "jean.dupont", classroom: classroom)
      create(:student, username: "jean.dupont2", classroom: classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont3")
    end

    it "returns a password of 8 characters" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:password].length).to eq(8)
    end

    it "returns a password with only unambiguous alphanumeric characters" do
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:password]).to match(/\A[a-km-np-z2-9]+\z/)
    end

    it "allows same username in different classrooms" do
      other_classroom = create(:classroom)
      create(:student, username: "jean.dupont", classroom: other_classroom)
      result = described_class.call(first_name: "Jean", last_name: "Dupont", classroom: classroom)
      expect(result[:username]).to eq("jean.dupont")
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/generate_student_credentials_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant GenerateStudentCredentials`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/generate_student_credentials.rb
class GenerateStudentCredentials
  # Alphanumeric sans caractères ambigus (0/O, 1/l/I)
  CHARSET = ("a".."z").to_a - ["l", "o"] + ("2".."9").to_a

  def self.call(first_name:, last_name:, classroom:)
    base = "#{first_name}.#{last_name}".parameterize(separator: ".")
    username = unique_username(base, classroom)
    password = Array.new(8) { CHARSET.sample }.join

    { username: username, password: password }
  end

  def self.unique_username(base, classroom)
    candidate = base
    counter = 2

    while classroom.students.exists?(username: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    candidate
  end
  private_class_method :unique_username
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/generate_student_credentials_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/generate_student_credentials.rb spec/services/generate_student_credentials_spec.rb
git commit -m "feat(auth): add GenerateStudentCredentials service with unique username and safe password"
```

---

## Task 7 : Service AuthenticateStudent (TDD)

**Files:**
- Create: `spec/services/authenticate_student_spec.rb`
- Create: `app/services/authenticate_student.rb`

- [ ] **Step 1 : Écrire les tests**

```ruby
# spec/services/authenticate_student_spec.rb
require "rails_helper"

RSpec.describe AuthenticateStudent do
  let(:classroom) { create(:classroom, access_code: "terminale-sin-2026") }
  let!(:student)  { create(:student, username: "jean.dupont", password: "password123", classroom: classroom) }

  describe ".call" do
    it "returns the student on success" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "jean.dupont",
        password: "password123"
      )
      expect(result).to eq(student)
    end

    it "returns nil if classroom not found" do
      result = described_class.call(
        access_code: "inexistant",
        username: "jean.dupont",
        password: "password123"
      )
      expect(result).to be_nil
    end

    it "returns nil if username not found in classroom" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "inconnu",
        password: "password123"
      )
      expect(result).to be_nil
    end

    it "returns nil if password is wrong" do
      result = described_class.call(
        access_code: "terminale-sin-2026",
        username: "jean.dupont",
        password: "mauvais"
      )
      expect(result).to be_nil
    end
  end
end
```

- [ ] **Step 2 : Lancer les tests (doivent échouer)**

```bash
bundle exec rspec spec/services/authenticate_student_spec.rb
```

Résultat attendu : FAIL — `uninitialized constant AuthenticateStudent`

- [ ] **Step 3 : Créer le service**

```ruby
# app/services/authenticate_student.rb
class AuthenticateStudent
  def self.call(access_code:, username:, password:)
    classroom = Classroom.find_by(access_code: access_code)
    return nil unless classroom

    student = classroom.students.find_by(username: username)
    return nil unless student

    student.authenticate(password) || nil
  end
end
```

- [ ] **Step 4 : Lancer les tests (doivent passer)**

```bash
bundle exec rspec spec/services/authenticate_student_spec.rb
```

Résultat attendu : tous PASS

- [ ] **Step 5 : Commit**

```bash
git add app/services/authenticate_student.rb spec/services/authenticate_student_spec.rb
git commit -m "feat(auth): add AuthenticateStudent service"
```

---

## Task 8 : Controllers + Routes + Vue login

**Files:**
- Create: `app/controllers/student/base_controller.rb`
- Create: `app/controllers/student/sessions_controller.rb`
- Create: `app/views/student/sessions/new.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1 : Créer le BaseController**

```ruby
# app/controllers/student/base_controller.rb
class Student::BaseController < ApplicationController
  before_action :require_student_auth
  before_action :set_classroom_from_url

  helper_method :current_student

  private

  def current_student
    @current_student ||= ::Student.find_by(id: session[:student_id])
  end

  def require_student_auth
    unless current_student && current_student.classroom.access_code == params[:access_code]
      session.delete(:student_id)
      redirect_to student_login_path(access_code: params[:access_code]),
                  alert: "Veuillez vous connecter."
    end
  end

  def set_classroom_from_url
    @classroom = Classroom.find_by(access_code: params[:access_code])
    redirect_to root_path, alert: "Classe introuvable." unless @classroom
  end
end
```

- [ ] **Step 2 : Créer le SessionsController**

```ruby
# app/controllers/student/sessions_controller.rb
class Student::SessionsController < ApplicationController
  before_action :set_classroom

  def new
    redirect_to student_root_path(access_code: params[:access_code]) if current_student_in_classroom?
  end

  def create
    student = AuthenticateStudent.call(
      access_code: params[:access_code],
      username: params[:username],
      password: params[:password]
    )

    if student
      session[:student_id] = student.id
      redirect_to student_root_path(access_code: params[:access_code]),
                  notice: "Bienvenue, #{student.first_name} !"
    else
      flash.now[:alert] = "Identifiant ou mot de passe incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:student_id)
    redirect_to student_login_path(access_code: params[:access_code]),
                notice: "Vous êtes déconnecté."
  end

  private

  def set_classroom
    @classroom = Classroom.find_by(access_code: params[:access_code])
    redirect_to root_path, alert: "Classe introuvable." unless @classroom
  end

  def current_student_in_classroom?
    student = ::Student.find_by(id: session[:student_id])
    student&.classroom == @classroom
  end
end
```

- [ ] **Step 3 : Créer la vue login**

```erb
<%# app/views/student/sessions/new.html.erb %>
<h1>Connexion — <%= @classroom.name %></h1>

<%= form_with url: student_session_path(access_code: @classroom.access_code), method: :post do |f| %>
  <% if flash[:alert] %>
    <p style="color: red;"><%= flash[:alert] %></p>
  <% end %>

  <div>
    <%= f.label :username, "Identifiant" %>
    <%= f.text_field :username, autocomplete: "username", required: true %>
  </div>

  <div>
    <%= f.label :password, "Mot de passe" %>
    <%= f.password_field :password, autocomplete: "current-password", required: true %>
  </div>

  <%= f.submit "Se connecter" %>
<% end %>
```

- [ ] **Step 4 : Ajouter les routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  # Auth élève via access_code
  scope "/:access_code", as: :student do
    get  "/",        to: "student/sessions#new",     as: :login
    post "/session", to: "student/sessions#create",  as: :session
    delete "/session", to: "student/sessions#destroy"
    # Espace élève (à compléter dans les prochaines tâches)
    get "/subjects", to: "student/subjects#index", as: :root
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 5 : Vérifier les routes**

```bash
bin/rails routes | grep student
```

Résultat attendu : routes `student_login`, `student_session`, `student_root` présentes

- [ ] **Step 6 : Commit**

```bash
git add app/controllers/student/ app/views/student/ config/routes.rb
git commit -m "feat(auth): add student sessions controller and login view"
```

---

## Task 9 : Smoke test final

- [ ] **Step 1 : Lancer toute la suite RSpec**

```bash
bundle exec rspec spec/models/ spec/services/
```

Résultat attendu : tous PASS, 0 failures

- [ ] **Step 2 : Vérifier la console Rails**

```bash
bin/rails console
```

```ruby
classroom = Classroom.new(name: "Test", school_year: "2026", specialty: "SIN", access_code: "test-sin-2026", owner: User.first)
classroom.valid?  # => true
```

- [ ] **Step 3 : Commit final si tout passe**

```bash
git add .
git commit -m "test(auth): all model and service specs passing for Classroom + Student auth"
```

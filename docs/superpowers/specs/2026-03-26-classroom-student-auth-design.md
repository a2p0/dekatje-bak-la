# Design: Classroom + Student + Auth élève

**Date**: 2026-03-26
**Branch**: `001-bac-training-app`
**Scope**: Modèles Classroom et Student, auth élève custom bcrypt, services associés

---

## Modèles et migrations

### Classroom

**Migration** : `name`, `school_year`, `specialty`, `access_code` (unique, index), `owner_id` (FK users)

**Génération access_code** : `GenerateAccessCode` service → `"#{specialty}-#{school_year}".parameterize` + suffixe numérique si collision (ex: `terminale-sin-2026`, `terminale-sin-2026-2`)

**Validations** : `name`, `school_year`, `access_code` présents — `access_code` unique en base

**Relations** :
- `belongs_to :owner` (User)
- `has_many :students`
- `has_many :classroom_subjects`
- `has_many :subjects, through: :classroom_subjects`

---

### Student

**Migration** : `first_name`, `last_name`, `username`, `password_digest`, `encrypted_api_key`, `encrypted_api_key_iv`, `api_provider` (integer, default 0), `classroom_id` (FK)

**Index composite** : `[username, classroom_id]` unique — un même username peut exister dans deux classes différentes

**Génération username** : `GenerateStudentCredentials` service → `"#{first_name}.#{last_name}".parameterize` + suffixe numérique si doublon dans la classroom (ex: `jean.dupont`, `jean.dupont2`)

**Auth** : `has_secure_password` (bcrypt natif Rails)

**Enum api_provider** : `openrouter: 0, anthropic: 1, openai: 2, google: 3`

**Validations** : `first_name`, `last_name`, `username`, `classroom_id` présents

**Relations** :
- `belongs_to :classroom`
- `has_many :student_sessions`

---

## Auth élève

### Routes

```
GET  /:access_code           → student/sessions#new   (formulaire login)
POST /:access_code/session   → student/sessions#create (authentification)
DELETE /:access_code/session → student/sessions#destroy (logout)
```

### Flow authentification

1. Trouve `Classroom` par `access_code` → 404 si inexistante
2. Trouve `Student` par `username` dans cette classroom → erreur générique si absent
3. `student.authenticate(password)` → erreur générique si KO
4. Si OK → `session[:student_id] = student.id` → redirect espace élève
5. Messages d'erreur en français, sans révéler si c'est l'username ou le password qui est faux

### `StudentBaseController`

```ruby
before_action :require_student_auth
before_action :set_classroom_from_url

def current_student
  @current_student ||= Student.find_by(id: session[:student_id])
end

def require_student_auth
  redirect_to student_login_path(access_code: params[:access_code]) unless current_student
end

def set_classroom_from_url
  @classroom = Classroom.find_by!(access_code: params[:access_code])
end
```

Sécurité : si `current_student` n'appartient pas à la classroom de l'URL → redirect login.

---

## Services

### `GenerateAccessCode`

```ruby
GenerateAccessCode.call(specialty:, school_year:)
# → "terminale-sin-2026"
# → "terminale-sin-2026-2" si collision
```

### `GenerateStudentCredentials`

```ruby
GenerateStudentCredentials.call(first_name:, last_name:, classroom:)
# → { username: "jean.dupont", password: "xK4m9p2r" }
```

- Password aléatoire 8 caractères (alphanumériques lisibles, pas de caractères ambigus)
- Retourné en clair une seule fois pour impression sur fiche — jamais stocké en clair

### `AuthenticateStudent`

```ruby
AuthenticateStudent.call(access_code:, username:, password:)
# → Student si succès
# → nil si échec (classroom introuvable, username inconnu, mauvais password)
```

---

## Structure des fichiers

```
db/migrate/
  XXXXXX_create_classrooms.rb
  XXXXXX_create_students.rb

app/models/
  classroom.rb
  student.rb

app/services/
  generate_access_code.rb
  generate_student_credentials.rb
  authenticate_student.rb

app/controllers/student/
  base_controller.rb
  sessions_controller.rb

app/views/student/sessions/
  new.html.erb

spec/models/
  classroom_spec.rb
  student_spec.rb

spec/services/
  generate_access_code_spec.rb
  generate_student_credentials_spec.rb
  authenticate_student_spec.rb

spec/factories/
  classrooms.rb
  students.rb
```

---

## Règles appliquées automatiquement

- Redirect login si non authentifié (pas d'erreur 500)
- Messages d'erreur en français sans info sensible
- `find_by` jamais `find` pour éviter les exceptions
- `before_action` pour auth et chargement classroom
- Migrations avant modèles
- Tests RSpec écrits avant le code (TDD)

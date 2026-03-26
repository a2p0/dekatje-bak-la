# Design: Teacher Classroom & Student Management

**Date**: 2026-03-26
**Branch**: `002-teacher-classroom-management`
**Scope**: Interface enseignant — CRUD classes, gestion élèves, Devise confirmable, export PDF/Markdown

---

## Architecture

**Namespace `teacher/`** — tous les controllers sous `Teacher::` avec `Teacher::BaseController` vérifiant `authenticate_user!` + `confirmed?`.

**Gems nouvelles :**
- `letter_opener` (dev uniquement) — emails dans le navigateur
- `prawn` + `prawn-table` — génération PDF A4
- Devise `:confirmable` activé (déjà installé)

---

## Routes

```ruby
namespace :teacher do
  root to: "classrooms#index"

  resources :classrooms, only: [:index, :new, :create, :show] do
    resources :students, only: [:index, :new, :create] do
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
```

---

## Controllers

### `Teacher::BaseController`
- `before_action :authenticate_user!` (Devise)
- `before_action :require_confirmed!` — redirect avec message français si email non confirmé

### `Teacher::ClassroomsController`
- `index` — classes de l'enseignant connecté
- `new/create` — crée une classe, `access_code` via `GenerateAccessCode`
- `show` — classe + liste élèves
- `export_pdf` — `ExportStudentCredentialsPdf.call(classroom:)` → envoi fichier
- `export_markdown` — `ExportStudentCredentialsMarkdown.call(classroom:)` → envoi fichier texte

### `Teacher::StudentsController`
- `new/create` — crée un élève via `GenerateStudentCredentials`, credentials en `session[:generated_credentials]` affichés une seule fois
- `bulk_new` — formulaire textarea
- `bulk_create` — parse `Prénom Nom` ligne par ligne, crée tous les élèves, credentials en session
- `reset_password` — `ResetStudentPassword.call(student:)`, nouveau mot de passe en flash via Turbo Stream

---

## Devise Confirmable

**Migration** : ajouter `confirmation_token`, `confirmed_at`, `confirmation_sent_at`, `unconfirmed_email` sur `users`.

**Modèle** : ajouter `:confirmable` dans `devise`.

**Dev** : `letter_opener` — emails s'ouvrent dans le navigateur.

**Production** : Resend via SMTP :
```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.resend.com",
  port: 587,
  user_name: "resend",
  password: Rails.application.credentials.resend_api_key
}
config.action_mailer.default_url_options = { host: ENV["APP_HOST"] }
```

**Comportement** :
- Inscription → email de confirmation → clic lien → compte activé
- Sans confirmation → message : *"Veuillez confirmer votre adresse email avant de vous connecter."*
- Renvoi mail possible depuis la page de login Devise

---

## Services

### `ResetStudentPassword`
```ruby
ResetStudentPassword.call(student:)
# → { password: "xK4m9p2r" }
```
Génère un mot de passe via le charset de `GenerateStudentCredentials`, appelle `student.update!(password:)`.

### `ExportStudentCredentialsPdf`
```ruby
ExportStudentCredentialsPdf.call(classroom:)
# → StringIO (PDF binaire)
```
Format A4 Prawn :
- En-tête : nom de la classe + URL de connexion (`/{access_code}`)
- Tableau : Nom complet / Identifiant / Mot de passe (colonne vide — jamais stocké)

### `ExportStudentCredentialsMarkdown`
```ruby
ExportStudentCredentialsMarkdown.call(classroom:)
# → String
```
Format :
```markdown
# Classe : Terminale SIN 2026
# URL de connexion : https://app.fr/terminale-sin-2026

| Nom | Identifiant | Mot de passe |
|-----|-------------|--------------|
| Jean Dupont | jean.dupont | _(à distribuer)_ |
```

---

## Credentials affichés une seule fois

Les mots de passe en clair sont stockés temporairement en `session[:generated_credentials]` (array de `{name, username, password}`) et effacés après affichage. Jamais persistés en base.

---

## Vues (Hotwire/Turbo)

**Layout** : `app/views/layouts/teacher.html.erb` — nav avec "Mes classes" + "Déconnexion".

**Classrooms :**
- `index` — liste classes avec liens
- `new` — formulaire : nom, année scolaire, spécialité
- `show` — infos + tableau élèves + boutons action

**Students :**
- `new` — formulaire prénom + nom
- `bulk_new` — textarea "Un prénom nom par ligne"
- Après création / bulk_create — Turbo Stream affiche les credentials générés (une seule fois)
- Après `reset_password` — Turbo Stream met à jour la ligne élève

---

## Structure des fichiers

```
app/controllers/teacher/
  base_controller.rb
  classrooms_controller.rb
  students_controller.rb

app/services/
  reset_student_password.rb
  export_student_credentials_pdf.rb
  export_student_credentials_markdown.rb

app/views/teacher/
  classrooms/ (index, new, show)
  students/ (new, bulk_new, _credentials)
  layouts/teacher.html.erb (optionnel)

spec/controllers/teacher/
  classrooms_controller_spec.rb
  students_controller_spec.rb

spec/services/
  reset_student_password_spec.rb
  export_student_credentials_pdf_spec.rb
  export_student_credentials_markdown_spec.rb
```

---

## Règles appliquées automatiquement

- Redirect login si non authentifié ou non confirmé
- Mots de passe jamais en base, jamais dans les logs
- Messages en français
- `find_by` jamais `find`
- Credentials affichés une seule fois via session temporaire

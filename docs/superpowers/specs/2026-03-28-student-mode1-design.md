# Design: Student Mode 1 — Navigation & Correction (F6)

**Date**: 2026-03-28
**Branch**: `006-student-mode1`
**Scope**: Navigation Part→Question, correction reveal avec data_hints, suivi progression StudentSession, accès DT/DR

---

## Architecture

Navigation une question à la fois avec sidebar responsive (persistante desktop, drawer overlay mobile). La sidebar combine contexte (presentation_text + objective_text) et navigation (questions partie courante + liens vers autres parties). Correction révélée en bloc (correction, explication, data_hints, key_concepts). Progression trackée via StudentSession (JSON).

---

## Nouvelle migration requise

`StudentSession` — suivi progression élève par sujet :
```
student_id: FK → students
subject_id: FK → subjects
mode: enum (autonomous: 0, tutored: 1)
progression: jsonb, default: {}
started_at: datetime
last_activity_at: datetime
index unique composite [student_id, subject_id]
```

Format progression JSON :
```json
{
  "42": {"seen": true, "answered": false},
  "43": {"seen": true, "answered": true}
}
```
Clés = question IDs en string.

---

## Routes

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

---

## Controllers

### `Student::SubjectsController`
- `index` — liste des sujets publiés assignés à la classe de l'élève (`current_student.classroom.subjects.published`)
- `show` — crée ou reprend StudentSession, redirige vers la première question non faite

### `Student::QuestionsController`
- `show` — affiche la question, marque "seen" dans progression, charge sidebar data
- `reveal` — marque "answered" dans progression, rend le partial correction via Turbo Frame

---

## Vues

### `app/views/student/subjects/index.html.erb`
Cards pour chaque sujet assigné :
- Titre, spécialité, année
- Barre de progression (% questions answered)
- Lien "Continuer" ou "Commencer"

### `app/views/student/questions/show.html.erb`
Layout principal :
- Desktop : sidebar 300px fixed gauche + contenu principal
- Mobile : hamburger → drawer overlay + contenu pleine largeur

Contenu principal :
- Barre de progression (Q3/8 + progress bar)
- Carte question (numéro, points, label, context_text)
- Bouton "Voir la correction" (avant révélation)
- Turbo Frame correction (après révélation)
- Navigation Précédent / Question suivante

### `app/views/student/questions/_correction.html.erb`
Turbo Frame `question_<id>_correction` :
- Correction (bordure verte) : correction_text
- Explication : explanation_text
- Données utiles : data_hints avec badges source (DT1, Énoncé...)
- Concepts clés : tags key_concepts
- Documents correction : liens DR corrigé + questions corrigées (seulement après révélation)

### `app/views/student/questions/_sidebar.html.erb`
Partial sidebar/drawer :
- "Mise en situation" : subject.presentation_text (collapsible)
- "Objectif" : part.objective_text
- Liste questions partie courante (checkmarks pour les "answered")
- Autres parties comme liens (badge progression par partie)
- Documents : DT + DR vierge toujours visibles

---

## Stimulus

### `sidebar-controller`
- Toggle drawer open/close sur mobile (hamburger click)
- Ferme le drawer après sélection d'une question
- Sur desktop : CSS gère l'affichage permanent, pas de JS nécessaire
- Breakpoint : 1024px (lg)

---

## Modèles

### `StudentSession`
```ruby
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
  part.questions.kept.order(:position).detect { |q| !answered?(q.id) }
end
```

### `Student` (ajouts)
```ruby
has_many :student_sessions, dependent: :destroy
```

### `Subject` (ajouts)
```ruby
has_many :student_sessions, dependent: :destroy
```

---

## Sécurité

- `Student::BaseController` gère l'auth (session + access_code)
- Accès sujet : scopé à `current_student.classroom.subjects.published`
- Accès question : scopé aux questions kept du sujet
- StudentSession : scopé à `current_student`
- DR corrigé + questions corrigées : seulement affichés si la correction est révélée

---

## Cas limites

- Sujet sans parties/questions → message "Ce sujet n'a pas encore de questions."
- Toutes questions terminées → message de complétion avec résumé progression
- URL directe vers question d'un autre sujet → redirect vers liste sujets
- StudentSession existante → reprend, pas de doublon (contrainte unique)
- Question sans Answer → affiche la question, bouton correction masqué

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_create_student_sessions.rb

app/models/
  student_session.rb
  student.rb (modifié)
  subject.rb (modifié)

app/controllers/student/
  subjects_controller.rb
  questions_controller.rb

app/views/student/
  subjects/index.html.erb
  questions/show.html.erb
  questions/_correction.html.erb
  questions/_sidebar.html.erb

app/javascript/controllers/
  sidebar_controller.js

spec/models/
  student_session_spec.rb

spec/factories/
  student_sessions.rb

spec/requests/student/
  subjects_spec.rb
  questions_spec.rb
```

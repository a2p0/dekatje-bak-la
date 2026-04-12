# Implementation Plan: Rails Conventions Audit Fix

**Branch**: `031-rails-conventions-fix` | **Date**: 2026-04-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/031-rails-conventions-fix/spec.md`

## Summary

Corriger les 13 violations et 58 warnings pertinents identifiés par l'audit `/rails-conventions audit`. Refactoring pur — aucune fonctionnalité ajoutée, aucune migration, aucun changement de schéma. Organisé en phases par domaine (fondations + 8 user stories + polish).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Devise, Stimulus, Turbo, Sidekiq, FactoryBot  
**Storage**: PostgreSQL via Neon  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Linux server (Coolify/Nixpacks)  
**Project Type**: Web application fullstack Rails  
**Performance Goals**: N/A (refactoring, pas de nouvelles fonctionnalités)  
**Constraints**: CI GitHub Actions comme runner de tests autoritaire  
**Scale/Scope**: 14 modèles, 16 controllers, 18 services, ~50 vues ERB

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | On externalise le JS inline en Stimulus (plus Hotwire-compliant) |
| II. RGPD & Protection des mineurs | PASS | Aucun changement de données |
| III. Security | PASS | Aucune clé API exposée, pas de changement auth |
| IV. Testing | PASS | Tests existants doivent passer. Pas de nouvelles features → pas de nouveaux tests requis (mais les specs des services seront mises à jour pour les nouveaux return types) |
| V. Performance & Simplicity | PASS | Mémoisation et eager loading améliorent la perf. Code reste simple. |
| VI. Development Workflow | PASS | Plan validé avant code. Branche feature. PR + CI. |

## Project Structure

### Documentation (this feature)

```text
specs/031-rails-conventions-fix/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Research findings
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # (created by /speckit.tasks)
```

### Source Code (files impacted)

```text
app/
├── controllers/
│   ├── student/
│   │   ├── questions_controller.rb    # Scopes extraction (3 where())
│   │   ├── subjects_controller.rb     # Scopes extraction (1 where())
│   │   └── tutor_controller.rb        # Scopes extraction (1 where())
│   └── teacher/
│       ├── parts_controller.rb        # Scopes extraction (1 where())
│       ├── questions_controller.rb    # Scopes extraction (1 where())
│       └── students_controller.rb     # Service return value updates
├── javascript/controllers/
│   └── access_code_controller.js      # NEW — replaces home.html.erb inline script
├── jobs/
│   ├── extract_questions_job.rb       # Idempotence guard
│   └── tutor_stream_job.rb            # Idempotence guard
├── models/
│   ├── part.rb                        # New scopes: .specific, #validated_questions_count
│   ├── question.rb                    # New scopes: .for_parts(), .for_subject()
│   └── student_session.rb             # Memoize filtered_parts + answered_count_for()
├── services/
│   ├── authenticate_student.rb        # self.call → new.call
│   ├── build_extraction_prompt.rb     # self.call → new.call
│   ├── export_student_credentials_markdown.rb  # self.call → new.call
│   ├── export_student_credentials_pdf.rb       # self.call → new.call
│   ├── extract_questions_from_pdf.rb  # self.call → new.call
│   ├── generate_access_code.rb        # self.call → new.call
│   ├── generate_student_credentials.rb # self.call → new.call + Struct return
│   ├── persist_extracted_data.rb      # self.call → new.call
│   ├── reset_student_password.rb      # self.call → new.call + direct return
│   ├── resolve_api_key.rb             # self.call → new.call + Struct return
│   └── validate_student_api_key.rb    # self.call → new.call + raise on failure
└── views/
    ├── layouts/                        # Theme scripts: KEEP (justified false positive)
    ├── pages/home.html.erb            # form_tag → form_with + remove inline script
    ├── student/
    │   ├── questions/
    │   │   ├── _sidebar_part.html.erb # Extract .count logic
    │   │   └── show.html.erb          # Extract .count logic
    │   ├── sessions/new.html.erb      # form_tag → form_with
    │   └── subjects/_part_row.html.erb # Extract .count
    ├── teacher/
    │   ├── classrooms/
    │   │   ├── index.html.erb         # Extract students.count (2N queries)
    │   │   └── show.html.erb          # .count → .size
    │   ├── parts/show.html.erb        # Extract validated count + .count → .size
    │   └── subjects/new.html.erb      # errors.count: KEEP (standard pattern)
    └── users/                          # 7 Devise views: form_for → form_with
        ├── confirmations/new.html.erb
        ├── passwords/edit.html.erb
        ├── passwords/new.html.erb
        ├── registrations/edit.html.erb
        ├── registrations/new.html.erb
        ├── sessions/new.html.erb
        └── unlocks/new.html.erb

spec/
├── jobs/extract_questions_job_spec.rb  # Update ResolveApiKey stub
├── requests/student/settings_spec.rb   # Update ValidateStudentApiKey stub
└── services/
    ├── generate_student_credentials_spec.rb  # Update assertions
    └── reset_student_password_spec.rb        # Update assertions
```

## Implementation Phases

### Phase 1 — Views: form_for/form_tag → form_with (Commit 1)

**Scope**: 9 violations — 7 Devise + home + student login

**Approche**:
- Devise views: remplacer `form_for(resource, as: resource_name, url: ...)` par `form_with(model: resource, as: resource_name, url: ..., class: ...)`
- Home page: remplacer `form_tag nil, method: :get` par `form_with url: nil, method: :get`
- Student login: remplacer `form_tag` par `form_with`
- Conserver toutes les classes CSS, champs et layouts existants

**Risques**: Les formulaires Devise ont des conventions spécifiques (`resource`, `resource_name`). `form_with` soumet en Turbo par défaut — vérifier que `data: { turbo: false }` est ajouté si nécessaire pour les actions Devise qui redirigent.

### Phase 2 — Views: externaliser le script inline home page (Commit 2)

**Scope**: 1 violation corrigée (home page). Les 3 layouts gardent le script theme anti-flash (faux positif justifié).

**Approche**:
- Créer `app/javascript/controllers/access_code_controller.js`
- Le controller écoute l'événement `submit`, lit la valeur du champ, redirige vers `/<code>`
- Ajouter `data-controller="access-code"` et `data-action="submit->access-code#redirect"` au formulaire
- Supprimer le `<script>` inline

### Phase 3 — Views: extraire logique métier des vues (Commit 3)

**Scope**: 8 warnings (2 gardés car pattern Rails standard)

**Approche**:
- `classrooms/show.html.erb`: `.count` → `.size` (relation déjà chargée)
- `classrooms/index.html.erb`: ajouter `includes(:students)` + `counter_cache` ou preload count dans le controller
- `parts/show.html.erb`: créer `Part#validated_questions_count`, `.count` → `.size`
- `_sidebar_part.html.erb` + `questions/show.html.erb`: créer `StudentSession#answered_count_for(questions)`
- `_part_row.html.erb`: eager load `questions` dans le controller ou counter cache

### Phase 4 — Jobs: gardes d'idempotence (Commit 4)

**Scope**: 2 warnings

**Approche**:
- `ExtractQuestionsJob#perform`: ajouter `return if extraction_job.done?` au début
- `TutorStreamJob#perform`: vérifier que la conversation n'a pas déjà un dernier message assistant avant de streamer

### Phase 5 — Controllers: where() → scopes (Commit 5)

**Scope**: 7 warnings

**Approche**:
- Créer `scope :specific, -> { where(section_type: :specific) }` sur Part
- Créer `scope :for_parts, ->(parts) { kept.where(part: parts) }` sur Question
- Créer `scope :for_subject, ->(subject) { kept.joins(:part).where(parts: { subject_id: subject.id }) }` sur Question
- Remplacer les 7 `where()` dans les controllers par les scopes correspondants

### Phase 6 — Models: N+1 et mémoisation (Commit 6)

**Scope**: 6 warnings

**Approche**:
- `StudentSession#filtered_parts`: mémoiser avec `@filtered_parts ||= ...`
- `StudentSession#answered_count_for(questions)`: nouvelle méthode (utilisée par Phase 3)
- Controllers listant des subjects: ajouter `.includes(:exam_session)` aux requêtes
- Vérifier que la mémoisation est safe (instances request-scoped)

### Phase 7 — Services: self.call → new.call (Commit 7)

**Scope**: 11 services

**Approche pour chaque service**:
1. Ajouter `def initialize(...)` avec les paramètres actuels de `self.call`
2. Renommer `self.call` en `call` (instance method) avec le corps existant
3. Ajouter `def self.call(...) = new(...).call`
4. Convertir les `private_class_method` en `private` instance methods
5. Remplacer les variables locales par des `@ivars` où nécessaire

**Services exclus** (justifié dans research.md):
- `AiClientFactory`: factory pattern, pas un service object
- `TutorSimulation::*` (4): objets à état long, interface instance déjà correcte

### Phase 8 — Services: return values (Commit 8)

**Scope**: 4 services + leurs callers

**Approche**:
- `ValidateStudentApiKey`: retourner `true` ou raise `InvalidApiKeyError`. Mettre à jour `settings_controller.rb` pour rescue.
- `ResolveApiKey`: retourner `Struct.new(:api_key, :provider)`. Mettre à jour `extract_questions_job.rb`.
- `ResetStudentPassword`: retourner le password directement (String). Mettre à jour `students_controller.rb`.
- `GenerateStudentCredentials`: retourner `Struct.new(:username, :password)`. Mettre à jour `students_controller.rb`.
- Mettre à jour toutes les specs correspondantes.

## Risques et mitigations

| Risque | Impact | Mitigation |
|--------|--------|-----------|
| Formulaires Devise cassés après migration form_with | Élevé | Tester chaque formulaire. Ajouter `data: { turbo: false }` si nécessaire |
| Callers de services non identifiés | Moyen | Grep exhaustif fait dans research. Vérifier les specs. |
| Mémoisation de filtered_parts avec état mutable | Faible | StudentSession est request-scoped, jamais modifié en cours de requête |
| Scopes mal nommés créant des conflits | Faible | Vérifier les noms existants avant de créer |

## Scope Adjustments from Research

1. **Réduction scope Views inline scripts**: 4 violations → 1 correction (3 faux positifs theme anti-flash)
2. **Réduction scope Views .count**: 10 warnings → 8 corrections (2 patterns Rails standard gardés)
3. **Réduction scope Services self.call**: 16 warnings → 11 corrections (5 ne sont pas des service objects)
4. **Total ajusté**: 10 violations corrigées (sur 13) + 58 warnings corrigés (sur 75) = 68 corrections

## Complexity Tracking

Aucune violation de constitution. Pas de complexité ajoutée — refactoring pur.

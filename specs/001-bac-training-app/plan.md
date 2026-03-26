# Implementation Plan: DekatjeBakLa

**Branch**: `001-bac-training-app` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-bac-training-app/spec.md`

## Summary

Application Rails 8 fullstack d'entraînement BAC STI2D. Double authentification (Devise teacher + bcrypt custom student). Pipeline extraction PDF asynchrone via Sidekiq + Claude API. Espace élève en 3 modes progressifs. Multi-provider IA avec streaming SSE → Turbo Streams. Déploiement Coolify + Neon PostgreSQL + Redis.

## Technical Context

**Language/Version**: Ruby 3.3+, Rails 8.1
**Primary Dependencies**: Devise, Sidekiq, pdf-reader, Faraday, Turbo Streams, Stimulus, ActiveStorage
**Storage**: PostgreSQL via Neon (poolée app + directe migrations), Redis (Sidekiq), ActiveStorage (PDFs locaux)
**Testing**: RSpec + FactoryBot + Faker + Capybara + Selenium
**Target Platform**: Linux server (Coolify + Nixpacks), navigateurs modernes (Chrome + Firefox)
**Project Type**: Web application fullstack (Rails monolithe)
**Performance Goals**: Extraction PDF démarre < 5s, streaming IA démarre < 2s, chargement pages < 1s
**Constraints**: Assets locaux (pas CDN), timeout IA 60s, PDF 20MB sujets / 50MB leçons, connexion lente Martinique
**Scale/Scope**: ~10 enseignants, ~300 élèves, ~50 sujets BAC au lancement MVP

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Notes |
|----------|--------|-------|
| Rails 8 fullstack uniquement | ✅ PASS | Pas de SPA séparé |
| Appels IA depuis le serveur uniquement | ✅ PASS | Faraday côté Rails, jamais fetch JS |
| Aucun email élève collecté | ✅ PASS | Student sans champ email |
| Clés API chiffrées (`encrypts`) | ✅ PASS | User et Student encrypted fields |
| TDD — test avant code | ✅ PASS | RSpec en place, discipline à maintenir |
| Thin controllers → services | ✅ PASS | app/services/ pour toute logique |
| Migrations avant modèles | ✅ PASS | Convention documentée dans CLAUDE.md |
| Assets locaux, pas CDN | ✅ PASS | Importmap + Propshaft |
| Soft delete (discarded_at) | ✅ PASS | Sur Subject et Question |
| Deux URLs Neon distinctes | ✅ PASS | DATABASE_URL + DATABASE_DIRECT_URL |

**Résultat** : Tous les gates passent. Phase 0 autorisée.

## Project Structure

### Documentation (this feature)

```text
specs/001-bac-training-app/
├── plan.md              # Ce fichier
├── research.md          # Phase 0 — décisions techniques
├── data-model.md        # Phase 1 — modèle de données complet
├── contracts/           # Phase 1 — contrats d'interfaces
│   ├── routes.md
│   └── ai-api.md
└── tasks.md             # Phase 2 — /speckit.tasks
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── teacher/          ← namespace enseignant
│   └── student/          ← namespace élève
├── models/
│   ├── user.rb           ← enseignant (Devise)
│   ├── student.rb        ← élève (bcrypt custom)
│   ├── classroom.rb
│   ├── subject.rb
│   ├── part.rb
│   ├── question.rb
│   ├── answer.rb
│   ├── technical_document.rb
│   ├── student_session.rb
│   ├── conversation.rb
│   └── extraction_job.rb
├── services/
│   ├── extract_questions_from_pdf.rb
│   ├── build_extraction_prompt.rb
│   ├── resolve_api_key.rb
│   ├── ai_client_factory.rb
│   ├── stream_ai_response.rb
│   ├── build_tutor_prompt.rb
│   └── generate_student_credentials.rb
├── jobs/
│   └── extract_questions_job.rb
└── javascript/
    └── controllers/
        ├── context_panel_controller.js   ← sticky panel
        └── pdf_viewer_controller.js

db/
└── migrate/

spec/
├── models/
├── services/
├── jobs/
└── system/               ← tests Capybara
```

**Structure Decision**: Rails monolithe avec namespaces `teacher/` et `student/` pour les controllers. Toute logique métier dans `app/services/`. Un job Sidekiq par extraction PDF.

## Complexity Tracking

Aucune violation de constitution identifiée.

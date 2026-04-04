# Implementation Plan: Consolidation de l'extraction PDF

**Branch**: `015-extraction-consolidation` | **Date**: 2026-04-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/015-extraction-consolidation/spec.md`

## Summary

Restructurer le pipeline d'extraction PDF pour passer de 5 fichiers uploadés séparément à 2 fichiers (sujet monolithique + corrigé). Introduire le concept d'ExamSession pour grouper les spécialités d'une même session d'examen, avec des parties communes partagées au niveau de la session. Ajouter la spécialité sur le profil élève et permettre le choix du périmètre de travail (commune/spé/complet).

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1  
**Primary Dependencies**: Devise, Sidekiq, pdf-reader, Faraday, Turbo Streams, Stimulus, ActiveStorage  
**Storage**: PostgreSQL via Neon (poolée app + directe migrations), Redis (Sidekiq), ActiveStorage (PDFs locaux)  
**Testing**: RSpec + FactoryBot + Capybara  
**Target Platform**: Web (Linux server, Coolify/Docker)  
**Project Type**: web-service (fullstack Rails, Hotwire)  
**Performance Goals**: Extraction < 3 min pour un PDF de 35 pages, interface responsive  
**Constraints**: PDF max 30 Mo, LLM max_tokens 16384 pour l'output, timeout API 180s  
**Scale/Scope**: ~10 enseignants, ~200 élèves, ~50 sujets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | PASS | Tout reste en Rails+Hotwire, pas de SPA |
| II. RGPD & Protection des mineurs | PASS | Pas de collecte d'email supplémentaire. La spécialité élève n'est pas une donnée sensible |
| III. Security | PASS | Les clés API restent chiffrées, pas de nouveau secret exposé |
| IV. Test-First | PASS | TDD obligatoire, migrations avant modèles, services thin controllers |
| V. Performance & Simplicity | PASS | PDF max 30 Mo (< limite 50 Mo). Soft delete conservé |

Aucune violation. Gate passé.

## Project Structure

### Documentation (this feature)

```text
specs/015-extraction-consolidation/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/          # Quality checklists
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── exam_session.rb          # NOUVEAU
│   ├── subject.rb               # MODIFIÉ (exam_session_id, nouveaux attachments, enum EE)
│   ├── part.rb                  # MODIFIÉ (exam_session_id nullable, subject_id nullable, specialty, document_references)
│   ├── question.rb              # MODIFIÉ (dt_references, dr_references)
│   ├── student.rb               # MODIFIÉ (specialty enum)
│   ├── student_session.rb       # MODIFIÉ (part_filter enum)
│   └── extraction_job.rb        # MODIFIÉ (exam_session_id)
├── services/
│   ├── build_extraction_prompt.rb    # RÉÉCRIT (dual-PDF, nouveau JSON)
│   ├── extract_questions_from_pdf.rb # MODIFIÉ (2 PDFs, page markers)
│   └── persist_extracted_data.rb     # RÉÉCRIT (common/specific, ExamSession, dédup)
├── jobs/
│   └── extract_questions_job.rb      # MODIFIÉ (ExamSession, skip common si existant)
├── controllers/
│   ├── teacher/
│   │   └── subjects_controller.rb    # MODIFIÉ (2 fichiers, ExamSession find_or_create)
│   └── student/
│       ├── subjects_controller.rb    # MODIFIÉ (filtrage par spé, périmètre)
│       └── questions_controller.rb   # MODIFIÉ (filtrage par part_filter)
└── views/
    ├── teacher/subjects/
    │   ├── new.html.erb              # RÉÉCRIT (formulaire 2 fichiers)
    │   └── show.html.erb             # MODIFIÉ (affichage ExamSession)
    └── student/
        ├── subjects/
        │   ├── index.html.erb        # MODIFIÉ (affichage par session)
        │   └── show.html.erb         # MODIFIÉ (écran choix périmètre)
        ├── questions/show.html.erb   # MODIFIÉ (filtrage parts)
        └── settings/show.html.erb    # MODIFIÉ (sélecteur spécialité)

db/migrate/
├── YYYYMMDD_rename_ec_to_ee.rb
├── YYYYMMDD_create_exam_sessions.rb
├── YYYYMMDD_add_exam_session_to_subjects.rb
├── YYYYMMDD_add_shared_parts_support.rb
├── YYYYMMDD_add_dt_dr_references_to_questions.rb
├── YYYYMMDD_add_specialty_to_students.rb
├── YYYYMMDD_add_part_filter_to_student_sessions.rb
└── YYYYMMDD_update_extraction_jobs.rb

spec/
├── models/exam_session_spec.rb       # NOUVEAU
├── services/
│   ├── build_extraction_prompt_spec.rb   # RÉÉCRIT
│   ├── extract_questions_from_pdf_spec.rb # MODIFIÉ
│   └── persist_extracted_data_spec.rb    # RÉÉCRIT
├── jobs/extract_questions_job_spec.rb    # MODIFIÉ
└── features/
    ├── teacher_upload_subject_spec.rb    # NOUVEAU
    ├── teacher_session_dedup_spec.rb     # NOUVEAU
    ├── student_specialty_spec.rb         # NOUVEAU
    └── student_scope_selection_spec.rb   # NOUVEAU
```

**Structure Decision**: Structure Rails standard existante. Pas de nouveau répertoire. L'ExamSession est un modèle standard dans `app/models/`. Les services existants sont modifiés en place.

## Complexity Tracking

Aucune violation de la constitution. Pas de justification nécessaire.

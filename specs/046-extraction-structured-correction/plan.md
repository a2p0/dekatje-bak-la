# Implementation Plan: Extraction — Structured Correction en production

**Branch**: `046-extraction-structured-correction` | **Date**: 2026-04-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/046-extraction-structured-correction/spec.md`

## Summary

Intégrer l'enrichissement `structured_correction` (validé POC 043) directement dans le
pipeline d'extraction PDF. Approche 2 passes : passe 1 inchangée (`ExtractQuestionsFromPdf`
→ `PersistExtractedData`), passe 2 nouvelle (`EnrichAllAnswers` → `EnrichStructuredCorrection`
par question) déclenchée dans le même job Sidekiq avec dégradation gracieuse. Script rake
idempotent pour les subjects existants.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: AiClientFactory (Faraday, multi-provider), ResolveApiKey, Sidekiq
**Storage**: PostgreSQL via Neon — champ `structured_correction` JSONB nullable sur `answers` (migration 043 — déjà présente)
**Testing**: RSpec + FactoryBot + WebMock (stubs LLM)
**Target Platform**: Serveur Rails (Sidekiq worker + rake CLI)
**Project Type**: Web application fullstack Rails
**Performance Goals**: Passe 2 ≤ 2× durée passe 1 pour sujet ~20 questions
**Constraints**: Dégradation gracieuse — passe 2 ne doit jamais faire échouer le job ; idempotence rake task
**Scale/Scope**: ~20 questions/sujet, coût passe 2 ~$0.05-0.10/sujet

## Constitution Check

| Principe | Check | Statut |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | Pas d'interface UI — service/job backend uniquement | ✅ |
| II. RGPD & Protection mineurs | Aucune donnée élève traitée — enrichissement de corrections | ✅ |
| III. Security | API keys via `ResolveApiKey` existant — pas de nouveau stockage clé | ✅ |
| IV. Testing (TDD) | Specs avant implémentation : `EnrichStructuredCorrection`, `EnrichAllAnswers`, job, rake | ✅ requis |
| V. Performance & Simplicity | Code simple : 2 nouveaux services, 1 rake task, 1 modif job | ✅ |
| VI. Development Workflow | Feature branch 046, PR avant merge, speckit complet | ✅ |

**Résultat** : Aucune violation. Pas de justification de complexité nécessaire.

## Project Structure

### Documentation (this feature)

```text
specs/046-extraction-structured-correction/
├── plan.md              ← Ce fichier
├── spec.md              ← Spécification
├── research.md          ← Décisions techniques
├── data-model.md        ← Modèle de données et interfaces services
├── quickstart.md        ← Guide implémentation
├── checklists/
│   └── requirements.md  ← Checklist qualité spec
└── tasks.md             ← À générer via /speckit-tasks
```

### Source Code (repository root)

```text
app/
├── jobs/
│   └── extract_questions_job.rb          ← MODIFIÉ : appel EnrichAllAnswers après PersistExtractedData
├── services/
│   ├── enrich_structured_correction.rb   ← NOUVEAU : enrichit UNE answer via LLM
│   └── enrich_all_answers.rb             ← NOUVEAU : orchestre enrichissement d'un subject entier

lib/
└── tasks/
    └── subjects.rake                      ← NOUVEAU : rake subjects:enrich_structured_correction[ID]

spec/
├── services/
│   ├── enrich_structured_correction_spec.rb  ← NOUVEAU
│   └── enrich_all_answers_spec.rb             ← NOUVEAU
├── jobs/
│   └── extract_questions_job_spec.rb          ← MODIFIÉ : test passe 2 appelée
└── tasks/
    └── subjects_enrich_spec.rb                ← NOUVEAU
```

## Phases d'implémentation

### Phase A — Service `EnrichStructuredCorrection` (TDD)

1. Écrire `spec/services/enrich_structured_correction_spec.rb` (WebMock, 3 cas)
2. Implémenter `app/services/enrich_structured_correction.rb`
   - Extraire SYSTEM_PROMPT et `build_user_message` verbatim du POC `tmp/poc_043_enrich.rb`
   - Pattern Result struct (ok:, structured_correction:, error:)
   - `AiClientFactory.build(provider:, api_key:).call(...)` avec `max_tokens: 4096, temperature: 0.0`
   - Rescue `StandardError` → `Result.new(ok: false, error: e.message)`
   - Parse JSON via méthode `extract_json` (copie du POC — strip markdown fences, gsub trailing commas)

### Phase B — Service `EnrichAllAnswers` (TDD)

1. Écrire `spec/services/enrich_all_answers_spec.rb` (3 answers, 1 erreur → enriched: 2, errors: 1)
2. Implémenter `app/services/enrich_all_answers.rb`
   - Itère `subject.parts.includes(questions: :answer).flat_map(&:questions).map(&:answer)`
   - Filtre `answer.structured_correction.nil?` (idempotent par défaut)
   - Appelle `EnrichStructuredCorrection.call(answer:, api_key:, provider:)`
   - Si `result.ok?` : `answer.update!(structured_correction: result.structured_correction)`
   - Si `!result.ok?` : `Rails.logger.warn("[EnrichAllAnswers] #{answer.question.number}: #{result.error}")`
   - Ne lève jamais d'exception
   - Retourne `{enriched: N, skipped: N, errors: N}`

### Phase C — Intégration dans `ExtractQuestionsJob` (TDD)

1. Mettre à jour `spec/jobs/extract_questions_job_spec.rb` — vérifier que `EnrichAllAnswers` est appelé
2. Modifier `app/jobs/extract_questions_job.rb` :
   ```ruby
   PersistExtractedData.call(subject: subject, data: data)
   EnrichAllAnswers.call(subject: subject.reload, api_key: resolved.api_key, provider: resolved.provider)
   ```
   - `subject.reload` pour avoir les answers fraîchement persistées
   - `EnrichAllAnswers` est dans le `begin` bloc existant mais ses exceptions sont déjà capturées par le rescue du job
   - Si `EnrichAllAnswers` lève malgré tout : le rescue existant attrape, job → `failed` avec message explicite

### Phase D — Rake task (TDD)

1. Écrire `spec/tasks/subjects_enrich_spec.rb`
2. Implémenter `lib/tasks/subjects.rake` :
   ```ruby
   namespace :subjects do
     desc "Enrich structured_correction for all subjects (or subject_id)"
     task :enrich_structured_correction, [:subject_id] => :environment do |_, args|
       # ...
     end
   end
   ```
   - Avec `args[:subject_id]` : `Subject.find(id)`
   - Sans argument : `Subject.joins(parts: { questions: :answer }).where(answers: { structured_correction: nil }).distinct`
   - Pour chaque subject : `ResolveApiKey.call(user: subject.owner)` puis `EnrichAllAnswers.call(...)`
   - Output lisible + résumé

## Complexité Tracking

Aucune violation de constitution. Pas de complexité injustifiée.

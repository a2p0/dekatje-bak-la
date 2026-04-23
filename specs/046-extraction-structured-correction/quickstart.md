# Quickstart: Extraction — Structured Correction en production

## Vue d'ensemble

```
PDF upload (enseignant)
  → ExtractQuestionsJob (Sidekiq)
      → Passe 1 : ExtractQuestionsFromPdf (inchangée)
      → PersistExtractedData (inchangée)
      → Passe 2 : EnrichAllAnswers   ← NOUVEAU
          → EnrichStructuredCorrection (par question)
              → AiClientFactory.call (prompt POC 043)
              → answer.update!(structured_correction: json)
      → job.update!(status: :done)

rake subjects:enrich_structured_correction[ID]   ← NOUVEAU
  → Subject.find(ID).parts.flat_map(&:questions).map(&:answer)
  → filtre: structured_correction: nil
  → EnrichStructuredCorrection par question
```

## Fichiers créés / modifiés

### Nouveaux
```
app/services/enrich_structured_correction.rb
app/services/enrich_all_answers.rb
lib/tasks/subjects.rake
spec/services/enrich_structured_correction_spec.rb
spec/services/enrich_all_answers_spec.rb
spec/tasks/subjects_enrich_spec.rb
```

### Modifiés
```
app/jobs/extract_questions_job.rb  — appel EnrichAllAnswers après PersistExtractedData
```

### Inchangés
```
app/services/build_extraction_prompt.rb   — passe 1 identique
app/services/extract_questions_from_pdf.rb
app/services/persist_extracted_data.rb
app/services/tutor/build_context.rb       — déjà câblé (043)
db/schema.rb                              — migration déjà présente (043)
```

## Prompt d'enrichissement (source POC)

Le SYSTEM_PROMPT et `build_user_message` sont extraits verbatim de
`tmp/poc_043_enrich.rb` dans `EnrichStructuredCorrection`. Le prompt
a été validé sur 7 questions réelles (sim 043, run 24756326092).

**Input message par question** :
- Numéro + énoncé de la question
- Contexte local (`context_text`)
- Références DT/DTS, DR/DRS
- Data hints existants
- `correction_text`
- `explanation_text`
- Concepts clés

**max_tokens**: 4096 (suffisant pour 4 sections JSON d'une question)
**temperature**: 0.0 (extraction déterministe)

## Dégradation gracieuse

| Scénario | Comportement |
|---|---|
| Passe 2 — erreur API question N | Log warn, skip question N, continue sur N+1 |
| Passe 2 — toutes les questions en erreur | Job termine en `done`, toutes answers en `structured_correction: nil` |
| Passe 2 — JSON malformé | Rescue JSON::ParseError, log, skip |
| Rake task — erreur question N | Log, continue, résumé final avec compteur erreurs |

## Rake task — utilisation

```sh
# Enrichir un subject spécifique (ID=1)
bundle exec rake subjects:enrich_structured_correction[1]

# Enrichir tous les subjects avec answers manquantes
bundle exec rake subjects:enrich_structured_correction

# Relancer sans risque (idempotent — skips already-enriched answers)
bundle exec rake subjects:enrich_structured_correction[1]
```

**Output console attendu** :
```
Subject: CIME (ID: 1)
  A.1 ✓ enrichie
  A.2 ✓ enrichie
  A.3 ✗ erreur API: timeout
  A.4 ✓ enrichie (déjà enrichie — skipped)
  ...
Résumé: 6 enrichies, 1 skippée, 1 erreur
```

## Tests

### `EnrichStructuredCorrection`
- Appel LLM mocké (WebMock) — retourne JSON valide → result.ok? true
- JSON malformé → result.ok? false, result.error présent
- Erreur Faraday::TimeoutError → result.ok? false

### `EnrichAllAnswers`
- 3 answers dont 1 erreur → enriched: 2, errors: 1, lève pas d'exception
- Toutes réussies → enriched: 3, errors: 0

### `ExtractQuestionsJob`
- Après extraction réussie, `EnrichAllAnswers` est appelé (stub)
- Si `EnrichAllAnswers` lève → job toujours `done` (rescue dans job)

### Rake task
- Subject avec 2 answers nil + 1 déjà enrichie → enrichit 2, skip 1

# Data Model: Extraction — Structured Correction en production

## Entités existantes modifiées

### Answer (table `answers`)

Champ `structured_correction` déjà migré (migration 043, PR #57).

```
structured_correction : jsonb, nullable, default: null
```

**Structure JSON attendue** (inchangée depuis 043) :

```json
{
  "input_data": [
    {
      "name": "string — nom humain de la donnée",
      "value": "string — valeur exacte avec unité",
      "source": "string — 'DT<n>' | 'DTS<n>' | 'DR<n>' | 'DRS<n>' | 'question_context' | 'mise_en_situation' | 'question_precedente'"
    }
  ],
  "final_answers": [
    {
      "name": "string — nom du résultat à trouver",
      "value": "string — valeur ou réponse finale attendue",
      "reasoning": "string — formule ou raisonnement court"
    }
  ],
  "intermediate_steps": ["string", "string"],
  "common_errors": [
    {
      "error": "string — description courte",
      "remediation": "string — comment corriger"
    }
  ]
}
```

**Invariants** :
- `null` = pas encore enrichi (legacy ou erreur passe 2)
- JSON valide = enrichi (même si `final_answers: []` pour une question de type `dr_reference`)
- Aucune migration nécessaire

---

## Nouveaux services

### `EnrichStructuredCorrection`

```
app/services/enrich_structured_correction.rb
```

**Responsabilité** : Appeler le LLM pour enrichir UNE `Answer` avec `structured_correction`.

**Input** :
- `answer:` — instance `Answer` (doit avoir `correction_text`, `explanation_text`, `context_text`, `data_hints`, `key_concepts` chargés ; question associée via `answer.question`)
- `api_key:` — String
- `provider:` — Symbol (`:anthropic`, `:openrouter`, `:openai`, `:google`)

**Output** : `Result` struct
- `Result.new(ok: true, structured_correction: Hash)` — succès
- `Result.new(ok: false, error: String)` — échec (API, JSON parse, timeout)

**Règle** : Ne persiste PAS en DB. La persistance est à la charge de l'appelant
(job ou rake task), ce qui permet de tester le service sans effets de bord.

---

### `EnrichAllAnswers`

```
app/services/enrich_all_answers.rb
```

**Responsabilité** : Orchestrer l'enrichissement de TOUTES les answers d'un subject.
Appelé par le job Sidekiq après `PersistExtractedData`.

**Input** :
- `subject:` — instance `Subject` (rechargée après PersistExtractedData)
- `api_key:` — String
- `provider:` — Symbol

**Comportement** :
- Itère sur toutes les answers du subject (via parts → questions → answer)
- Pour chaque answer : appelle `EnrichStructuredCorrection`, persiste si succès, logue si erreur
- Ne lève jamais d'exception — capture tout et continue
- Retourne un résumé `{enriched: N, skipped: N, errors: N}`

---

## Rake task

```
lib/tasks/subjects.rake
namespace :subjects
  task enrich_structured_correction, [:subject_id] => :environment
```

**Filtre idempotent** : `Answer.where(structured_correction: nil)`

**Scope** :
- Avec `subject_id` : enrichit uniquement ce subject
- Sans argument : enrichit tous les subjects dont au moins une answer a `structured_correction: nil`

**Provider rake** : utilise `ResolveApiKey.call(user: subject.owner)` — même logique que le job.

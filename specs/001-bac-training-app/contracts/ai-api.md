# AI API Contract

**Branch**: `001-bac-training-app` | **Date**: 2026-03-26

## Interface unifiée AiClientFactory

Tous les appels IA passent par `AiClientFactory.build(provider:, api_key:)` qui retourne un objet avec :

```ruby
client.call(
  messages: Array<{role: "user"|"assistant", content: String}>,
  system: String,       # system prompt
  stream: Boolean,      # true pour SSE
  max_tokens: Integer,
  temperature: Float
) → String | Enumerator  # string si stream:false, enumerator si stream:true
```

## Providers supportés

| Provider | Base URL | Auth header |
|----------|----------|-------------|
| anthropic | https://api.anthropic.com/v1 | x-api-key |
| openrouter | https://openrouter.ai/api/v1 | Authorization: Bearer |
| openai | https://api.openai.com/v1 | Authorization: Bearer |
| google | https://generativelanguage.googleapis.com/v1beta | x-goog-api-key |

## Extraction PDF — JSON cible

```json
{
  "presentation": "Mise en situation générale...",
  "technical_documents": [
    {"type": "DT", "number": 1, "title": "Diagrammes SysML"}
  ],
  "parts": [{
    "number": 1,
    "title": "Titre de la partie",
    "objective": "Objectif pédagogique",
    "section_type": "common",
    "questions": [{
      "number": "1.2",
      "label": "Énoncé complet...",
      "context": "Contexte local optionnel",
      "points": 2,
      "answer_type": "calculation",
      "dt_dr_refs": ["DT1"],
      "correction": "Réponse officielle",
      "data_hints": [
        {"source": "DT1", "location": "tableau ligne Consommation"},
        {"source": "mise_en_situation", "location": "distance 186 km"}
      ],
      "key_concepts": ["énergie primaire", "rendement"]
    }]
  }]
}
```

## System prompt tutorat (base)

```
Tu es un tuteur bienveillant pour des élèves de Terminale préparant le BAC.
Spécialité : {specialty}. Partie : {part_title}. Objectif : {objective_text}.
Question : {question_label}. Contexte : {context_text}.
Correction officielle (confidentielle) : {correction_text}.
Règle absolue : ne donne JAMAIS la réponse directement.
Guide par étapes, valorise les tentatives, pose des questions.
Réponds en français, niveau lycée, de façon bienveillante.
```

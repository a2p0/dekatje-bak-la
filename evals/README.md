# evals/ — Évaluations LLM

Scripts de comparaison et d'évaluation des modèles LLM utilisés dans DekatjeBakLa.
Les résultats sont stockés dans `tmp/llm_comparison/` (gitignorés).

## Structure

```
evals/
├── extraction/          — Comparaison des pipelines d'extraction PDF
│   ├── run_comparison.rb    — Lance l'extraction (Opus vs Mistral OCR)
│   ├── judge.rb             — Dispatcher du juge (--mode pairwise|absolute)
│   ├── persist_winner.rb    — Sauvegarde le JSON gagnant en DB
│   └── judges/
│       ├── shared.rb            — Utilitaires communs
│       ├── pairwise_judge.rb    — Juge blind A/B (wins par critère)
│       └── absolute_judge.rb    — Juge absolu (notes 1-5 par critère)
└── tutor/               — Simulation et évaluation du tuteur IA
    └── (à venir)
```

## Résultats

```
tmp/llm_comparison/
├── extraction/results/<subject_id>/
│   ├── opus.json                    — Extraction Claude Opus 4.7
│   ├── mistral.json                 — Extraction Mistral Large 2512 (OCR)
│   ├── mistral_ocr_subject.md       — Markdown OCR du sujet
│   ├── mistral_ocr_correction.md    — Markdown OCR du corrigé
│   ├── pairwise_report.json         — Résultats juge pairwise
│   ├── pairwise_summary.md
│   ├── absolute_report.json         — Résultats juge absolu
│   └── absolute_summary.md
└── tutor/results/
    └── (à venir)
```

## Usage extraction

```bash
# 1. Lancer les extractions (skip automatique si JSON déjà présent)
source .env && bin/rails runner evals/extraction/run_comparison.rb <subject_id> [...]

# 2. Juger les résultats
source .env && bin/rails runner evals/extraction/judge.rb <subject_id> --mode pairwise
source .env && bin/rails runner evals/extraction/judge.rb <subject_id> --mode absolute

# 3. Persister le gagnant en DB
bin/rails runner evals/extraction/persist_winner.rb <subject_id> <opus|mistral>
```

## Variables d'environnement requises

| Variable | Usage |
|---|---|
| `ANTHROPIC_API_KEY` | Claude Opus 4.7 |
| `MISTRAL_API_KEY` | Mistral OCR + Mistral Large 2512 |
| `OPENROUTER_API_KEY` | Juge GPT-5.5 via OpenRouter |

## Critères d'évaluation

| Critère | Description |
|---|---|
| completude | Tous les champs présents (label, points, références) |
| verbatim | Fidélité mot pour mot au sujet original |
| data_hints | Précision des références aux documents (source + localisation) |
| structure | Conformité au schéma JSON attendu |
| pedagogique | Clarté et qualité pédagogique de l'explication |

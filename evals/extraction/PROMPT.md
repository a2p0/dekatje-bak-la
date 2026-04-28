# Comparatif d'extraction de sujets BAC STI2D

## Objectif

Comparer la qualité et le coût de plusieurs LLMs pour l'extraction structurée de sujets d'examens BAC STI2D à partir de PDFs (sujet + corrigé) en JSON structuré.

## Contexte projet

DekatjeBakLa est une application Rails d'entraînement aux examens BAC pour les élèves de Terminale STI2D. L'enseignant uploade un sujet PDF et son corrigé. Un LLM extrait automatiquement les questions, corrections, explications pédagogiques et métadonnées en JSON structuré. Ce JSON est ensuite persisté en base (Subject → Parts → Questions → Answers).

Le JSON extrait sert ensuite au **tutorat IA** : les `data_hints` guident l'élève vers les bonnes sources, les `explanation` fournissent le feedback pédagogique, les `context` restituent les données nécessaires à chaque question.

## Fichiers de référence

- `app/services/build_extraction_prompt.rb` — le prompt d'extraction (system prompt + user message)
- `app/services/extract_questions_from_pdf.rb` — le service qui extrait le texte du PDF et appelle le LLM
- `app/services/ai_client_factory.rb` — le client multi-provider (Anthropic, OpenRouter, OpenAI, Google)
- `tmp/extraction_comparison/run_comparison.rb` — script de test Claude + DeepSeek
- `tmp/extraction_comparison/run_mistral.rb` — script de test Mistral Small + Large
- `tmp/extraction_comparison/rapport_comparatif.md` — rapport des résultats précédents (2026-04-07)

## Comment lancer une comparaison

### Prérequis

```bash
# Variables d'environnement requises
export ANTHROPIC_API_KEY=...    # pour Claude via API Anthropic
export OPENROUTER_API_KEY=...   # pour DeepSeek, Mistral, etc. via OpenRouter

# L'app Rails doit être fonctionnelle avec la base de données connectée
# Le sujet à tester doit exister en base avec subject_pdf et correction_pdf attachés
bin/rails runner "Subject.find(1).subject_pdf.attached? && Subject.find(1).correction_pdf.attached? ? puts('OK') : puts('MISSING')"
```

### Lancer les scripts existants

```bash
# Claude Sonnet + DeepSeek v3.2
bin/rails runner tmp/extraction_comparison/run_comparison.rb

# Mistral Small 3.2 + Mistral Large 2512
bin/rails runner tmp/extraction_comparison/run_mistral.rb
```

### Ajouter un nouveau modèle

Dans le script `run_comparison.rb` ou `run_mistral.rb`, ajouter une entrée dans le hash `providers` ou `models` :

```ruby
"nom-du-modele" => {
  model: "provider/model-id",  # ID OpenRouter du modèle
  file: "nom_fichier.json"
}
```

Pour un provider non-OpenRouter (ex: Anthropic direct), utiliser `call_anthropic()` au lieu de `call_openrouter()`.

### Paramètres importants

| Paramètre | Valeur recommandée | Pourquoi |
|-----------|-------------------|----------|
| `max_tokens` | 32 768 minimum | Un sujet complet (42 questions) génère ~20k tokens output. Avec 16 384, tous les modèles tronquent. |
| `temperature` | 0.1 | Extraction factuelle, on veut du déterminisme. |
| `timeout` | 900s | Claude Sonnet peut prendre jusqu'à 600s pour 32k tokens output. |

## Critères d'évaluation

### Critères obligatoires (bloquants)

1. **Complétude** — toutes les questions extraites (42 pour le sujet CIME). Vérifier le nombre de questions par partie.
2. **Structure JSON valide** — le JSON doit être parsable sans erreur.
3. **Convention DTS/DRS** — les parties spécifiques utilisent DTS1/DRS1, pas DT/DR générique.
4. **Numérotation** — parties spécifiques numérotées en lettres (A, B, C), pas en chiffres.

### Critères de qualité (classants)

Par ordre d'importance pour le tutorat élève :

| # | Critère | Comment mesurer | Seuil acceptable |
|---|---------|-----------------|------------------|
| 1 | **`question_precedente`** | Compter les data_hints avec `source: "question_precedente"` | ≥10 sur 42 questions |
| 2 | **Présentation verbatim** | Longueur du champ `presentation` en caractères | ≥2000 chars (texte complet) |
| 3 | **data_hints volume** | Moyenne de data_hints par question | ≥1.5 |
| 4 | **data_hints sources numérotées** | Vérifier que les sources sont `DT2`, `DTS1`, pas `DT` générique | 100% numérotées |
| 5 | **Corrections non-paresseuses** | Compter les corrections contenant "Voir DR" ou "Voir document" | ≤5 |
| 6 | **Explanations détaillées** | Longueur moyenne des explanations | ≥300 chars |
| 7 | **Context rempli** | % de questions avec context non vide | ≥50% |
| 8 | **Context correct** | Vérifier manuellement Q1.1 (doit être vide) et Q1.2 (doit contenir le tableau) | Pas d'erreur de placement |

### Critères économiques

| Critère | Comment calculer |
|---------|-----------------|
| Coût input | (taille system + user en chars / 4) × prix_input / 1M |
| Coût output | (taille JSON output en chars / 4) × prix_output / 1M |
| Temps | Mesuré par le script |

### Tarifs connus (avril 2026)

| Modèle | Provider | Input $/M | Output $/M |
|--------|----------|-----------|------------|
| Claude Sonnet 4.6 | Anthropic | $3.00 | $15.00 |
| DeepSeek v3.2 | OpenRouter | $0.80 | $1.60 |
| Mistral Small 3.2 | OpenRouter | $0.07 | $0.20 |
| Mistral Large 2512 | OpenRouter | $0.50 | $1.50 |

Pour les tarifs à jour : `curl -s "https://openrouter.ai/api/v1/models" -H "Authorization: Bearer $OPENROUTER_API_KEY" | python3 -c "import json,sys; [print(f'{m[\"id\"]:50s} \${float(m[\"pricing\"][\"prompt\"])*1e6:.2f}/M in \${float(m[\"pricing\"][\"completion\"])*1e6:.2f}/M out') for m in json.load(sys.stdin)['data'] if 'KEYWORD' in m['id'].lower()]"`

## Résultats de référence (2026-04-07, sujet CIME AC)

| Modèle | Coût | Temps | Questions | Présentation | data_hints/q | question_prec. | Explanations | Corrections paresseuses |
|--------|------|-------|-----------|-------------|-------------|----------------|-------------|------------------------|
| Claude Sonnet 4.6 | $0.396 | 432s | 42 | 3086c (complet) | 2.1 | 16 | 419c | 2 |
| DeepSeek v3.2 | $0.052 | 287s | 42 | 1835c (tronqué) | 1.9 | 16 | 429c | 13 |
| Mistral Large 2512 | $0.035 | 295s | 42 | 1835c (tronqué) | 1.2 | 3 | 213c | 13 |
| Mistral Small 3.2 | $0.005 | 123s | 42 | 1827c (tronqué) | 1.0 | 0 | 144c | 10 |

### Classement qualité : Claude > DeepSeek >> Mistral Large > Mistral Small
### Meilleur rapport qualité/prix : DeepSeek v3.2

## Comment analyser les résultats

### Script rapide de comptage

```bash
bin/rails runner '
require "json"

Dir.glob("tmp/extraction_comparison/*.json").sort.each do |file|
  name = File.basename(file, ".json")
  raw = File.read(file)

  # Strip markdown code fences if present
  json_str = raw.match(/\{.*\}/m)&.to_a&.first
  next puts "#{name}: INVALID JSON" unless json_str

  data = JSON.parse(json_str) rescue next

  common_q = (data["common_parts"] || []).sum { |p| (p["questions"] || []).size }
  specific_q = (data["specific_parts"] || []).sum { |p| (p["questions"] || []).size }
  total_q = common_q + specific_q

  all_questions = (data["common_parts"] || []).flat_map { |p| p["questions"] || [] } +
                  (data["specific_parts"] || []).flat_map { |p| p["questions"] || [] }

  hints = all_questions.flat_map { |q| q["data_hints"] || [] }
  hint_sources = hints.map { |h| h["source"] }.tally
  q_prec = hint_sources["question_precedente"] || 0

  contexts_filled = all_questions.count { |q| q["context"].to_s.strip != "" }
  lazy_corrections = all_questions.count { |q| q["correction"].to_s.match?(/\bvoir\b/i) }

  expl_lengths = all_questions.map { |q| (q["explanation"] || "").length }
  avg_expl = expl_lengths.any? ? (expl_lengths.sum.to_f / expl_lengths.size).round(0) : 0

  pres_len = (data["presentation"] || "").length

  puts "#{name.ljust(20)} | #{total_q} Q | pres=#{pres_len}c | hints=#{hints.size} (#{(hints.size.to_f/total_q).round(1)}/q) | q_prec=#{q_prec} | ctx=#{contexts_filled}/#{total_q} | expl=#{avg_expl}c | lazy=#{lazy_corrections}"
end
'
```

### Analyse manuelle

Pour chaque nouveau modèle, vérifier manuellement :
1. **Q1.1** — context doit être vide (les données viennent de la mise en situation, pas d'un contexte local)
2. **Q1.2** — context doit contenir le tableau des modes de transport avec distance (186 km), consommation, émissions, places, coût
3. **Q1.3** — data_hints doit inclure `question_precedente` (résultats de Q1.2 nécessaires)
4. **Q2.1** — data_hints doit référencer `DT2` (pas `DT` générique), location doit mentionner le tableau comparatif

## Réutilisation pour le comparatif tuteur élève

Ce même protocole peut être adapté pour comparer les LLMs sur le tutorat :
- Remplacer `BuildExtractionPrompt` par `BuildTutorPrompt`
- Adapter les critères : respect de la non-divulgation, guidage progressif, bienveillance, utilisation des data_hints
- Prévoir des conversations multi-tours (pas un prompt unique) — voir la simulation tuteur sur la branche `014-tutor-simulation`
- Les mêmes modèles devraient être testés : Claude, DeepSeek, Mistral Large, Mistral Small

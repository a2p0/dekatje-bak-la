# Rapport comparatif — Extraction BAC STI2D CIME 2024

Date : 2026-04-07
Sujet : Subject #1 (CIME, spécialité AC, 42 questions)

---

## Fichiers comparés

| Fichier | Prompt | Provider | Modèle | max_tokens | Temps | Taille |
|---------|--------|----------|--------|------------|-------|--------|
| `original.json` | Ancien | Anthropic | Claude Sonnet | 16 384 | — | 45 084 chars |
| `claude.json` | Nouveau | Anthropic | Claude Sonnet 4.6 | 32 768 | 432s | 83 471 chars |
| `deepseek.json` | Nouveau | OpenRouter | DeepSeek v3.2 | 32 768 | 287s | 78 778 chars |
| `mistral_small.json` | Nouveau | OpenRouter | Mistral Small 3.2 | 32 768 | 123s | 52 690 chars |
| `mistral_large.json` | Nouveau | OpenRouter | Mistral Large 2512 | 32 768 | 295s | 57 965 chars |

---

## 1. Complétude

| Parties | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Commune 1 | 6 Q | 6 Q | 6 Q | 6 Q | 6 Q |
| Commune 2 | 6 Q | 6 Q | 6 Q | 6 Q | 6 Q |
| Commune 3 | 5 Q | 5 Q | 5 Q | 5 Q | 5 Q |
| Commune 4 | 5 Q | 5 Q | 5 Q | 5 Q | 5 Q |
| Commune 5 | 5 Q | 5 Q | 5 Q | 5 Q | 5 Q |
| **Total communes** | **27** | **27** | **27** | **27** | **27** |
| Spécifique A | 7 Q | 7 Q | 7 Q | 7 Q | 7 Q |
| Spécifique B | 5 Q | 5 Q | 5 Q | 5 Q | 5 Q |
| Spécifique C | 3 Q | 3 Q | 3 Q | 3 Q | 3 Q |
| **Total spécifiques** | **15** | **15** | **15** | **15** | **15** |
| **TOTAL** | **42** | **42** | **42** | **42** | **42** |
| common_dts | 13 | 13 | 13 | 13 | 13 |
| common_drs | 6 | 6 | 6 | 6 | 6 |
| specific_dts | 4 | 4 | 4 | 4 | 4 |
| specific_drs | 4 | 4 | 4 | 4 | 4 |

Les cinq extractions sont strictement identiques en complétude. Aucune question manquante.

Note : avec max_tokens=16 384, Claude s'arrêtait à Q5.3 (25 questions) et DeepSeek à QA.2 (29 questions). Le passage à 32 768 a résolu le problème de troncature pour tous les modèles.

---

## 2. Présentation (mise en situation)

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Longueur | 437 chars | **3 086 chars** | 1 835 chars | 1 827 chars | 1 835 chars |
| Type | Résumé | **Verbatim complet** | Verbatim tronqué | Verbatim tronqué | Verbatim tronqué |

### Détail

- **Original** : résumé synthétique de 3 lignes. Perd les informations sur la superficie, la SAE, les tribunes, etc.
- **Claude 4.6** : texte complet avec tous les paragraphes — superficie (5000 m²), SAE 18 m, matériaux, circuits courts, économie locale, liste des fonctions du complexe, tribunes (500 places, 50 PMR, 20 presse, extension à 3000), aire multisports, vestiaires.
- **DeepSeek, Mistral Small, Mistral Large** : texte verbatim quasi-identique (~1835 chars) mais tronqué après "encourager la pratique du handisport de haut niveau". Manque la description des espaces intérieurs (tribunes, aire multisports, vestiaires).

**Gagnant : Claude 4.6** — seul à restituer la totalité de la mise en situation.

---

## 3. data_hints

### Volume et diversité des sources

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Total hints | 42 | **89** | **80** | 42 | 49 |
| Moyenne/question | 1.0 | **2.1** | **1.9** | 1.0 | 1.2 |
| Questions avec hints | 38/42 | **42/42** | 41/42 | 36/42 | 39/42 |

### Sources utilisées

| Source | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|--------|----------|------------|---------------|---------------|---------------|
| `DT`/`DR` (générique) | Oui | Non | Non | Non | Non |
| `enonce` | Oui | Non | Non | Non | Non |
| DT numérotés (DT1-DT13) | Non | **Oui** | **Oui** | **Oui** | **Oui** |
| DR numérotés (DR1-DR6) | Non | **Oui** | **Oui** | **Oui** | **Oui** |
| DTS1-DTS4 | Non | **Oui** | **Oui** | **Oui** | **Oui** |
| DRS1-DRS4 | Non | **Oui** | **Oui** | **Oui** | **Oui** |
| `mise_en_situation` | Non | **Oui** (2) | **Oui** (3) | **Oui** (1) | **Oui** (2) |
| `question_context` | Oui (3) | **Oui** (29) | **Oui** (25) | Oui (6) | Oui (7) |
| `question_precedente` | Non | **Oui** (16) | **Oui** (16) | **Non** (0) | Oui (3) |
| `question_label` | Non | Non | **Oui** | Non | Non |

### Exemples concrets

**Q1.1** (piliers du développement durable) :
- Original : 1 hint générique `{"source": "DT", "location": "Diagrammes SysML du complexe sportif « CIME »"}`
- Claude : 2 hints `mise_en_situation` (paragraphes matériaux, circuits courts, handisport, économie locale) + `DT1` (diagrammes SysML : mission, exploitation, besoins)
- DeepSeek : 4 hints détaillés (3× `mise_en_situation` + `DT1`)
- Mistral Small : 1 seul hint `mise_en_situation`
- Mistral Large : 2 hints (`mise_en_situation` + `DT1`)

**Q2.1** (bois lamellé collé vs bois massif) :
- Original : `{"source": "DT", "location": "Comparatif entre le bois massif et le bois lamellé collé"}`
- Claude : `{"source": "DT2", "location": "tableau comparatif, ligne Longueur maximale du poteau (m) : bois massif = 7 m, bois lamellé collé = 45 m"}`
- DeepSeek : `{"source": "DT2", "location": "tableau comparatif, ligne Longueur maximale du poteau (m)"}`
- Mistral Small : 1 hint `DT2` (manque la donnée "12 m" de l'énoncé)
- Mistral Large : 1 hint `DT2` (manque aussi la donnée "12 m")

**Q1.3** (nombre de véhicules + coût) :
- Original : 1 hint `{"source": "enonce"}`
- Claude : 3 hints (`question_context` + `question_precedente` → Q1.2 + `mise_en_situation` → 91 personnes)
- DeepSeek : 3 hints similaires
- Mistral Small : 1 hint `question_context` uniquement
- Mistral Large : 1 hint `question_context` uniquement

**Constat critique** : `question_precedente` est le marqueur le plus discriminant. Claude et DeepSeek en génèrent 16 chacun. Mistral Large : 3. Mistral Small : **zéro**. C'est critique pour le tutorat car de nombreuses questions BAC STI2D sont chaînées.

---

## 4. Context (texte introductif)

### Volume

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Context vide | 28 (67%) | 18 (43%) | 17 (40%) | 25 (60%) | **15 (36%)** |
| Context rempli | 14 (33%) | **24 (57%)** | **25 (60%)** | 17 (40%) | **27 (64%)** |

### Q1.2 — tableau des modes de transport

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Longueur context | 134 chars | **1 107 chars** | 578 chars | 264 chars | 488 chars |
| Tableau complet | Non | **Oui** | Partiel | Partiel | **Oui** (format markdown) |
| Distance 186 km | Non | **Oui** | Non (!) | **Oui** | **Oui** |
| 91 personnes | Non | **Oui** | Non | **Oui** | **Oui** |

### Erreurs de placement

- **DeepSeek Q1.1** : place le contexte introductif de la sous-partie transport (distance 186 km, délégation 91 personnes) dans le `context` de Q1.1 alors qu'il appartient à Q1.2. Claude laisse correctement Q1.1 sans contexte.
- **Mistral Large** : le plus de contexts remplis (27/42) mais qualité à vérifier au cas par cas.
- **Mistral Small** : minimaliste, 25 contexts vides.

---

## 5. Explanations

### Volume

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Longueur moyenne | 88 chars | **419 chars** | **429 chars** | 144 chars | 213 chars |
| Min / Max | 58 / 131 | 216 / 663 | 204 / 785 | — | — |
| Ratio vs Original | 1× | **4.8×** | **4.9×** | 1.6× | 2.4× |

### Exemples

**Q1.2** (consommation car / van) :
- Original (91c) : *"Calcul de la consommation énergétique pour chaque mode de transport sur la distance donnée."*
- Claude (284c) : formules complètes, calculs avec résultats (56,73 l, 38,68 kWh), cite les sources
- DeepSeek (269c) : similaire à Claude, formules + résultats + source
- Mistral Small (220c) : formules présentes mais notation "1,86" au lieu de "186 km / 100" — potentiellement confus
- Mistral Large (159c) : formules correctes mais sans mention de la source des données

**QA.1** (résistances thermiques) :
- Claude (440c) : cite R = e/λ, mentionne DTS1 et DRS1, donne Rse et Rsi
- DeepSeek (413c) : similaire, mentionne DTS1
- Mistral Small (107c) : juste la formule, aucune référence documentaire
- Mistral Large (174c) : formule + mention DRS1 mais plus court

### Note positive DeepSeek

Sur Q2.3 (contrainte sigma), DeepSeek signale une incohérence entre la force annoncée (250 kN) et les résultats du corrigé (0.21 MPa), montrant un esprit critique que les autres modèles n'ont pas eu.

---

## 6. Corrections "paresseuses" (type "Voir DR...")

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| Nb corrections "Voir..." | 4 | **2** | 13 | 10 | 13 |

- **Claude** : le moins de renvois paresseux (2), dont Q4.4 qui est un algorigramme (difficile à transcrire en texte).
- **Mistral Small/Large et DeepSeek** : 10-13 renvois "Voir DRx" sans détail. Mistral Small est le pire avec des renvois secs ("Voir document réponses DR2." point final).

---

## 7. Convention DTS/DRS et numérotation

| Critère | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---------|----------|------------|---------------|---------------|---------------|
| dt_references | DTS1-4 | DTS1-4 | DTS1-4 | DTS1-4 | DTS1-4 |
| dr_references | DRS1-4 | DRS1-4 | DRS1-4 | DRS1-4 | DRS1-4 |
| data_hints.source | `DT`/`DR` génériques | **DTS1, DRS1...** | **DTS1, DRS1...** | **DTS1, DRS1...** | **DTS1, DRS1...** |
| Parties spécifiques | A, B, C | A, B, C | A, B, C | A, B, C | A, B, C |

L'original est incohérent (dt_references correct mais data_hints générique). Tous les nouveaux sont cohérents partout.

---

## 8. Coût approximatif

| | Original | Claude 4.6 | DeepSeek v3.2 | Mistral Small | Mistral Large |
|---|----------|------------|---------------|---------------|---------------|
| Input (~25k tokens) | — | $0.075 | $0.020 | $0.002 | $0.013 |
| Output (estimé) | — | $0.321 | $0.032 | $0.003 | $0.022 |
| **Total** | — | **$0.396** | **$0.052** | **$0.005** | **$0.035** |
| **Ratio vs Claude** | — | 1× | 7.6× ↓ | **88× ↓** | 11.3× ↓ |
| **Temps** | — | 432s | 287s | **123s** | 295s |

Tarifs (par million de tokens) :
- Claude Sonnet 4.6 : $3 input / $15 output
- DeepSeek v3.2 via OpenRouter : $0.80 input / $1.60 output
- Mistral Small 3.2 via OpenRouter : $0.07 input / $0.20 output
- Mistral Large 2512 via OpenRouter : $0.50 input / $1.50 output

Pour 10-20 sujets/an : Claude ~$4-8 / DeepSeek ~$0.50-1 / Mistral Small ~$0.05-0.10 / Mistral Large ~$0.35-0.70

---

## Synthèse

### Classement qualité

| Rang | Modèle | Forces | Faiblesses |
|------|--------|--------|------------|
| **1** | **Claude Sonnet 4.6** | data_hints les plus riches (89, 2.1/q), 16 `question_precedente`, explanations détaillées (419c), présentation verbatim complète, 2 corrections paresseuses | Le plus cher ($0.40), le plus lent (432s) |
| **2** | **DeepSeek v3.2** | Très proche de Claude (80 hints, 1.9/q), 16 `question_precedente`, explanations équivalentes (429c), esprit critique | 13 corrections paresseuses, oublie 186km dans Q1.2 context, erreur placement Q1.1 |
| **3** | **Mistral Large 2512** | Plus de contexts remplis (27/42), convention DTS/DRS correcte | data_hints pauvres (49, 1.2/q), seulement 3 `question_precedente`, 13 corrections paresseuses, explanations courtes (213c) |
| **4** | **Mistral Small 3.2** | Ultra-rapide (123s), ultra-économique ($0.005), structure complète | data_hints les plus pauvres (42, 1.0/q), **0** `question_precedente`, 10 corrections paresseuses, explanations minimales (144c) |
| **5** | **Original** | Baseline | Résumé, références génériques, pas de `question_precedente` |

### Classement rapport qualité/prix

| Rang | Modèle | Coût | Qualité vs Claude | Verdict |
|------|--------|------|-------------------|---------|
| **1** | **DeepSeek v3.2** | $0.052 | ~95% | Meilleur compromis global |
| **2** | **Mistral Large 2512** | $0.035 | ~70% | Utilisable si data_hints enrichis post-extraction |
| **3** | **Claude Sonnet 4.6** | $0.396 | 100% (référence) | Justifié si qualité maximale requise |
| **4** | **Mistral Small 3.2** | $0.005 | ~50% | Insuffisant pour le tutorat (pas de chaînage, explanations trop courtes) |

---

## Enseignements pour les comparatifs futurs

### Méthodologie

1. **Toujours tester avec max_tokens suffisant** — 32 768 minimum pour un sujet BAC complet (42 questions). Avec 16 384, tous les modèles tronquent.
2. **Timeout API** — Claude Sonnet nécessite 600-900s pour 32k tokens output. Prévoir un timeout de 900s. DeepSeek et Mistral sont plus rapides (~300s max).
3. **Sauvegarder les JSON bruts** — permet de re-analyser sans relancer les extractions (coûteuses en tokens et en temps).
4. **Comparer sur le même sujet** — un seul sujet suffit pour une première évaluation, mais tester sur 2-3 sujets différents avant de fixer un provider en prod.

### Critères discriminants identifiés

Pour l'extraction de sujets :
- **`question_precedente`** : marqueur le plus discriminant. Seuls Claude et DeepSeek le génèrent systématiquement (16/42). Critique pour le tutorat (questions chaînées).
- **Présentation verbatim** : seul Claude restitue le texte complet. Les 3 autres tronquent au même endroit.
- **Corrections paresseuses** ("Voir DRx") : Claude en a 2, les autres 10-13. Impact direct sur la qualité du feedback élève.
- **Explanations détaillées** : Claude et DeepSeek ~420c, Mistral Large ~213c, Mistral Small ~144c. Le seuil de qualité pédagogique semble autour de 300c.

### À réutiliser pour le comparatif tuteur élève

- Le script `run_comparison.rb` / `run_mistral.rb` est réutilisable : changer le prompt et les fichiers de sortie.
- Les mêmes 4-5 modèles devraient être testés pour le tuteur.
- Critères spécifiques au tuteur à définir : respect de la consigne "ne jamais donner la réponse", qualité du guidage progressif, adaptation au profil élève, utilisation des data_hints dans le contexte.
- Prévoir un protocole avec des conversations multi-tours (pas juste un prompt unique) pour évaluer le tutorat.

---

## Points à explorer

- Augmenter le `max_tokens` et le `timeout` dans `AiClientFactory` pour la prod
- Envisager le découpage du PDF en amont (questions, DT, DR) pour réduire l'input et le coût
- Corriger le code Rails de persistence pour exploiter les nouvelles données (context, data_hints numérotés)
- Tester sur un 2e sujet pour valider la robustesse du prompt

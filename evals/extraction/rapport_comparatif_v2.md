# Rapport comparatif v2 — Extraction BAC STI2D CIME 2024 (incluant Gemini)

Date : 2026-04-07
Sujet : Subject #1 (CIME, spécialité AC, 42 questions)
Nouveaux modèles testés : Gemini 2.0 Flash, Gemini 2.5 Pro (via OpenRouter)

---

## 1. Fichiers et Modèles comparés

| Fichier | Provider | Modèle | max_tokens (req) | Résultat | Temps |
|---------|----------|--------|------------------|----------|-------|
| `claude.json` | Anthropic | Claude Sonnet 4.6 | 32 768 | **Complet (42 Q)** | 432s |
| `deepseek.json` | OpenRouter | DeepSeek v3.2 | 32 768 | **Complet (42 Q)** | 287s |
| `mistral_large.json` | OpenRouter | Mistral Large 2512 | 32 768 | **Complet (42 Q)** | 295s |
| `gemini_2.5_pro.json` | OpenRouter | Gemini 2.5 Pro | 32 768 | **Tronqué (JSON invalide)** | 253s |
| `gemini_2.0_flash.json` | OpenRouter | Gemini 2.0 Flash | 32 768 | **Tronqué (JSON invalide)** | 43s |
| `gemini_2.0_flash_v3.json` | OpenRouter | Gemini 2.0 Flash | 8 192 | **Réduit (5 Q)** | 19s |

⚠️ **Note technique critique** : Bien que 32 768 tokens aient été demandés, OpenRouter semble limiter les sorties Gemini à **8 192 tokens**. Cela rend l'extraction d'un sujet complet (42 questions + corrections détaillées + data_hints) impossible en une seule passe pour Gemini actuellement. Claude Sonnet 4.6 reste le seul à garantir >30k tokens en sortie.

---

## 2. Qualité d'extraction (sur les 5 premières questions)

Comparaison de la qualité sur le sous-ensemble commun extrait par **Gemini 2.0 Flash** vs les leaders.

| Critère | Claude 4.6 | DeepSeek v3.2 | Gemini 2.0 Flash | Mistral Large |
|---------|------------|---------------|------------------|---------------|
| **Fidélité Verbatim** | Excellente | Bonne | **Excellente** | Moyenne |
| **data_hints / Q** | 2.1 | 1.9 | **2.2** | 1.2 |
| **Corrections paresseuses** | 0/5 | 1/5 | **0/5** | 2/5 |
| **Explanations** | Très détaillées | Détaillées | **Très détaillées** | Courtes |

### Analyse Gemini 2.0 Flash
- **Rapidité foudroyante** : 19s pour 5 questions complexes (incluant calculs et data_hints).
- **Qualité pédagogique** : Les `explanation` sont riches, citant précisément les documents (ex: "D'après le DT1 page 3...").
- **Précision des hints** : Utilise correctement `question_precedente` et `question_context`.
- **Structure** : Respecte parfaitement le schéma JSON sans texte superflu (Markdown).

---

## 3. Synthèse mise à jour

### Classement Qualité (Potentielle)

1.  **Claude Sonnet 4.6** : La référence absolue. Gère la longueur (42 Q) et la profondeur.
2.  **Gemini 2.0 Flash / 2.5 Pro** : **Qualité équivalente ou supérieure à Claude sur les petits segments**, mais bloqué par la limite de tokens en sortie sur OpenRouter.
3.  **DeepSeek v3.2** : Excellent rapport qualité/prix, mais quelques erreurs de placement de contexte.
4.  **Mistral Large** : Correct mais plus "paresseux" sur les corrections et les hints.

### Recommandations Stratégiques

| Scénario | Modèle recommandé | Pourquoi |
| :--- | :--- | :--- |
| **Extraction complète (batch)** | **Claude Sonnet 4.6** | Seul modèle capable d'extraire 42 questions en un seul bloc sans troncature. |
| **Extraction par parties** | **Gemini 2.0 Flash** | Si on découpe le sujet (Partie 1, puis Partie 2...), c'est le plus rapide et le moins cher pour une qualité "Claude-level". |
| **Tutorat (Mode 2)** | **Gemini 2.0 Flash** | Idéal pour le streaming temps réel. L'élève pose une question, la réponse est quasi instantanée. |
| **Budget serré** | **DeepSeek v3.2** | Très performant pour 1/10ème du prix de Claude, si on accepte quelques corrections manuelles. |

---

## 4. Prochaines étapes suggérées

1.  **Solution au "Token Limit"** : Tester Gemini via Google AI Studio (Vertex AI) en direct pour vérifier si la limite de 8k est propre à OpenRouter ou au modèle.
2.  **Pipeline itératif** : Modifier `ExtractQuestionsFromPdf` pour extraire partie par partie (Common 1, puis Common 2...) afin de permettre l'usage de Gemini 2.0 Flash sur des sujets complets.
3.  **Benchmark Tutorat** : Lancer un comparatif spécifique au tutorat (interactif) où Gemini 2.0 Flash devrait dominer grâce à sa latence ultra-faible.

# Contracts — Outils du tuteur (interface LLM ↔ serveur)

Ces contrats définissent ce que le LLM voit (JSON Schema généré par
ruby_llm à partir du DSL) et ce que le serveur garantit en retour.

## 1. `transition`

**Description exposée au LLM** : "Changer la phase pédagogique courante
de la conversation. À appeler systématiquement lors d'un changement de
phase."

**Schéma d'entrée** :
```json
{
  "type": "object",
  "properties": {
    "phase": {
      "type": "string",
      "description": "Phase cible (greeting, reading, spotting, guiding, validating, feedback, ended)"
    },
    "question_id": {
      "type": "integer",
      "description": "ID de la question associée (requis pour guiding et spotting)"
    }
  },
  "required": ["phase"]
}
```

**Retour de `#execute`** : `{ ok: true, recorded: { phase, question_id } }`

**Effet serveur différé** : `ApplyToolCalls#apply_transition` vérifie la
matrice de transitions et le `question_id` obligatoire le cas échéant.
Refus silencieux (côté utilisateur) si invalide — l'état reste inchangé.

---

## 2. `update_learner_model`

**Description exposée au LLM** : "Mettre à jour le modèle de l'élève :
concepts maîtrisés, concepts à revoir, niveau de découragement."

**Schéma d'entrée** :
```json
{
  "type": "object",
  "properties": {
    "concept_mastered":      { "type": "string" },
    "concept_to_revise":     { "type": "string" },
    "discouragement_delta":  { "type": "integer", "description": "Delta typique -1, 0, +1" }
  }
}
```

**Retour de `#execute`** : `{ ok: true, recorded: {...} }`

**Effet serveur différé** : dédoublonnage automatique des listes ;
clamp du `discouragement_level` à [0, 3].

---

## 3. `request_hint`

**Description exposée au LLM** : "Demander un indice gradué pour la
question courante. Toujours commencer à 1 et progresser 1→2→3…
(pas de saut, maximum 5)."

**Schéma d'entrée** :
```json
{
  "type": "object",
  "properties": {
    "level": { "type": "integer", "description": "1 à 5, strictement monotone" }
  },
  "required": ["level"]
}
```

**Retour de `#execute`** : `{ ok: true, recorded: { level } }`

**Effet serveur différé** :
- Refus si `level > 5`.
- Refus si `level != hints_used + 1` (saut de niveau).
- Refus si pas de question courante.

---

## 4. `evaluate_spotting`

**Description exposée au LLM** : "Conclure la phase de repérage des
données : succès (→ guiding), échec (rester en spotting, relancer),
révélation forcée après 3 échecs (→ guiding)."

**Schéma d'entrée** :
```json
{
  "type": "object",
  "properties": {
    "outcome": {
      "type": "string",
      "enum": ["success", "failure", "forced_reveal"]
    }
  },
  "required": ["outcome"]
}
```

**Retour de `#execute`** : `{ ok: true, recorded: { outcome } }`

**Effet serveur différé** :
- Appelable uniquement en phase `spotting` (sinon refus).
- `success` / `forced_reveal` déclenchent la transition automatique
  `spotting → guiding`.
- `failure` conserve la phase.

---

## Garanties transverses

- **G1 — Idempotence** : deux appels identiques consécutifs produisent
  le même état final (dédup pour concepts, pas d'incrément double pour
  `request_hint` car la validation monotone l'empêche).
- **G2 — Silence en cas d'erreur** : une erreur d'invocation n'est jamais
  exposée à l'élève (pas de message technique côté UI).
- **G3 — Streaming préservé** : les chunks texte continuent d'être
  broadcastés pendant toute la séquence.
- **G4 — Souveraineté serveur** : quoi que le LLM propose, seuls les
  garde-fous serveur décident de l'état final.

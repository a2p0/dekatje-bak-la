# Data Model: Refonte phases tuteur + answer_type

## Entités modifiées

### Question#answer_type (migration enum)

**Avant** (6 valeurs) :
```ruby
{ text: 0, calculation: 1, argumentation: 2, dr_reference: 3, completion: 4, choice: 5 }
```

**Après** (7 valeurs) :
```ruby
{ identification: 0, calcul: 1, justification: 2, representation: 3, qcm: 4, verification: 5, conclusion: 6 }
```

**Mapping de migration** :

| Ancien int | Ancien label | Nouveau int | Nouveau label |
|-----------|--------------|-------------|---------------|
| 0 | text | 0 | identification |
| 1 | calculation | 1 | calcul |
| 2 | argumentation | 2 | justification |
| 3 | dr_reference | 3 | representation |
| 4 | completion | 3 | representation |
| 5 | choice | 4 | qcm |
| _(nouveau)_ | — | 5 | verification |
| _(nouveau)_ | — | 6 | conclusion |

Migration SQL :
```sql
UPDATE questions SET answer_type = 3 WHERE answer_type = 4;  -- completion → representation
UPDATE questions SET answer_type = 4 WHERE answer_type = 5;  -- choice → qcm
-- text(0), calculation(1), argumentation(2), dr_reference(3) conservent leur int
```

---

### TutorState (JSONB — évolution sans migration schéma)

**Champs ajoutés** :

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `last_activity_at` | String ISO8601 ou nil | nil | Dernière activité tuteur, pour re-greeting 12h |

**Champs existants inchangés** : `current_phase`, `current_question_id`, `concepts_mastered`, `concepts_to_revise`, `discouragement_level`, `question_states`, `welcome_sent`

**Compatibilité ascendante** : les `TutorState` en base sans `last_activity_at` désérialisent avec `nil` par défaut.

---

### QuestionState (JSONB embarqué dans TutorState)

**Champ ajouté** :

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `phase` | String | `"enonce"` | Phase courante pour CETTE question |

**Phases valides pour QuestionState#phase** :
`enonce`, `spotting_type`, `spotting_data`, `guiding`, `validating`, `feedback`, `ended`

**Compatibilité ascendante** : les `QuestionState` existants sans `phase` désérialisent avec `phase: "enonce"` par défaut.

---

## Transitions de phases

### Matrice globale

```
idle ──→ greeting ──→ enonce
                        │
                        ├─→ spotting_type ──→ spotting_data ──→ guiding
                        │         │                               │
                        │         └─────────────────────────────→│ (skip spotting_data)
                        │                                         │
                        └─────────────────────────────────────→──┘ (skip tout spotting, QCM)
                                                                  │
                                                              validating
                                                                  │
                                                              feedback ──→ ended
                                                                  │
                                                              ended (skip feedback)
```

### Règles de skip

| Condition | Skip |
|-----------|------|
| `answer_type == qcm` | `spotting_type` + `spotting_data` → direct `guiding` |
| `answer_type` in `{justification, representation}` ET `dt_dr_refs.empty?` | `spotting_data` → direct `guiding` depuis `spotting_type` |
| Clic "voir correction" | `validating` → `ended` (skip `feedback`) |

### Re-greeting

| Condition | Action |
|-----------|--------|
| `welcome_sent == false` | Envoyer greeting, `welcome_sent: true` |
| Nouvelle `StudentSession` créée (reconnexion) | Re-greeting |
| `Time.current - last_activity_at > 12.hours` | Re-greeting |
| Navigation inter-questions, même session | Pas de re-greeting |

---

## Pas de nouvelle table, pas de nouvelle colonne

- `TutorState` et `QuestionState` : évolution du format JSONB, aucune migration de colonne
- `questions.answer_type` : migration de données uniquement (UPDATE SQL), la colonne existe déjà
- Aucune nouvelle table créée

# Phase 1 — Data Model

## Entités persistées

Aucune modification de schéma DB. Les modèles suivants existent déjà
et restent inchangés :

- `Conversation` (has_one `tutor_state`, has_many `messages`)
- `TutorState` (JSONB `current_phase`, `current_question_id`,
  `concepts_mastered`, `concepts_to_revise`, `discouragement_level`,
  `question_states`)
- `Message`
- `QuestionState` (value object dans TutorState : `step`, `hints_used`,
  `last_confidence`, `error_types`, `completed_at`)

## Nouvelles entités logiques (runtime uniquement)

### `Tutor::Tools::TransitionTool`

Outil LLM-callable. Aucune persistance propre — transmet l'intention
au pipeline.

| Param | Type | Required | Description | Validation en aval |
|---|---|---|---|---|
| `phase` | string | ✅ | Phase cible | Doit être ∈ ALLOWED_PHASES (`ApplyToolCalls`). |
| `question_id` | integer | ❌ | ID de la question courante | Requis si phase ∈ `guiding`/`spotting` (`ApplyToolCalls`). |

**Transitions autorisées** (matrice serveur, dans
`Tutor::ApplyToolCalls::TRANSITION_MATRIX`, **avec ajout `idle → greeting`
dans cette feature** — FR-009) :

```
idle       → greeting        ← AJOUTÉ (FR-009)
greeting   → reading
reading    → spotting
spotting   → guiding
guiding    → validating, spotting
validating → feedback
feedback   → ended
```

**Note terminologique** : la phase TutorState `ended` (parcours
pédagogique du tuteur) est distincte de l'état AASM `Conversation.done`
(cycle de vie technique de la conversation). Les deux coexistent sans
ambiguïté.

---

### `Tutor::Tools::UpdateLearnerModelTool`

| Param | Type | Required | Description | Validation en aval |
|---|---|---|---|---|
| `concept_mastered` | string | ❌ | Concept que l'élève vient de démontrer | dédupliqué côté serveur |
| `concept_to_revise` | string | ❌ | Concept mal maîtrisé | dédupliqué côté serveur |
| `discouragement_delta` | integer | ❌ | -3..3 typique | clampé 0..3 par `ApplyToolCalls` |

Aucun param requis : un appel vide est valide mais no-op.

---

### `Tutor::Tools::RequestHintTool`

| Param | Type | Required | Description | Validation en aval |
|---|---|---|---|---|
| `level` | integer | ✅ | 1..5 | progression monotone enforced par `ApplyToolCalls` ; refus si saut ou > 5 |

---

### `Tutor::Tools::EvaluateSpottingTool`

| Param | Type | Required | Description | Validation en aval |
|---|---|---|---|---|
| `outcome` | string | ✅ | `success` / `failure` / `forced_reveal` | doit être appelé en phase `spotting` ; sur `success` ou `forced_reveal`, `ApplyToolCalls` déclenche la transition automatique `spotting → guiding` |

---

## Contrat entre couche LLM et couche serveur

```
┌──────────────────┐   chat.ask          ┌──────────────┐
│ Tutor::CallLlm   │ ─ with_tools(…) ──> │ RubyLLM::Chat│
└──────────────────┘                     └──────────────┘
         │                                       │
         │ chunk (text)                          │
         │ <───────────────────────────────────  │
         │                                       │
         │ chunk (tool_calls)                    │
         │ <───────────────────────────────────  │
         │                                       │
         │ #execute(**args) → { ok: true, … }    │
         │ ───────────────────────────────────>  │
         │                                       │
         │ chunk (text, suite)                   │
         │ <───────────────────────────────────  │
         │                                       │
         ▼
  full_content, tool_calls=[ToolCall(name, arguments), …]
         │
         ▼
  ParseToolCalls → ApplyToolCalls → UpdateTutorState
         │                │
         │                └─ garde-fous serveur (matrice,
         │                   clamp, progression indices)
         ▼
  TutorState persisté
```

## Invariants

- **I1** : `TutorState.current_phase` n'est jamais modifié par
  `#execute` des tools ; seul `ApplyToolCalls` en a l'autorité.
- **I2** : un `#execute` de tool ne fait **jamais** d'I/O DB.
- **I3** : Les garde-fous existants de `ApplyToolCalls` restent
  l'ultime source de vérité, quel que soit ce que le LLM propose.

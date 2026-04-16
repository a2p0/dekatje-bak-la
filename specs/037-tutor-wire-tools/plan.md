# Implementation Plan: Câblage des outils du tuteur au LLM

**Branch**: `037-tutor-wire-tools` | **Date**: 2026-04-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/037-tutor-wire-tools/spec.md`

## Summary

Rendre les 4 outils du tuteur (`transition`, `update_learner_model`,
`request_hint`, `evaluate_spotting`) réellement invocables par le LLM.
Actuellement ils sont mentionnés en texte libre dans le prompt système mais
jamais enregistrés côté `RubyLLM::Chat` via `chat.with_tools(...)`, donc
le LLM ne peut pas les appeler. Résultat (baseline sim 2026-04-15) : phase
finale 0/7, le tuteur reste coincé en `idle`.

**Bug révélé à l'analyse (FR-009)** : la matrice `TRANSITION_MATRIX` dans
`Tutor::ApplyToolCalls` n'a **pas** `"idle"` comme clé source, alors que
`TutorState` démarre en `"idle"`. Sans patch, même après câblage des
outils, la première `transition` échouerait systématiquement. Ajout
`"idle" => %w[greeting]`.

**Approche** : créer 4 classes `RubyLLM::Tool` (DSL `param`/`description`),
les enregistrer dans `Tutor::CallLlm` avant `chat.ask`, renforcer le prompt
système (instructions minimales d'usage), adapter `FakeRubyLlm` pour
stubber le flow multi-tour (chunk texte → chunk `tool_calls` → chunk texte).
Pipeline existant (`ParseToolCalls` → `ApplyToolCalls`) conservé tel quel.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: `ruby_llm` (déjà présent au Gemfile), Hotwire
(Turbo Streams + ActionCable — inchangé), Sidekiq (inchangé), RSpec +
FactoryBot pour les tests.
**Storage**: PostgreSQL Neon (aucune migration nécessaire — `TutorState`
et `Conversation` ont déjà tous les champs requis).
**Testing**: RSpec + FakeRubyLlm existant (à étendre pour supporter
`tool_calls` en cours de streaming et callbacks tool).
**Target Platform**: serveur Rails, CI GitHub Actions (autorité selon
constitution §IV).
**Project Type**: application web fullstack Rails (Hotwire).
**Performance Goals**: streaming token-par-token conservé (pas de
régression latence perçue côté élève) ; appel LLM < 60s (conforme
constitution §V).
**Constraints**:
- Ne pas casser le streaming token-par-token (FR-008).
- Garde-fous serveur inchangés (matrice de transitions, clamp
  découragement, progression indices).
- Compatibilité des 4 providers (Anthropic, OpenRouter, OpenAI, Google) :
  l'API `ruby_llm` est unifiée, pas de code provider-specific.
**Scale/Scope**: ~10 fichiers modifiés/créés. Pas de migration.
Sim tuteur doit pouvoir tourner après merge.

## Constitution Check

Référence : `.specify/memory/constitution.md` v2.0.0.

| Principe | Statut | Note |
|---|---|---|
| I. Fullstack Rails Hotwire | ✅ | Aucun changement front ; le streaming Turbo/ActionCable reste identique. |
| II. RGPD | ✅ | Aucune collecte élève modifiée. |
| III. Sécurité (clés chiffrées, pas de log secret) | ✅ | Aucun changement au flow clé API (`ResolveTutorApiKey` inchangé). |
| IV. Testing NON-NEGOTIABLE (TDD, CI) | ✅ | Nouveaux specs écrits avant code ; CI GitHub Actions = autorité. |
| V. Performance & Simplicité | ✅ | Ajout minimal (4 classes tool + 1 câblage + 1 paragraphe prompt). |
| VI. Workflow NON-NEGOTIABLE | ✅ | Spec validée, branche `037-tutor-wire-tools` créée, PR à venir, pas de merge direct. |

**Gate** : ✅ passage OK. Aucune violation à justifier → pas de
`Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/037-tutor-wire-tools/
├── plan.md              # Ce fichier
├── spec.md              # Spec
├── research.md          # Phase 0 — décisions techniques
├── data-model.md        # Phase 1 — schémas des 4 outils
├── quickstart.md        # Phase 1 — comment vérifier manuellement
├── contracts/
│   └── tools.md         # Phase 1 — contrat d'interface des 4 tools
├── checklists/
│   └── requirements.md  # Checklist qualité spec (déjà écrite)
└── tasks.md             # Phase 2 — produit par /speckit.tasks (pas ici)
```

### Source Code (repository root)

```text
app/
├── services/
│   └── tutor/
│       ├── call_llm.rb                 # MODIFIÉ — ajoute with_tools(…)
│       ├── build_context.rb            # MODIFIÉ — prompt renforcé
│       ├── parse_tool_calls.rb         # INCHANGÉ (déjà compatible)
│       ├── apply_tool_calls.rb         # MODIFIÉ — ajout `idle → greeting`
│       │                                 dans TRANSITION_MATRIX (FR-009)
│       └── tools/                      # NOUVEAU — 4 classes RubyLLM::Tool
│           ├── transition_tool.rb
│           ├── update_learner_model_tool.rb
│           ├── request_hint_tool.rb
│           └── evaluate_spotting_tool.rb

spec/
├── services/
│   └── tutor/
│       ├── call_llm_spec.rb            # MODIFIÉ — vérifie with_tools appelé
│       ├── build_context_spec.rb       # MODIFIÉ — nouvelles instructions
│       └── tools/                      # NOUVEAU
│           ├── transition_tool_spec.rb
│           ├── update_learner_model_tool_spec.rb
│           ├── request_hint_tool_spec.rb
│           └── evaluate_spotting_tool_spec.rb
├── support/
│   └── fake_ruby_llm.rb                # MODIFIÉ — stub tool_calls en flux
└── features/
    └── student_tutor_full_flow_spec.rb # POTENTIEL — si breakage
```

**Structure Decision** : projet web fullstack Rails existant, pas de
frontend/backend séparés. Les nouveaux fichiers suivent la convention
établie (namespace `Tutor::`, sous-dossier `tools/`).

## Phase 0 — Research Output

Voir `research.md`. Résumé des décisions :

- **API tools** : `RubyLLM::Tool` sous-classe, DSL `description` +
  `param name, desc:, type:, required:`, méthode `#execute(**args)`.
- **Enregistrement** : `chat.with_tools(Tool1, Tool2, …)` (varargs,
  chainable, accepte classes ou instances).
- **Shape des tool_calls en streaming** : `chunk.tool_calls` est un
  Hash keyé par tool-call id, valeurs avec `.name` et `.arguments`
  (potentiellement partiels en streaming — attendre la fin pour parser).
- **`#execute`** : le retour est sérialisé et réinjecté au LLM. Dans
  notre cas, les mutations d'état sont faites par `ApplyToolCalls` en
  aval du pipeline ; `#execute` renvoie donc un **accusé de réception
  léger** (ex. `{ ok: true }`). Cela évite la double mutation.
- **Streaming + tools** : compatible. Le bloc `chat.ask { |chunk| … }`
  continue de recevoir des chunks texte + chunks tool_calls entremêlés.
- **Providers** : Anthropic, OpenRouter, OpenAI, Google tous supportés
  sans code spécifique. Sélection du modèle côté config déjà faite par
  `ResolveTutorApiKey` — à conserver (vérifier que les modèles utilisés
  supportent le function calling ; Claude Sonnet/Haiku 4.x OK, GPT-4
  OK, OpenRouter route selon modèle, Gemini 2.x OK).

## Phase 1 — Design Output

### Data model

Pas de schéma DB modifié. Voir `data-model.md` pour le schéma JSON de
chaque outil (types, required, enums).

### Contracts

Voir `contracts/tools.md`. Quatre contrats, un par outil :

1. **`transition`** — `{phase: enum, question_id?: integer}`
2. **`update_learner_model`** — `{concept_mastered?: string,
   concept_to_revise?: string, discouragement_delta?: integer(-3..3)}`
3. **`request_hint`** — `{level: integer(1..5)}`
4. **`evaluate_spotting`** — `{outcome: enum(success, failure,
   forced_reveal)}`

### Quickstart

Voir `quickstart.md` : procédure de vérification manuelle locale +
procédure de lancement de la sim tuteur post-merge.

### Agent context update

Pas d'ajout de techno nouvelle (ruby_llm déjà présent). Le fichier
`CLAUDE.md` Active Technologies sera mis à jour par le script
`update-agent-context.sh` si besoin — aucune nouvelle entrée attendue.

## Complexity Tracking

*Aucune violation — section vide.*

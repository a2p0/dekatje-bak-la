# Quickstart — Vérifier le câblage des outils tuteur

## Vérification locale rapide (développement)

### 1. Lancer la suite ciblée

```sh
bundle exec rspec \
  spec/services/tutor/tools/ \
  spec/services/tutor/call_llm_spec.rb \
  spec/services/tutor/build_context_spec.rb
```

Tous les specs doivent passer. Les specs unitaires des tools vérifient :
- Les params, types, required conformes au DSL `RubyLLM::Tool`.
- Le retour de `#execute` (hash `{ ok: true, recorded: … }`).

### 2. Vérifier que `with_tools` est appelé

Le spec `call_llm_spec.rb` doit contenir une assertion du type :

```ruby
expect_any_instance_of(RubyLLM::Chat).to receive(:with_tools).with(
  Tutor::Tools::TransitionTool,
  Tutor::Tools::UpdateLearnerModelTool,
  Tutor::Tools::RequestHintTool,
  Tutor::Tools::EvaluateSpottingTool
)
```

### 3. Scénario de fumée (pipeline complet)

Le spec de `ProcessMessage` doit fournir un chunk de streaming avec
`tool_calls` contenant une instance simulée de ToolCall `transition`
avec `{ phase: "reading" }` et vérifier que `TutorState#current_phase`
est bien passé à `reading` à la fin du tour.

---

## Vérification d'intégration post-merge (CI / prod)

### 1. Déclencher la simulation tuteur manuellement

Via GitHub Actions : workflow `tutor_simulation.yml` → "Run workflow".

### 2. Récupérer le rapport

Le job uploade un artefact `tutor_simulation_report_YYYYMMDD_HHMMSS`
contenant :
- `report.json` — scores bruts par conversation
- `report.md` — résumé tabulaire

### 3. Comparer avec la baseline 2026-04-15

| Métrique | Baseline | Cible (SC) | Status |
|---|---|---|---|
| Phase finale moyenne | 0 / 7 | ≥ 4 / 7 (SC-001) | — |
| Respect du process | 3.1 / 5 | ≥ 4.0 (SC-002) | — |
| Non-divulgation | 3.5 / 5 | ≥ 4.2 (SC-003) | — |
| % convs. avec ≥1 `transition` aux 3 premiers tours | 0 % | ≥ 80 % (SC-004) | — |

Si une métrique échoue : c'est un signal de tuning prompt, pas d'erreur
de câblage.

---

## Vérification manuelle (QA enseignant, optionnelle)

1. Se connecter comme élève sur une classe avec tuteur activé et clé
   OpenRouter présente (côté élève ou mode gratuit).
2. Ouvrir une question, activer le tuteur (drawer).
3. Envoyer "bonjour" → le tuteur doit saluer brièvement et poser
   immédiatement une question de lecture.
4. Inspecter la console Rails (`rails runner "puts
   Conversation.last.tutor_state.current_phase"`) : doit être `reading`
   ou `spotting`, pas `idle`.

---

## Rollback

Si régression bloquante en production :
- Revert du merge (1 PR) — pas de migration DB à reculer.
- Les conversations déjà démarrées restent valides (pas de changement
  de schéma).

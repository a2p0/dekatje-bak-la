# Phase 0 — Research: Câblage des outils du tuteur au LLM

## Décision 1 — API de définition des outils

**Decision** : Utiliser la sous-classe `RubyLLM::Tool` avec son DSL natif.

```ruby
class TransitionTool < RubyLLM::Tool
  description "Changer la phase pédagogique courante de la conversation."
  param :phase,       type: :string,  desc: "Phase cible", required: true
  param :question_id, type: :integer, desc: "ID question associée", required: false

  def execute(phase:, question_id: nil)
    { ok: true, recorded: { phase: phase, question_id: question_id } }
  end
end
```

**Rationale** :
- C'est l'API officielle ruby_llm, documentée via context7.
- Le schéma est auto-généré côté SDK (JSON Schema envoyé au provider)
  → pas besoin de redéfinir un schéma custom.
- Compatible tous providers (Anthropic / OpenRouter / OpenAI / Google)
  via l'abstraction ruby_llm.

**Alternatives considérées** :
- Construire le JSON Schema à la main et le passer via une API bas
  niveau : plus de code, plus de risque d'écart entre providers.
- Utiliser `claude-on-rails` / autre gem tool-centric : ajouterait une
  dépendance, `ruby_llm` fait déjà le job.

---

## Décision 2 — Rôle de `#execute`

**Decision** : `#execute` renvoie un accusé léger `{ ok: true,
recorded: {...} }`. Les **mutations réelles** de `TutorState` restent
faites par `Tutor::ApplyToolCalls` en aval du pipeline.

**Rationale** :
- Le pipeline existant (`ParseToolCalls → ApplyToolCalls →
  UpdateTutorState`) contient tous les garde-fous serveur (matrice de
  transitions, clamp 0-3, progression monotone des indices,
  restriction phase spotting). Le dupliquer dans `#execute` ouvrirait
  la porte à des incohérences.
- `#execute` est appelé **pendant** le round LLM (ruby_llm injecte le
  résultat comme tool-message et continue le round) ; mais la
  persistance de `TutorState` n'a pas besoin d'être synchrone à ce
  moment-là — elle peut attendre la fin du round.
- Conserver la source unique de vérité côté serveur (ApplyToolCalls)
  respecte le principe de simplicité (constitution §V).

**Alternatives considérées** :
- Muter directement dans `#execute` : couplerait le tool à la
  conversation/state, casserait la testabilité unitaire des tools.
- Supprimer `ApplyToolCalls` et tout faire dans `#execute` : refonte
  hors scope, et perdrait les garde-fous existants.

---

## Décision 3 — Extraction des tool_calls depuis le chunk

**Decision** : Conserver le code actuel de `call_llm.rb` qui accumule
`chunk.tool_calls` à chaque chunk, et passer le résultat final à
`ParseToolCalls`. Adapter `ParseToolCalls` **uniquement si** la shape
retournée par ruby_llm diverge du `.name` / `.arguments` attendu.

**Rationale** :
- Mémoire projet (2026-04-13) confirme `ParseToolCalls` déjà compatible
  avec `RubyLLM::ToolCall` (expose `.name` et `.arguments`).
- La doc ruby_llm indique que `chunk.tool_calls` est un Hash keyé par
  id, mais que les valeurs exposent `.name` et `.arguments`.
- ⚠️ Attention : `arguments` peut être **partiel** en cours de
  streaming. Il faut prendre la version du dernier chunk (ou
  `chunk.done?`).

**Point d'implémentation** : `call_llm.rb:41` fait déjà :
```ruby
tool_calls = chunk.tool_calls if chunk.tool_calls.present?
```
Cela écrase à chaque chunk → on garde la dernière version = bonne
pratique. Reste à extraire les **valeurs** du Hash (pas les clés) si
la shape est Hash-keyed. À vérifier au runtime ou adapter :
```ruby
tool_calls = Array(chunk.tool_calls.respond_to?(:values) ? chunk.tool_calls.values : chunk.tool_calls)
```

**Alternatives considérées** :
- Utiliser les callbacks `.on_tool_call` / `.on_tool_result` de
  ruby_llm : plus réactif, mais déconnecté du pipeline actuel.
  Report à une future refonte si besoin.

---

## Décision 4 — Prompt renforcé

**Decision** : Ajouter dans `BuildContext::SYSTEM_TEMPLATE` une section
explicite qui oblige l'appel aux outils, par-dessus la mention texte
actuelle ("Outils disponibles : transition, …").

Nouvelle section à ajouter, après `[CORRECTION CONFIDENTIELLE]` :

```text
[UTILISATION DES OUTILS — OBLIGATOIRE]
Tu DOIS invoquer l'outil `transition` à chaque changement de phase.
Tu DOIS invoquer `update_learner_model` quand tu identifies un concept
maîtrisé, à revoir, ou quand le moral de l'élève change.
En phase `guiding`, tu DOIS invoquer `request_hint` (niveau 1 d'abord,
puis 2, etc., jamais de saut) avant de formuler un indice.
En phase `spotting`, tu DOIS invoquer `evaluate_spotting` pour conclure
la phase.
Un message sans appel d'outil approprié = workflow rompu.
```

**Rationale** :
- Le tuning fin est hors scope, mais une instruction minimale est
  nécessaire sinon le LLM ignore les tools même s'ils sont enregistrés.
- Phrasé directif ("DOIS", "OBLIGATOIRE") aligné sur les autres sections
  normatives du prompt.

**Alternatives considérées** :
- Laisser le prompt actuel tel quel : risque que le LLM n'utilise pas
  les tools spontanément (connu pour Claude/GPT sur tools optionnels).
- Prompt très détaillé : hors scope (tuning).

---

## Décision 5 — Support de test (FakeRubyLlm)

**Decision** : Étendre `spec/support/fake_ruby_llm.rb` pour supporter :
1. Les méthodes `with_tool` et `with_tools` (stub no-op).
2. La shape Hash-keyed par id pour `tool_calls` (pas juste Array).

Exemple d'extension :

```ruby
RSpec::Mocks.space
            .any_instance_recorder_for(RubyLLM::Chat)
            .stub(:with_tools) { |*_args, **_kwargs| nil }
RSpec::Mocks.space
            .any_instance_recorder_for(RubyLLM::Chat)
            .stub(:with_tool)  { |*_args| nil }
```

**Rationale** :
- Les specs existants stubent déjà `with_instructions` sans simuler le
  comportement — même approche pour `with_tools`.
- `tool_calls` shape : on peut choisir de fournir une Array directement
  (comme aujourd'hui) si `ParseToolCalls` est adapté, **ou** fournir
  un Hash pour fidélité maximale à la shape réelle.

**Décision de shape de test** : fournir une Array (plus simple). Adapter
`ParseToolCalls` à coup de `.values` côté prod pour gérer la Hash
retournée par ruby_llm réel — tests et prod passent tous les deux.

---

## Décision 6 — Providers et modèles supportés

**Decision** : Ne rien changer à `ResolveTutorApiKey` ni au choix de
modèle. Documenter dans le README que les modèles utilisés doivent
supporter le function calling.

**Rationale** :
- ruby_llm uniforme l'API tools sur les 4 providers.
- Modèles en usage (Claude Sonnet/Haiku 4.x, GPT-4/4o, OpenRouter
  passe-through, Gemini 2.x) supportent tous le function calling.
- Ajouter une validation du modèle = hors scope (tuning).

**Alternatives considérées** :
- Forcer un modèle tools-capable : rigide, casse la flexibilité
  actuelle.

---

## Risques identifiés

| Risque | Sévérité | Mitigation |
|---|---|---|
| Shape `chunk.tool_calls` Hash inattendue → casse `ParseToolCalls` | Moyen | Adapter `call_llm.rb` pour `.values` ; ajouter spec avec Hash en entrée. |
| Le LLM appelle un outil qui retourne un résultat et continue la réponse (multi-tour) → le streaming pourrait sembler se "figer" pendant `#execute` | Faible | `#execute` est léger (hash littéral) → latence invisible. |
| Un provider (OpenRouter avec certains modèles) ne supporte pas le function calling | Moyen | Documentation quickstart + erreur LLM gracieusement catchée par `rescue => e` déjà en place. |
| Le prompt renforcé ne suffit pas → SC-004 (80 % de conversations avec `transition`) non atteint | Moyen | La sim post-merge révélera le besoin éventuel de tuning plus profond (follow-up séparé). |

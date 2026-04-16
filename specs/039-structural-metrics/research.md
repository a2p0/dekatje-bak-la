# Research — Metrics structurelles déterministes

**Branche** : `039-structural-metrics`
**Date** : 2026-04-16
**Statut** : résolutions Phase 0 — aucun NEEDS CLARIFICATION restant

## R1 — Comment capturer `phase_per_turn` dans le Runner ?

### Décision
Capturer in-memory dans `Runner#simulate_profile` : après chaque appel
`Tutor::ProcessMessage.call`, lire `conversation.reload.tutor_state.current_phase`
et pousser dans un tableau local `phase_per_turn`. Passer ce tableau en kwarg
optionnel à `StructuralMetrics.compute(conversation:, phase_per_turn:)`.

### Rationale
- Le `TutorState` est un JSONB attaché à `Conversation` et **n'a pas d'historique**
  — seul le `current_phase` à l'instant T est stocké. Donc on doit snapshot-er à
  chaque tour sinon on perd l'information.
- Capture in-memory pendant la sim : coût 0, complexité minimale, pas de migration.
- Le tableau `phase_per_turn` est sérialisé dans `raw.json` comme champ `structural_metrics[:phase_per_turn]`
  pour traçabilité (post-mortem possible sans relancer la sim).

### Alternatives considérées

| Option | Verdict | Raison |
|---|---|---|
| Migration `messages.phase_snapshot` JSONB | ❌ rejeté | Alourdit le schema de prod pour un usage test-only, viole principe V (simplicité) |
| Hook dans `Tutor::ApplyToolCalls` pour persister | ❌ rejeté | Modifie le pipeline prod, risque de régression subtile |
| Recalcul post-hoc depuis messages+tool_calls | ❌ impossible | `tool_calls` pas persistés en DB (confirmé par lecture de `apply_tool_calls.rb`) |
| Snapshot in-memory dans Runner (**choisi**) | ✅ | Zéro impact prod, suffit au cas d'usage sim |

---

## R2 — Structure des 4 nouvelles métriques dans `StructuralMetrics`

### Décision
Étendre la signature publique : `compute(conversation:, phase_per_turn: nil)`.
Ajouter 4 méthodes privées, chacune retournant une valeur scalaire ou sentinelle :

```ruby
def compute
  {
    # … 6 métriques existantes …
    first_turn_with_transition:    first_turn_with_transition,
    action_verb_ratio_guiding:     action_verb_ratio_guiding,
    dt_dr_leak_count_non_spotting: dt_dr_leak_count_non_spotting,
    short_message_ratio:           short_message_ratio,
    phase_per_turn:                @phase_per_turn  # trace
  }
end
```

Règles de sentinelles :

| Métrique | Quand `nil` | Quand `0` / valeur |
|---|---|---|
| `first_turn_with_transition` | `phase_per_turn` absent OU aucune transition hors idle | rang 1-indexé sinon |
| `action_verb_ratio_guiding` | `phase_per_turn` absent OU aucun message tuteur en guiding | ratio [0.0, 1.0] sinon |
| `dt_dr_leak_count_non_spotting` | jamais nil | `0` si aucun leak, compteur sinon |
| `short_message_ratio` | aucun message assistant | ratio [0.0, 1.0] sinon |

### Rationale
- Rétrocompat stricte (FR-011, SC-004) : les specs existants appellent
  `compute(conversation: conv)` sans `phase_per_turn` → les 2 métriques qui
  dépendent de l'historique retournent `nil`, les 2 autres sont calculables
  depuis la conv seule.
- **Distinction `nil` vs `0`** : importante pour le rapport. `nil` = "métrique
  non calculable faute de données" ; `0` = "donnée calculée à 0" (ex : aucun leak).
- La liste des verbes est figée comme **constante privée** du service
  (`ACTION_VERBS = %w[identifie repère cite relève compare calcule].freeze`) pour
  éviter tout drift avec le prompt H2 (si on modifie le prompt, on doit
  explicitement toucher cette liste ET la métrique).

### Alternatives considérées

| Option | Verdict | Raison |
|---|---|---|
| Passer les 4 métriques dans une classe séparée `TransitionMetrics` | ❌ | Splitting prématuré, augmente la surface. 4 méthodes privées suffisent |
| Retourner `0.0` au lieu de `nil` quand phase absente | ❌ | Confond "phase absente" et "0 verbes observés" — bruite les moyennes globales |
| Renvoyer les verbes comme un Set plutôt que Array | ⚖️ équivalent | `include?` en O(1) pour les deux, Array plus lisible pour 6 éléments |

---

## R3 — Regex et normalisation pour H2

### Décision
Match sur : `content.strip.downcase.split(/\s+/).first`. Si ce premier mot (après
strip ponctuation finale éventuelle) est dans `ACTION_VERBS`, le message compte.

```ruby
ACTION_VERBS = %w[identifie repère cite relève compare calcule].freeze

def action_verb?(content)
  first = content.to_s.strip.downcase.split(/\s+/).first.to_s
  first = first.gsub(/[[:punct:]]$/, "")  # enlève ponctuation finale type "Identifie,"
  ACTION_VERBS.include?(first)
end
```

### Rationale
- **Case-insensitive + trim** : un Acceptance Scenario (US2 scenario 3) impose
  que "  identifie ..." en minuscule avec espaces matche.
- **Strip ponctuation finale** : "Identifie," ou "Identifie." doivent matcher
  (on n'attend pas du tuteur une typographie stricte).
- **Caractères accentués** : "Repère" et "Relève" contiennent é/è. Ruby 3.3
  `downcase` gère Unicode correctement par défaut (pas besoin de `:fold`).
- Pas de regex multiligne / lookbehind : split simple, compréhensible au
  premier coup d'œil (principe V).

### Alternatives considérées

| Option | Verdict | Raison |
|---|---|---|
| Regex `/\A\s*(identifie\|repère\|...)/i` | ⚖️ marche | Un poil moins lisible, mais OK. Choisi `split + include?` pour clarté |
| Matcher le verbe n'importe où dans le message | ❌ | Change la sémantique de H2 (qui dit "commence par") |
| Stocker les verbes avec leurs variantes morphologiques (imperative 2e pers) | ❌ | H2 a figé la forme impérative 2e pers sg. Pas de variante à gérer |

---

## R4 — Guard `SKIP_JUDGE=1` dans `Runner`

### Décision
Guard dans `Runner#simulate_profile` à la ligne de l'appel juge :

```ruby
evaluation = if ENV["SKIP_JUDGE"] == "1"
  { "skipped" => true }
else
  judge_transcript(question, profile, simulator.profile_label, transcript)
end
```

Le `judge_client` reste construit (rake task inchangée) mais jamais invoqué
quand le guard est actif. Pas de refacto invasive.

### Rationale
- 5 LOC, zéro impact sur les callers existants.
- Marker `{ "skipped" => true }` discriminant du cas erreur `{ "error" => "..." }`
  déjà existant dans `judge_transcript` (ligne 184 de runner.rb).
- Le `ReportGenerator#render_qualitative` doit savoir afficher ce marker (FR-010).
  Modification triviale : ajouter un `if evaluation&.dig("skipped")` en tête.

### Alternatives considérées

| Option | Verdict | Raison |
|---|---|---|
| Null Object `NullJudge.new` (option B discutée) | ⚖️ acceptable | Plus propre conceptuellement mais + 1 classe + 1 spec. Le guard suffit |
| Rake task dédiée `tutor:simulate_structural` | ⚖️ acceptable | Dupliquerait ~50 lignes de la task existante. À reconsidérer si l'usage se pérennise |
| Ne pas instancier `judge_client` quand `SKIP_JUDGE=1` | ❌ | Impose de modifier la rake task en plus, viole le principe "minimal diff" |

---

## R5 — Mock du `judge_client` dans le spec `runner_spec.rb`

### Décision
Utiliser `instance_double("TutorSimulation::Judge")` et stubber `Judge.new` pour
retourner le double :

```ruby
let(:fake_judge) { instance_double(TutorSimulation::Judge) }

before do
  allow(TutorSimulation::Judge).to receive(:new).and_return(fake_judge)
end

context "when SKIP_JUDGE=1" do
  before { ENV["SKIP_JUDGE"] = "1" }
  after  { ENV.delete("SKIP_JUDGE") }

  it "does not call the judge" do
    expect(fake_judge).not_to receive(:evaluate)
    runner.run
  end

  it "marks evaluation as skipped in each profile result" do
    result = runner.run
    expect(result[:results].first[:profiles].first[:evaluation]).to eq("skipped" => true)
  end
end
```

### Rationale
- `instance_double` garantit que les méthodes stubées existent vraiment sur
  `TutorSimulation::Judge` (safer que `double`).
- Mutation d'ENV encadrée par `before`/`after` pour éviter le leak entre tests.
- L'assertion sur `not_to receive(:evaluate)` est le verdict exact du
  comportement attendu (FR-007, FR-013).

### Alternatives considérées

| Option | Verdict | Raison |
|---|---|---|
| Injecter un flag `skip_judge:` au constructeur du Runner | ⚖️ plus propre | Nécessite modifier la rake task ET le constructeur. Env var plus pragmatique pour outil dev |
| Mock au niveau `RubyLLM::Chat.ask` | ❌ | Plus bas niveau que nécessaire, l'intention est à la frontière Runner/Judge |

---

## R6 — Impact sur les tests existants

### Décision
Les 6 specs existants de `structural_metrics_spec.rb` continuent à passer sans
modification grâce à la rétrocompat (kwarg `phase_per_turn: nil` par défaut).
On **ajoute** ~8 specs (2 par nouvelle métrique) + 1 spec pour SKIP_JUDGE dans
`runner_spec.rb` + 2 specs pour le rendu markdown.

### Rationale
SC-004 impose rétrocompat stricte → les tests existants ne DOIVENT PAS être modifiés.
C'est une ligne rouge de la méthodologie speckit : "pas de refacto hors scope".

### Vérification
Avant le merge, je dois lancer `bundle exec rspec spec/services/tutor_simulation/` et
vérifier que les 6 specs existants passent toujours.

---

## Synthèse

| Question | Réponse |
|---|---|
| Comment capturer l'historique des phases ? | In-memory dans Runner, kwarg optionnel au service |
| Comment structurer les 4 métriques ? | 4 méthodes privées, nil-safe, constante `ACTION_VERBS` figée |
| Comment mocker le juge ? | `instance_double(Judge)` + stub de `Judge.new` |
| Rétrocompat garantie ? | Oui via kwarg `phase_per_turn: nil` + sentinelles explicites |
| Migration DB ? | Aucune |
| Modif pipeline prod ? | Aucune |
| Risque rupture tests existants ? | Aucun si on respecte la rétrocompat |

**Tous les NEEDS CLARIFICATION résolus. Prêt pour Phase 1.**

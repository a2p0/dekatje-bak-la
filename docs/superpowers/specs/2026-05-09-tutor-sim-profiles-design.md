# Design 063 — Profils de simulation tuteur (autonome / passif) + seuils SC-C/D/E

**Date** : 2026-05-09
**Branche** : `063-tutor-sim-profiles`
**Statut** : design validé, prêt pour plan d'implémentation

## 1. Contexte et motivation

La PR 062 (`062-tutor-redesign-from-scratch`, mergée le 2026-05-07) a livré la
refonte du tuteur (services, prompt, chips, drawer) et la réécriture de
`StructuralMetrics` en mode trace-based avec 8 métriques.

Le design 062 (§7.4 et §11) a explicitement reporté trois éléments à une
PR de suivi :

1. Les profils élèves simulés `autonome` et `passif` (062 ne livre que
   `collaboratif`).
2. La réécriture du juge LLM avec la rubrique 062.
3. La validation des seuils SC-C/D/E/F sur les 6 métriques structurelles
   non-asserted (062 n'asserte que SC-A `resolution_rate >= 0.70` et SC-B
   `cap_violations == 0`).

**063 livre les éléments 1 et 3.** L'élément 2 (juge LLM réécrit) reste
hors scope et fera l'objet d'une PR 064 distincte si la valeur est
démontrée.

### Pourquoi ne pas faire les trois ensemble

Coût comparatif estimé :

| Trajectoire | Dev | Coût LLM (calibrage) |
|---|---|---|
| 063 + 064 (juge plus tard, optionnel) | 4-6h + 6-10h | ~$5-15 + ~$20-40 |
| Tout en une PR | 12-16h | ~$15-25 |

Faire 063 d'abord laisse la possibilité de **ne jamais faire 064** si les
métriques structurelles suffisent. Le risque est de payer plus cher
cumulativement si 064 est de toute façon nécessaire — choix assumé en
faveur de la latitude de pivoter.

## 2. Périmètre

### Livré

- Profils `autonome` et `passif` dans `TutorSimulation::StudentSimulator::PROFILES`
- Nouveau service `TutorSimulation::ProfileBehavior` qui encapsule la
  logique runtime par profil (déclenchement de `viewed_correction`,
  gestion du tag `[VOIR_CORRECTION]`)
- Extension de `TutorSimulation::Runner` : appelle `ProfileBehavior`
  à chaque tour, déclenche `Tutor::RecordEvent` pour `viewed_correction`,
  break la boucle après abandon
- Trois nouveaux seuils CI :
  - **SC-C** : `proactive_help_rate <= 0.30` (moyenne globale)
  - **SC-D** : `mean_help_steps_before_resolution >= 1.0` (moyenne globale)
  - **SC-E** : `correct_attempts_after_help_rate >= 0.50` (moyenne globale)
- Rapport markdown enrichi : section "Métriques par profil" avec
  drapeau `WARN` si un profil dévie d'un seuil indicatif (sans casser la CI)
- Documentation de la baseline observée dans la description de la PR

### Hors scope

- Réécriture du juge LLM (rubrique 062) → PR 064 si nécessaire
- Refonte des profils en machine d'état déterministe (les profils
  restent implémentés via prompt LLM + guard-rails minimaux dans
  `ProfileBehavior`)
- Augmentation du nombre de questions/convs par sim (on reste à
  5 questions × 3 profils = 15 convs ; ajustement futur si variance
  trop forte)
- Modification de l'UI étudiante ou enseignante

## 3. Success Criteria

| ID | Critère | Source | Validation |
|---|---|---|---|
| SC-A | `resolution_rate >= 0.70` (moyenne globale) | déjà en CI 062 | workflow YAML |
| SC-B | `cap_violations == 0` (somme) | déjà en CI 062 | workflow YAML |
| SC-C | `proactive_help_rate <= 0.30` (moyenne globale) | **nouveau 063** | workflow YAML |
| SC-D | `mean_help_steps_before_resolution >= 1.0` (moyenne globale) | **nouveau 063** | workflow YAML |
| SC-E | `correct_attempts_after_help_rate >= 0.50` (moyenne globale) | **nouveau 063** | workflow YAML |
| SC-F | `correction_view_rate(autonome) == 0` ET `correction_view_rate(passif) >= 0.66` | **nouveau 063 — non gaté CI** | rapport markdown, indicateur de validité des profils |

Les valeurs chiffrées SC-C/D/E sont **a priori**. Méthodologie de
calibrage : hybride — on lance une baseline avec ces seuils et on
ajuste si la baseline est légèrement hors cible (relaxer/durcir),
sinon on investigue (bug profil ou seuil irréaliste).

## 4. Architecture

### 4.1 Nouveau service `TutorSimulation::ProfileBehavior`

Fichier : `app/services/tutor_simulation/profile_behavior.rb`

```ruby
module TutorSimulation
  class ProfileBehavior
    BEHAVIORS = {
      autonome: {
        view_correction_after_turns: nil,   # jamais
        honor_view_tag:              false  # ignore [VOIR_CORRECTION]
      },
      collaboratif: {
        view_correction_after_turns: 8,
        honor_view_tag:              true
      },
      passif: {
        view_correction_after_turns: 3,
        honor_view_tag:              true
      }
    }.freeze

    VIEW_TAG = "[VOIR_CORRECTION]"

    def self.for(profile)
      new(profile)
    end

    def initialize(profile)
      @profile = profile.to_sym
      @config  = BEHAVIORS.fetch(@profile)
    end

    def should_view_correction?(student_message:, turns_without_correct:)
      return true if @config[:honor_view_tag] && student_message.include?(VIEW_TAG)

      threshold = @config[:view_correction_after_turns]
      return false if threshold.nil?
      turns_without_correct >= threshold
    end

    def strip_view_tag(student_message)
      student_message.gsub(VIEW_TAG, "").strip
    end
  end
end
```

**Responsabilités** :
- Mapper profil → règles comportementales runtime
- Décider, à chaque tour, si l'élève simulé "voit la correction"
- Nettoyer le tag avant envoi au tuteur (sinon le tuteur le voit comme un message ordinaire)

**Non-responsabilités** : prompts profils (restent dans
`StudentSimulator::PROFILES`), appels LLM, persistance d'event.

### 4.2 Extension `StudentSimulator::PROFILES`

Ajout de deux entrées dans le hash existant. Les prompts mentionnent
explicitement la possibilité d'écrire `[VOIR_CORRECTION]` selon le
profil — l'autonome est explicitement instruit de **ne jamais** l'écrire,
le passif est invité à le faire dès qu'il bloque.

```ruby
autonome: {
  label: "Élève autonome",
  system: <<~PROMPT
    Tu simules un élève de Terminale STI2D qui prépare le BAC.
    Profil : autonome — tu préfères réfléchir seul. Tu demandes très
    rarement de l'aide. Si tu es bloqué, tu retentes par toi-même
    plusieurs fois avant de demander quoi que ce soit.
    Tu ne demandes JAMAIS à voir la correction.
    Tu n'écris jamais [VOIR_CORRECTION].
    Si vraiment tu n'y arrives pas après 6+ tentatives, tu admets ne pas
    savoir mais tu ne capitules pas.
    Réponds en français, niveau lycéen, 1-3 phrases maximum.
  PROMPT
},
passif: {
  label: "Élève passif",
  system: <<~PROMPT
    Tu simules un élève de Terminale STI2D qui prépare le BAC.
    Profil : passif — tu cherches le minimum d'effort. Tu demandes vite
    l'aide maximale.
    Tes premières réponses sont du type "je sais pas",
    "donne-moi un indice", "comment je fais ?".
    Si tu sens que ça bloque dès 3 tours, tu écris [VOIR_CORRECTION]
    pour voir la solution.
    Tu acceptes les chips d'aide proposés sans chercher à les éviter.
    Réponds en français, niveau lycéen, 1-2 phrases maximum.
  PROMPT
}
```

### 4.3 Modification du `Runner`

Une seule méthode change : `simulate_profile`. Pseudo-code de la boucle :

```ruby
behavior = ProfileBehavior.for(profile)
turns_without_correct = 0

@max_turns.times do |turn|
  raw_student = simulator.respond(...)
  cleaned     = behavior.strip_view_tag(raw_student)

  # 1. Décider si on déclenche viewed_correction AVANT envoi au tuteur
  if behavior.should_view_correction?(
       student_message: raw_student,
       turns_without_correct: turns_without_correct
     )
    Tutor::RecordEvent.call(
      conversation: conversation,
      question_id:  question.id,
      type:         "viewed_correction",
      source:       "code"
    )
    transcript << {
      "role"    => "user",
      "content" => cleaned.presence || "Je vais voir la correction."
    }
    break  # le profil a abandonné cette question
  end

  # 2. Envoi normal au tuteur
  transcript << { "role" => "user", "content" => cleaned }
  result = Tutor::ProcessMessage.call(
    conversation:  conversation,
    student_input: cleaned,
    question:      question,
    access_code:   nil
  )

  # 3. Mise à jour du compteur "turns sans correct"
  conversation.reload
  trace = conversation.tutor_state.trace_for(question.id)
  last_event = trace.events.last
  if last_event&.dig("type") == "student_attempt" &&
     last_event["verdict"] == "correct"
    turns_without_correct = 0
  else
    turns_without_correct += 1
  end

  # ... reste inchangé
end
```

Notes :
- `source: "code"` est déjà dans `RecordEvent::ALLOWED_SOURCES`.
- Le strip empêche le tuteur de voir `[VOIR_CORRECTION]` comme un message ordinaire.
- `break` après `viewed_correction` reflète l'abandon de l'élève sur cette question — la sim passe à la suivante.

### 4.4 Workflow CI — nouveaux seuils

Dans `.github/workflows/tutor_simulation.yml`, ajouter après les
assertions SC-A/SC-B existantes :

```bash
PHR=$(jq '[.results[].profiles[].structural_metrics.proactive_help_rate] | add / length' "$RAW_JSON")
MHB=$(jq '[.results[].profiles[].structural_metrics.mean_help_steps_before_resolution] | add / length' "$RAW_JSON")
CAH=$(jq '[.results[].profiles[].structural_metrics.correct_attempts_after_help_rate] | add / length' "$RAW_JSON")

python3 -c "import sys; sys.exit(0 if float('$PHR') <= 0.30 else 1)" \
  || { echo "::error::SC-C failed: proactive_help_rate $PHR > 0.30"; exit 1; }
python3 -c "import sys; sys.exit(0 if float('$MHB') >= 1.0 else 1)" \
  || { echo "::error::SC-D failed: mean_help_steps_before_resolution $MHB < 1.0"; exit 1; }
python3 -c "import sys; sys.exit(0 if float('$CAH') >= 0.50 else 1)" \
  || { echo "::error::SC-E failed: correct_attempts_after_help_rate $CAH < 0.50"; exit 1; }
```

### 4.5 Rapport markdown enrichi

Dans `ReportGenerator#to_markdown`, ajouter une section "Métriques par
profil" qui liste pour chaque profil les 8 métriques + un drapeau
`⚠ WARN` si dépassement d'un seuil indicatif **par profil** (différent
du seuil global CI).

Seuils indicatifs par profil (issus de l'objectif pédagogique) :

| Métrique | autonome | collaboratif | passif |
|---|---|---|---|
| proactive_help_rate | ≤ 0.20 | ≤ 0.30 | ≤ 0.50 |
| mean_help_steps_before_resolution | ≥ 0.5 | ≥ 1.5 | ≥ 1.0 |
| correct_attempts_after_help_rate | n/a (peu d'aide) | ≥ 0.60 | ≥ 0.40 |
| correction_view_rate | == 0 | ≤ 0.20 | ≥ 0.66 |

Note sur `correct_attempts_after_help_rate` côté autonome : la métrique
n'est pas vraiment indicative pour ce profil (peu/pas d'aide donnée
donc dénominateur global tiré vers le bas par autonome). C'est un
risque pour SC-E que le calibrage devra observer. Mitigation : si
autonome plombe trop SC-E, durcir prompt autonome pour qu'il accepte
quelques aides au cas-limite, ou relaxer SC-E.

Ces valeurs sont **a priori**. La première baseline 063 servira à les
ajuster.

## 5. Tests

### 5.1 Pyramide

| Niveau | Quoi | Volume |
|---|---|---|
| Unit | `ProfileBehavior` (3 profils × règles) | ~10 examples |
| Unit | `StudentSimulator` (3 profils, raise sur unknown) | ~3 examples |
| Unit | `StructuralMetrics#correction_view_rate` (regression check) | 1 example |
| Unit | `ReportGenerator` (section par profil + WARN) | ~3 examples |
| Integration | `Runner` avec `viewed_correction` déclenché (FakeRubyLlm) | ~2 examples |

Aucun test feature/Capybara : 063 ne touche aucune UI.

### 5.2 Tests unitaires `ProfileBehavior` — détail

```ruby
describe TutorSimulation::ProfileBehavior do
  describe "#should_view_correction?" do
    context "profil autonome" do
      it "retourne false même après 20 tours sans réussite"
      it "retourne false même si le message contient [VOIR_CORRECTION]"
    end
    context "profil collaboratif" do
      it "retourne false avant 8 tours"
      it "retourne true au 8e tour sans réussite"
      it "retourne true si message contient [VOIR_CORRECTION] avant 8 tours"
    end
    context "profil passif" do
      it "retourne false avant 3 tours"
      it "retourne true au 3e tour sans réussite"
      it "retourne true si message contient [VOIR_CORRECTION]"
    end
  end

  describe "#strip_view_tag" do
    it "retire le tag et trim"
    it "retourne le message intact si pas de tag"
  end
end
```

### 5.3 Test intégration `Runner`

Stratégie : vrais services `Tutor::ProcessMessage` + `Tutor::RecordEvent`,
client RubyLLM mocké via `FakeRubyLlm` (déjà existant, cf. 062). Réponses
LLM élève scriptées pour forcer le déclenchement.

```ruby
context "profil passif déclenche viewed_correction au 3e tour" do
  it "appelle RecordEvent.call avec type: viewed_correction"
  it "ajoute viewed_correction dans la trace après run"
end
```

### 5.4 Régression specs feature 062

Vérifier `bundle exec rspec spec/features/student_tutor_*` reste vert.

## 6. Migration et compatibilité

- **Schéma BD** : aucune migration.
- **Données existantes** : compatibles, `tutor_state` inchangé.
- **`tutor:simulate` rake task** : la liste de profils par défaut est
  `StudentSimulator::PROFILES.keys`. Avec 063 elle passe automatiquement de
  `[:collaboratif]` à `[:autonome, :collaboratif, :passif]`. Effet : un
  `rake tutor:simulate[1]` sans `PROFILES=...` triple le coût LLM.
  À documenter dans le commentaire d'ouverture de la rake task.
- **Workflow CI** : `tutor_simulation.yml` est `workflow_dispatch`
  (manuel). Pas d'augmentation de coûts CI automatique. Un déclenchement
  manuel coûte ~$5-10.

## 7. Workflow de validation et calibrage

```
Phase 1 — Implémentation (sans LLM)
  → tous les tests unit + integration passent

Phase 2 — Smoke test ($0.50)
  rake tutor:simulate[<id>] TURNS=5 QUESTIONS=1.1 SKIP_JUDGE=1
  → 3 profils × 1 question × 5 tours
  → vérifier : runner ne crash pas, trace contient les events attendus,
    rapport markdown s'affiche correctement

Phase 3 — Baseline calibrage ($5)
  rake tutor:simulate[<id>] TURNS=8 SKIP_JUDGE=1
  → 5 questions × 3 profils = 15 convs
  → observer les 8 métriques par profil
  → comparer aux seuils a priori

Phase 4 — Ajustement seuils si nécessaire
  → si baseline ne passe pas à ±10% → ajuster le YAML
  → si écart >50% → investigation (bug profil ? seuil irréaliste ?)
  → commit `chore(sim): calibrate SC-C/D/E thresholds from 063 baseline`

Phase 5 — Sim de validation finale ($5)
  → relancer sim complète, vérifier les 5 SC

Phase 6 — Merge PR
  → CI standard verte (la sim n'est PAS dans la CI standard)
  → reviewer humain
```

Coût estimé total : **~$10-15** (Phase 2 + 3 + 5, avec marge pour 1
itération de Phase 4).

### Critère d'arrêt du calibrage

On accepte les seuils si :
- 3 sims (Phase 3 + Phase 5 + 1 contrôle) passent toutes les SC-A à SC-E
- Aucune SC ne passe à <10% de marge (sinon trop fragile à la variance)
- Pas plus de 2 `WARN` par profil dans le rapport

Sinon, après 2 itérations sans convergence → STOP. Soit un profil est
mal designé, soit on doit augmenter à 30 convs (revoir taille run).

## 8. Risques et mitigations

| Risque | Probabilité | Mitigation |
|---|---|---|
| `autonome` ne résout aucune question, tire SC-A vers le bas | Moyenne | Si SC-A casse à cause de ça, durcir prompt autonome (élève moins entêté). Vérifier que `resolution_rate` est bien moyenné sur l'ensemble. |
| Variance LLM > 10% sur 15 convs → CI flaky | Moyenne-haute | Smoke test + 2 sims successives Phase 5. Si flaky : monter à 30 convs (option déjà cadrée). |
| Prompt autonome trop passif, contredit ProfileBehavior (jamais correction) → boucle stérile | Faible | Le runner break naturellement après `@max_turns`. Le prompt explicite "tu retentes, tu ne sors pas". |
| Tag `[VOIR_CORRECTION]` mal stripé → tuteur le voit | Faible | Strip systématique en sortie de `simulator.respond`. Test unit dédié. |
| Coût Phase 3+5 > $15 | Faible | `SKIP_JUDGE=1` obligatoire en Phase 3. Modèle `sonnet-4-6` ($3/$15 par M tokens) acceptable. |

## 9. Découpage commits

D'après mémoire `feedback_commit_scope` (un concern par commit) :

```
1. docs(spec): add 063 tutor sim profiles design
2. feat(sim): add ProfileBehavior service with autonome/collaboratif/passif rules
3. test(sim): cover ProfileBehavior with unit specs
4. feat(sim): add autonome and passif prompts to StudentSimulator
5. feat(sim): wire ProfileBehavior in Runner + emit viewed_correction
6. test(sim): cover Runner viewed_correction emission with FakeRubyLlm
7. feat(sim): enrich ReportGenerator with per-profile section and WARN flags
8. test(sim): cover per-profile report section
9. ci(sim): add SC-C/D/E thresholds to tutor_simulation workflow
10. chore(sim): calibrate SC-C/D/E thresholds from 063 baseline    [Phase 4 si nécessaire]
```

10 commits prévus, ~9 si pas d'ajustement post-baseline. Squash optionnel
selon préférence reviewer (cf. mémoire `feedback_squash_large_refactors` :
squash conventionné pour les gros multi-task — 063 est moyen, donc
commits séparés par défaut).

## 10. Definition of Done

**Code**

- [ ] `app/services/tutor_simulation/profile_behavior.rb` créé
- [ ] `student_simulator.rb` étendu avec `autonome` + `passif`
- [ ] `runner.rb` modifié : appelle `ProfileBehavior` à chaque tour, déclenche `Tutor::RecordEvent` pour `viewed_correction`, strip le tag, break après abandon
- [ ] `report_generator.rb` enrichi : section par profil + `WARN` indicatif

**Tests**

- [ ] `profile_behavior_spec.rb` (~10 examples)
- [ ] `student_simulator_spec.rb` étendu (3 examples)
- [ ] `runner_spec.rb` étendu (~2 examples integration)
- [ ] `report_generator_spec.rb` étendu (~3 examples)
- [ ] CI standard verte (rspec + rubocop + brakeman)
- [ ] Specs feature `student_tutor_*` toujours vertes

**CI workflow**

- [ ] `.github/workflows/tutor_simulation.yml` : 3 nouvelles assertions SC-C/D/E

**Calibrage validé**

- [ ] Smoke test (Phase 2) tourne sans crash
- [ ] Baseline (Phase 3) lancée, valeurs des 8 métriques par profil consignées dans la PR description
- [ ] Sim finale (Phase 5) passe les 5 SC avec ≥10% de marge
- [ ] Si seuils ajustés vs design : commit dédié documentant l'écart

**Documentation**

- [ ] `docs/superpowers/specs/2026-05-09-tutor-sim-profiles-design.md` (ce fichier) committé
- [ ] PR description résume scope + valeurs baseline + seuils retenus

## 11. Décisions clés tracées

| Question | Décision | Justification courte |
|---|---|---|
| Périmètre 063 | Profils + calibrage seuils, juge LLM hors scope | Latitude pour ne jamais faire 064 si métriques structurelles suffisent |
| Mécanique `viewed_correction` | Tag `[VOIR_CORRECTION]` + guard-rails par profil | Couvre la liberté du LLM ET un comportement déterministe |
| Calibrage seuils | Hybride a priori + baseline | Évite la cristallisation d'un mauvais comportement (option observée seule) ET l'irréaliste (option a priori seul) |
| Métriques gatées | proactive_help_rate, mean_help_steps_before_resolution, correct_attempts_after_help_rate | Les 3 plus alignantes avec l'objectif pédagogique. `correction_view_rate` reste indicatif (validité profil) |
| Agrégation seuils | Globale CI + WARN par profil | Limite le risque CI flaky tout en gardant la visibilité par profil |
| Taille run | 5 questions × 3 profils = 15 convs | Cohérent avec mémoire `feedback_sim_variance`. Ajustable à 30 si bruit |
| Architecture profils | Service `ProfileBehavior` séparé | Runner déjà à 228 LOC, séparation testable, ouvre 064 |

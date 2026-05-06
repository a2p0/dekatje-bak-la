# Tuteur — redesign from scratch (062)

**Created**: 2026-05-06
**Branch**: `062-tutor-redesign-from-scratch`
**Status**: Design — pending implementation
**Supersedes**: 011, 037, 038, 042 (reverted), 044, 049, 059

## 1. Pourquoi ce redesign

L'archi tuteur actuelle (post-049) reste pédagogiquement insatisfaisante malgré dix
features successives. Symptômes :

- Le tuteur paraît mécanique, enchaîne des phases prévisibles
  (`enonce → spotting_type → spotting_data → guiding`) au lieu d'avoir une vraie
  conversation.
- Les questions qu'il pose sonnent comme un interrogatoire — verbe d'action +
  catégorie d'information à chercher — pas comme un prof qui aide.
- Les élèves ne progressent pas plus vite avec qu'avant : la métrique sim
  `respect_process` plafonne à `3.20/5`, et les hypothèses prompt-only
  (H3a/H4/H5) toutes dégradent l'expérience pédagogique en mode défensif.

Le diagnostic : le problème est **architectural**, pas paramétrique. La machine
d'état à 9 phases pilotée par le LLM via 4 tools force le tuteur dans un script.
Tuner le prompt revient à essayer d'humaniser un script.

Ce redesign **part d'une page blanche pédagogique** : qu'est-ce qu'un bon moment de
tutorat pour un élève STI2D qui prépare le BAC, et qu'est-ce que la machine doit
faire pour le permettre ?

## 2. Recadrage de l'objectif app

L'objectif principal de DekatjeBakLa est **faire réussir un sujet de BAC à l'élève**,
pas couvrir le programme STI2D. Conséquences directes :

- Donner le savoir disciplinaire à l'élève s'il ne le maîtrise pas (formule, concept)
  **n'est pas un échec pédagogique**. C'est même la condition pour qu'il puisse
  exercer ce qu'on veut développer.
- Les compétences que l'élève doit développer sont les **compétences-sujet** :
  lire un sujet, repérer les infos dans les DT/DR, articuler un raisonnement,
  construire une conclusion.
- Le tuteur est un **bouton SOS**, pas une étape obligatoire. L'élève travaille en
  autonomie sur papier et sollicite le chat quand il bloque. Pas de progression
  imposée. Pas de conversation continue.

## 3. Posture du tuteur

**Prof STI2D sympa qui tutoie**. Pas familier-camarade ("ah ouais", "vas-y"). Pas
formel-distant ("Pourriez-vous identifier…"). Court, direct, sans détour.

**Une intervention type, c'est** :

- Une instruction ou une donnée concrète
- + soit une demande de retour ("dis-moi ce que tu trouves")
- + soit un choix proposé ("tu veux qu'on le fasse ensemble ou je te donne ?")

1-3 phrases par message. Pas de questions socratiques alambiquées. Pas de "70%
de tes messages se terminent par une question ouverte". Pas de "verbe d'action +
catégorie".

## 4. User stories prioritaires

### US1 — Aide graduée pilotée par l'élève (P1)

L'élève ouvre le drawer, clique un chip ou tape un message ("je bloque"). Le
tuteur répond au niveau d'aide qu'on lui demande, pas au niveau au-dessous, pas
au niveau au-dessus. À chaque palier, il **propose explicitement** le choix
suivant : *"tu veux qu'on le fasse ensemble ou je te donne ?"*

Paliers (de l'abstrait au concret) :

1. Méthode / formule / structure de réponse
2. Valeurs identifiées (sans calcul)
3. Calcul détaillé (sans résultat)
4. Résultat final (avec **cap déterministe**, voir US3)

**Acceptance** : pour une question de calcul, l'élève peut obtenir successivement
formule, valeur, calcul détaillé en cliquant des chips. Le résultat final
n'apparaît pas si l'élève n'a tenté < 2 fois et n'a pas vu la correction.

### US2 — Le tuteur réagit aux events page (P1)

L'élève peut afficher la correction officielle ou les data_hints sur la page
question (hors drawer). Le tuteur en tient compte :

- Si le drawer est ouvert et l'élève clique "afficher correction" → le tuteur
  émet un message d'appropriation : *"Tu as vu la correction. Sur quel passage
  tu veux qu'on revienne ?"* (chips contextualisés)
- Si le drawer est fermé et l'élève clique "afficher data_hints" → l'event est
  enregistré silencieusement. À la prochaine ouverture, le tuteur démarre en
  tenant compte de cette information ("Tu as les valeurs. Tu préfères choisir
  la formule ensemble ou tenter le calcul ?").

**Pas d'ouverture proactive du drawer**. L'élève reste seul maître de l'activation.

### US3 — Cap résultat final déterministe (P1)

Le tuteur **peut donner le résultat final** dans deux situations :

- L'élève a fait `≥ 2 tentatives` (peu importe le verdict)
- OU l'élève a vu la correction officielle (`viewed_correction`)

Sinon, le tuteur refuse poliment la demande de résultat final et propose
soit une dernière tentative avec un dernier indice, soit le bouton "afficher la
correction" sur la page.

**Acceptance** : un élève qui clique `[Donne le résultat]` à 0 tentatives reçoit
un refus pédagogique. À 2 tentatives, il reçoit le résultat avec le raisonnement.

### US4 — Suivi de la navigation inter-question (P2)

Le drawer suit la question courante. Quand l'élève change de question, le drawer
filtre l'historique pour n'afficher que les messages de la nouvelle question.

Un message de transition est émis par le tuteur **sauf** si on est revenu sur
une question sans aucune interaction depuis la dernière transition (règle "sans
doublons" formalisée en section 6.4).

### US5 — Greeting unique par sujet (P3)

À la première ouverture du drawer pour un sujet donné, le tuteur émet un message
court d'accueil (1 phrase). Pas de re-greeting ultérieur. Pas de relance après
12h d'inactivité (062 retire cette mécanique de 049).

### US6 — Profils de questions adaptatifs (P2)

Le comportement du tuteur s'adapte au type de question (`answer_type`) :

- `calcul` : guidage formule → valeurs → calcul → résultat
- `identification` : guidage emplacement → valeur
- `qcm` : élimination de distracteurs → bonne réponse
- `justification` : mots-clés → structure → rédaction
- `representation` : structure → étapes → tracé / DR rempli
- `verification` : critère → application → conclusion
- `conclusion` : éléments à reprendre → structure → rédaction

Concrètement, ce sont les chips proposés et le `behavior_hint` du prompt qui
varient. Le calibrage exact du mapping `(answer_type, phase) → chips` est
**différé à une session sujet-en-main** (voir mémoire
`project_062_chips_calibration.md`).

## 5. Architecture — vue d'ensemble

### 5.1 Principes architecturaux

1. **La machine n'est plus dans le LLM.** Le code Ruby pilote la trace, calcule
   les chips, dérive les phases. Le LLM ne fait que parler en respectant un
   budget d'aide qu'il voit dans son prompt.
2. **La trace remplace les phases persistées.** Une `QuestionTrace` par question
   stocke des events bruts (élève a vu data_hints, élève a tenté, tuteur a donné
   la formule, etc.). La phase est une **fonction pure dérivée** de la trace,
   jamais persistée comme état autorité.
3. **Un seul appel LLM par tour de chat (chemin critique).** Un classifier
   asynchrone court tourne après le tour pour mettre à jour la trace. Pas de
   double appel séquentiel devant l'élève.
4. **Cap déterministe sur le résultat final.** Le seul vrai garde-fou est appliqué
   dans le prompt avec des compteurs déterministes lus côté code.

### 5.2 Flux d'un tour de chat

```
[message élève (ou clic chip)]
   │
   ├─► Tutor::ValidateInput
   ├─► Tutor::RecordStudentEvent      (ajoute student_attempt OU enregistre chip)
   ├─► Tutor::BuildContext            (system prompt avec trace + budget + cap + behavior_hint)
   ├─► Tutor::CallLlm                 (appel streamé, prose pure, pas de tool)
   │      │
   │      └─► broadcast chunks → drawer
   │
   ├─► [STREAMING TERMINÉ]
   ├─► Tutor::Classify                (1 appel léger sync, message tuteur → annotation events)
   ├─► Tutor::RecordTutorEvents       (applique annotation à la trace)
   ├─► Tutor::ChipsPresenter          (calcule chips depuis trace + answer_type + phase dérivée)
   └─► Tutor::BroadcastDone           (envoie payload `done` ActionCable avec chips)
```

### 5.3 Approche d'implémentation retenue : F (single LLM + classifier async)

Le brainstorming a comparé six approches (Reactor 100% code, LLM 100% libre,
hybride simple, two-stage classifier+renderer, structured output bi-canal,
single+classifier async). L'approche retenue est **F (single LLM + classifier
asynchrone)**.

**Pourquoi F** :

- **1 appel LLM en chemin critique** : streaming intact, pas de doublement de
  latence (vs D two-stage).
- **Posture libre** du LLM : pas contraint par un schema d'output (vs E structured
  output forcé).
- **Portabilité totale** : prose pure, pas de tool-use forcé, fonctionne avec
  tous les providers que les élèves peuvent configurer (anthropic, openrouter,
  openai, google).
- **Trace fiable à 90-95%** : les events critiques (clics page, clics chips) ne
  dépendent pas du classifier — loggés par le code direct. Le classifier ne
  rattrape que ce que dit le LLM en prose.
- **LOC modeste** (~570 vs ~1180 actuels, soit -50%).

**Configuration retenue** :

- Classifier sur **clé serveur** (`ANTHROPIC_API_KEY`), modèle haiku 4.5,
  temperature 0. L'élève ne paie pas le classifier. Coût marginal (~$1-2/mois
  100 élèves).
- Classifier **inline post-response** (pas Sidekiq) : appel sync après fin
  streaming, update trace, puis envoi payload `done`. Décale chips ~500ms
  (transparent — élève finit de lire le message).
- Si le classifier rate (JSON malformé, timeout, rate limit) : trace neutre pour
  ce tour, pas de retry. Le LLM verra le budget se réajuster au tour suivant.

### 5.4 Modèle de données — `TutorState` (JSONB)

Pas de migration de schéma BDD. Seul le format JSONB stocké dans
`conversations.tutor_state` change.

```ruby
TutorState = Data.define(
  :current_question_id,    # Integer ou nil
  :greeted,                # Boolean — true après le 1er ouverture du drawer dans ce sujet
  :question_traces,        # Hash<String, QuestionTrace> — clé = question_id.to_s
  :concepts_seen           # Array<String> — pour Tutor::SubjectDebrief futur, ignoré par tuteur
)

QuestionTrace = Data.define(
  :question_id,            # Integer
  :events                  # Array<Event> — append-only
) do
  def budget                # calculé à la volée depuis events, pas de cache
    # { formule_given:, value_given:, calc_given:, result_given:, attempts_count:, viewed_correction: }
  end
end

Event = {
  type:    "viewed_data_hints" | "viewed_correction" | "navigated_here" |
           "student_attempt"   | "tutor_gave"        | "marked_done"     |
           "concept_seen",
  at:      ISO8601,
  source:  "page_click" | "chip_click" | "llm_message" | "classifier" | "code",

  # selon type :
  step:    Integer ou nil,
  content: String ou nil,                                    # student_attempt
  verdict: "correct" | "incorrect" | "unknown",              # student_attempt
  what:    "formule" | "valeur" | "calcul" | "résultat" |
           "structure" | "élimination" | "argument",         # tutor_gave
  reason:  "tutor_revealed" | "student_solved" |
           "viewed_correction" | "abandoned",                # marked_done
  concept: String                                            # concept_seen
}
```

**Phase dérivée** : `Tutor::DerivePhase.call(trace, answer_type) → :fresh | :armed | :debug | :close | :done`. Lecture seule pour l'UI (chips) et la sim. Jamais persistée.

### 5.5 Services Ruby

| Service | Rôle | LOC approx |
|---|---|---|
| `Tutor::ProcessMessage` | Orchestrateur du flux d'un tour | 80 |
| `Tutor::ValidateInput` | Sanitize + garde-fous | 30 |
| `Tutor::BuildContext` | Assemble system prompt 6 blocs | 150 |
| `Tutor::CallLlm` | Appel RubyLLM streamé, prose pure | 70 |
| `Tutor::Classify` | **Nouveau** — classifier message tuteur → annotation | 80 |
| `Tutor::RecordEvent` | Append event atomique à la trace | 40 |
| `Tutor::DerivePhase` | Fonction pure (trace, answer_type) → Symbol | 50 |
| `Tutor::ChipsPresenter` | Mapping (answer_type, phase, budget) → chips | 90 |
| `Tutor::BehaviorHints` | Mapping statique (signal, answer_type, budget) → hint | 80 |
| `Tutor::BroadcastMessage` | Streaming chunks ActionCable | 40 |
| `Tutor::BroadcastDone` | Payload final avec chips | 30 |

**Suppressions** (~535 LOC) :

- `ApplyToolCalls` (transition matrix), `ParseToolCalls`, `FilterSpottingOutput`,
  `InjectDataHints`, `UpdateTutorState`, `BuildIntroMessage`,
  `BuildWelcomeMessage`
- Les 4 tools : `transition_tool`, `request_hint_tool`,
  `evaluate_spotting_tool`, `update_learner_model_tool`

### 5.6 System prompt

Six blocs concaténés, ~600 mots cible (vs ~1100 aujourd'hui) :

1. **POSTURE** — qui tu es, comment tu parles
2. **CONTEXTE QUESTION** — sujet, partie, énoncé, type
3. **CORRECTION STRUCTURÉE** — input_data, intermediate_steps, final_answers
   (depuis `Answer.structured_correction`, livré par feature 046)
4. **ÉTAT D'AIDE** — budget calculé (formule_given, value_given, etc.)
5. **CAP RÉSULTAT FINAL** — formulation positive sur la levée :
   *"Tu peux donner le résultat si tentatives ≥ 2 OU correction vue. Sinon, refuse poliment."*
6. **ACTION ATTENDUE** — résumé du dernier signal de l'élève + `behavior_hint`
   sélectionné par mapping statique (Option A retenue, ~30-50 entrées)

**Ce qui disparaît du prompt 049** :

- Plus de "tuteur socratique"
- Plus de "70% de tes messages se terminent par une question ouverte"
- Plus de "verbe d'action + catégorie"
- Plus de "Indices strictement gradués 1 à 5"
- Plus de "Avant toute correction, exiger l'auto-évaluation 1-5"
- Plus de noms de phases dans le prompt (régressions H3a/H4/H5
  structurellement évitées)

### 5.7 Greeting

À la première ouverture du drawer pour un sujet (`greeted: false`),
`BuildContext` injecte un `last_signal_summary` spécial qui demande au LLM de
saluer brièvement (1 phrase max). Après envoi, `greeted: true` est écrit côté
code dans le `TutorState`.

Plus de service `BuildWelcomeMessage` ni `BuildIntroMessage`. Plus de
re-greeting 12h.

## 6. UI / Chips

### 6.1 Drawer et page question

Le drawer (reskin Radical 056) et la page question (reskin Radical 055) sont
**conservés sans changement structurel**. Les composants suivants restent
inchangés :

- Animation slide drawer
- Bulles de messages (élève / tuteur)
- Frame `tutor-chips` au pied du drawer
- Stimulus `tutor_chat_controller`, `tutor_activator_controller`
- ActionCable channel `ConversationChannel`
- Boutons "Afficher data_hints" et "Afficher correction" sur la page question

**Ajouts** :

- Les boutons page émettent un POST vers `/student/events` (ou shallow équivalent)
  qui appelle `Tutor::RecordEvent` côté serveur. Le clic continue de révéler
  l'encadré côté client (Stimulus existant), **plus** émet l'event.
- Les chips peuvent être **désactivés visuellement** (greyed) avec tooltip si le
  cap résultat est actif. Clic désactivé → tooltip seulement, pas de POST.

### 6.2 Mapping chips par answer_type

Structure validée :

```ruby
{ action: "send" | "navigate" | "confidence", label:, payload: }
```

**Calibrage du contenu différé à une session sujet-en-main**. Voir mémoire
`project_062_chips_calibration.md`. Sets minimaux de démarrage documentés dans le
brainstorm (mémoire `project_062_tutor_redesign_brainstorm.md`, section 5.2).

### 6.3 Conversation créée silencieusement

Aujourd'hui, `Conversation` n'est créée qu'à la première activation explicite du
tuteur. 062 modifie ce comportement : à la **première visite** d'une question
d'un sujet, on s'assure qu'une `Conversation` `disabled` existe pour
`(student, subject)`.

Pourquoi : permet de logger les events page (`viewed_data_hints`,
`viewed_correction`) **avant** que l'élève ait jamais ouvert le drawer. Si
l'élève n'active jamais le tuteur, la conversation reste `disabled` mais collecte
les events.

### 6.4 Navigation inter-question

**Drawer suit la navigation (Option A)** : `current_question_id` change avec
l'URL, le drawer se rafraîchit pour ne montrer que les messages de la nouvelle
question.

Un **message de transition** est émis par le tuteur uniquement si :

1. La transition vers Q **n'a jamais eu lieu** dans cette session, OU
2. Depuis la dernière transition vers Q, l'élève a **interagi avec Q** (message
   tapé, chip cliqué, ou bouton page de Q).

Pas de rate-limit temporel — la règle "sans doublons" couvre déjà le cas du
switch rapide.

### 6.5 Réaction aux clics page (Option III)

Seul `viewed_correction` déclenche un message auto LLM côté tuteur (1 appel LLM,
pédagogiquement justifié — bascule en mode appropriation).

Tous autres clics page (`viewed_data_hints`, expand PDF, download DR) → mise à
jour silencieuse des chips uniquement (zéro appel LLM, recalcul ChipsPresenter).

L'évolution future vers une Option II partielle (par answer_type) est prévue
sans refactoring : `RecordEvent` est point d'attache unique, mapping
`TRIGGERS_TUTOR_MESSAGE_BY_TYPE` extensible.

## 7. Sim et métriques

### 7.1 Métriques structurelles (réécrites)

Les métriques 049 (`phase_rank`, `state_targets`,
`dt_dr_leak_count_non_spotting`) sont **invalidées** par le redesign. Réécriture :

| Métrique | Définition |
|---|---|
| `resolution_rate` | Fraction de questions résolues (`student_attempt verdict: correct` apparaît avant `viewed_correction`). **Métrique principale**, alignée avec l'objectif app. |
| `cap_violations` | Nombre de fois où le LLM a divulgué le résultat final malgré cap actif (event classifier détecté + budget locked). **Cible: 0**. |
| `mean_help_steps_before_resolution` | Moyenne du nombre de paliers d'aide donnés avant résolution. |
| `proactive_help_rate` | Fraction des `tutor_gave` émis sans demande explicite (chip ou message). Proxy d'un tuteur trop directif. |
| `correct_attempts_after_help_rate` | Fraction des `student_attempt verdict: correct` qui suivent un `tutor_gave`. Proxy de bon dosage. |
| `attempts_per_question` | Moyenne du nombre de tentatives par question. |
| `correction_view_rate` | Fraction des questions où l'élève a vu la correction. |
| `mean_turns_to_resolution` | Tours médian pour atteindre `verdict: correct`. |

### 7.2 Métriques juge (LLM-judge)

Critères conservés : **bienveillance**, **guidage progressif**, **focalisation**.

Reformulés : **non-divulgation** → **cap résultat respecté** (rubrique permissive
selon recadrage objectif app — voir mémoire `project_primary_objective`).

**Retiré** : `respect_process` (062 n'a plus de "process" à respecter).

**Ajouté** : **ton et registre** (le tuteur tutoie, parle court, sympa-sans-familier).

### 7.3 Profils élèves simulés

Trois profils redéfinis pour 062 (chacun **utilise les chips** pour être réaliste) :

| Profil | Chips d'aide tuteur | viewed_correction | Comportement |
|---|---|---|---|
| autonome | rare (≤1 par question) | **jamais** | retente seul, abandonne après 6+ tours sans progrès |
| collaboratif | escalade graduelle (formule → valeur → calcul) | seulement si bloqué 8+ tours | demande chip suivant après tentative |
| passif | rapidement et au max | rapidement (3+ tours sans progrès) | demande aide max ou correction |

### 7.4 Découpage PR 062 vs 063 (Option 3 simple)

**PR 062** livre :

- Toute la mécanique tuteur (services, prompt, chips, drawer, migration)
- `structural_metrics.rb` réécrit
- **Profil collaboratif uniquement** (suffisant pour valider SC-A et SC-B)
- Rake task `tutor:simulate` mise à jour
- Workflow CI mis à jour

**PR 063** (suivi, hors scope de ce design) :

- Profils `autonome` et `passif`
- Juge LLM réécrit (rubrique 062)
- Validation des SC C/D/E/F

## 8. Migration depuis 049

### 8.1 Reset complet

L'app n'est pas vraiment en prod (très peu d'élèves actifs). On reset toutes les
`tutor_state` existantes au déploiement :

```ruby
class RebootTutorStateFor062 < ActiveRecord::Migration[8.1]
  def up
    Conversation.in_batches(of: 500) do |batch|
      batch.update_all(tutor_state: {})
    end
    Conversation.where(lifecycle_state: %w[validating feedback])
                .update_all(lifecycle_state: 'active')
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

**Ce qui est conservé** : Conversations, Messages historiques (élève voit son
chat précédent), résolution clé API, lifecycle_state `disabled / active / done`.

**Ce qui est perdu** : phases historiques, `concepts_mastered`,
`concepts_to_revise`, `hints_used`, `welcome_sent` — pas de migration des
données legacy (Option a retenue).

### 8.2 AASM simplifié

Le `Conversation` AASM passe de 5 à 3 états :

```ruby
aasm column: :lifecycle_state do
  state :disabled, initial: true
  state :active
  state :done

  event :activate do
    transitions from: :disabled, to: :active, guard: :student_has_api_key_or_free_mode?
  end

  event :finish do
    transitions from: :active, to: :done
  end
end
```

Les états `validating` et `feedback` étaient des artefacts du flow 049
(auto-évaluation confiance, feedback final). 062 ne les a plus.

### 8.3 Code legacy supprimé (~535 LOC)

- `app/services/tutor/apply_tool_calls.rb`
- `app/services/tutor/parse_tool_calls.rb`
- `app/services/tutor/filter_spotting_output.rb`
- `app/services/tutor/inject_data_hints.rb`
- `app/services/tutor/update_tutor_state.rb`
- `app/services/tutor/build_intro_message.rb`
- `app/services/tutor/build_welcome_message.rb`
- `app/services/tutor/tools/` (4 tools, dossier vidé)

Les specs unitaires correspondantes sont supprimées.

### 8.4 Specs feature à réécrire

Toutes les specs qui touchent `tutor_state.current_phase`, `welcome_sent`,
`hints_used` etc. sont cassées. Périmètre estimé : ~800-1200 LOC de specs
touchées dans la même PR :

- `spec/features/student_tutor_full_flow_spec.rb`
- `spec/features/student_tutor_spotting_spec.rb`
- `spec/features/student_tutor_activation_spec.rb`
- `spec/features/student_tutor_chat_spec.rb`
- `spec/features/student_tutor_chips_spec.rb`
- `spec/services/tutor/process_message_spec.rb`
- `spec/services/tutor/update_tutor_state_spec.rb`
- `spec/models/conversation_aasm_spec.rb`
- `spec/models/types/tutor_state_type_spec.rb`
- `spec/jobs/process_tutor_message_job_spec.rb`

Stratégie : suppression des specs de comportement disparu (spotting phases,
hints gradués), réécriture des autres pour refléter la nouvelle archi. Aucun
`pending` ni `xscenario` créé par 062.

### 8.5 Stratégie de merge

**Merge normal** (pas squash). Override de la mémoire
`feedback_squash_large_refactors` qui recommandait squash pour les refactors
tuteur. Décision a2p0.

## 9. Tests et validation

### 9.1 Pyramide

| Niveau | Cible | Outil |
|---|---|---|
| Unitaires | Services purs, sérialisation, mappings | RSpec |
| Request / Feature | Endpoints, drawer, ActionCable | RSpec request + Capybara/Cuprite |
| Sim LLM | Conversations bout-en-bout multi-tours | rake `tutor:simulate` |

Cibles approximatives : ~150 specs unitaires, ~60 specs avec stubs LLM, ~25-30
features.

### 9.2 Composants 100% testables sans LLM

- `Tutor::DerivePhase` (fonction pure, ~30 cas)
- `QuestionTrace#budget` (fonction pure, ~20 séquences)
- `Tutor::RecordEvent` (append-only, idempotence)
- `Tutor::ChipsPresenter` (mapping exhaustif, ~100 combinaisons)
- `Tutor::BehaviorHints.for(...)` (mapping exhaustif)
- `TutorStateType.serialize/deserialize` (roundtrip)
- `Conversation` AASM

### 9.3 Trois invariants critiques en specs

- **Invariant 1** : events append-only — un event ajouté n'est jamais modifié ni
  supprimé.
- **Invariant 2** : phase dérivée jamais persistée — `TutorState.members` ne
  contient pas `:phase` ni `:current_phase`. Si un dev les rajoute par accident,
  le test casse.
- **Invariant 3** : cap résultat respecté ou détecté comme violation — quand le
  LLM essaie de donner le résultat avec cap actif, soit il refuse, soit on
  enregistre un `cap_violation` event et le système continue de tourner.

### 9.4 Tests cross-provider

4 specs intégration (anthropic / openrouter / openai / google) avec stub SDK
respectif. Vérifient que le flux tuteur fonctionne sans dépendance hard à
Anthropic dans le chemin principal (le classifier, lui, est volontairement sur
clé serveur Anthropic).

### 9.5 Anti-flake

- Stubs `RubyLLM::Chat#ask` systématiques (`FakeRubyLlm`) dans les specs
  request/feature
- Wait timeouts ≥ 10s dans Cuprite
- Reset BDD entre specs
- Aucun `pending` ni `xscenario` créé par 062

## 10. Périmètre PR 062

Estimation par catégorie :

| Catégorie | LOC |
|---|---|
| Code Ruby (services, models, types) | ~700 |
| Migration | ~30 |
| Specs unitaires | ~600 |
| Specs request/feature | ~500 |
| Vues ERB / Stimulus | ~150 |
| Configuration (rake, workflow) | ~80 |
| Suppressions legacy | ~−800 |
| **Total net** | **~1260 LOC** |

PR grosse mais bornée et structurée par l'ordre d'exécution interne (voir
brainstorm section 7.3).

### 10.1 Definition of Done

Avant de merger 062 :

- [ ] CI verte (specs unitaires + request + feature)
- [ ] Sim sur branche : `resolution_rate ≥ 70%` (collaboratif, 15 questions)
- [ ] Sim sur branche : `cap_violations = 0`
- [ ] Calibrage chips terminé (mémoire `project_062_chips_calibration.md` livrée)
- [ ] Spec self-review effectuée
- [ ] PR review humaine (au moins 1 cycle)
- [ ] Aucune spec en `pending` ou `xscenario` créée par 062

## 11. Hors scope explicite

Reportés à des features de suivi :

- **Calibrage des chips par answer_type** (mémoire
  `project_062_chips_calibration.md`) — session sujet-en-main dédiée, peut être
  conduite en parallèle ou avant `superpowers:writing-plans`.
- **Profils élèves complets et juge LLM réécrit** — PR 063 (suivi de 062).
- **`Tutor::SubjectDebrief`** — feature future qui consommera `concepts_seen`
  pour un retour fin-de-sujet à l'élève.
- **`depends_on_questions` dans extraction** — nécessaire pour le cas
  "sélection d'équipement à partir de Q précédentes". Chantier extraction
  futur, hors redesign tuteur.
- **Évolution Option II partielle** (réaction auto LLM sur d'autres clics page
  que `viewed_correction`) — l'archi 062 le permet sans refactoring, à
  déclencher quand on aura mesuré quels signaux secondaires méritent un message.

## 12. Décisions clés tracées

Les décisions principales du brainstorming ainsi que les options écartées sont
conservées dans la mémoire `project_062_tutor_redesign_brainstorm.md` (lue par
les sessions futures).

Décisions structurantes pour cette spec :

| Décision | Alternative écartée | Raison |
|---|---|---|
| Approche F (LLM single + classifier async) | A, B, C, D, E | Portabilité providers + LOC modeste + posture libre |
| Phase dérivée fonction pure | Phase persistée comme état autorité | Évite que le LLM combatte la machine |
| Classifier sur clé serveur | Classifier sur clé élève | Simplicité, coût marginal, fiabilité indépendante du provider élève |
| Budget calculé à la volée | Budget caché dans la trace | Simplicité, pas de désynchro |
| Mapping statique behavior_hint | Templates paramétrés | Phrases bien construites > flexibilité |
| Cap résultat formulé positif (OU) côté prompt | Formulation négative (ET) | Lecture LLM plus claire |
| Reset complet `tutor_state` | Migration data legacy | App pas vraiment en prod |
| AASM simplifié 3 états | Garder validating/feedback | Plus de "process" à respecter |
| Drawer suit navigation + règle sans-doublons | Drawer collé à 1 question | Lisibilité, focalisation |
| Réaction LLM uniquement sur viewed_correction | Sur tous clics page | Coût, pédagogie ciblée |
| Découpage PR 062/063 simple | Tout dans 062 ou tout dans 063 | Validation pré-merge possible |
| Merge normal (pas squash) | Squash | Décision a2p0 |

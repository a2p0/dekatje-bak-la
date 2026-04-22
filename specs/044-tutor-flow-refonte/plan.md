# Implementation Plan: Refonte Flow Tuteur

**Branch**: `044-tutor-flow-refonte` | **Date**: 2026-04-22 | **Spec**: [spec.md](spec.md)

## Summary

Refonte du flow d'entrée tuteur : auto-ouverture du drawer à l'activation, message d'accueil LLM slot-fill, suppression du bouton "Commencer" dupliqué, badge intro-question sur la page question. Aucune nouvelle table — extension du modèle TutorState JSONB existant + migration colonne `kind` sur `messages`.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1
**Primary Dependencies**: Hotwire (Turbo Streams, Stimulus), RubyLLM (appel LLM welcome), AASM (transitions Conversation existantes)
**Storage**: PostgreSQL — extension JSONB `student_sessions.tutor_state`, migration `messages.kind`
**Testing**: RSpec + FactoryBot + Capybara (feature specs)
**Target Platform**: Web, serveur Rails fullstack
**Performance Goals**: Drawer ouvert < 1s post-activation (hors LLM) ; welcome affiché < 5s (LLM inclus)
**Constraints**: Zéro LLM pour l'intro-question (synchrone) ; fallback statique welcome si LLM fail ; greeting non-sollicitant (SC-005)
**Scale/Scope**: Feature élève existante, ~1 sujet actif / session

## Constitution Check

| Principe | Statut | Note |
|---|---|---|
| I — Hotwire only | ✅ | Turbo Streams + Stimulus, zero SPA |
| II — RGPD | ✅ | Pas de nouvelle donnée personnelle |
| III — Security | ✅ | Clé API gérée par `ResolveTutorApiKey` existant |
| IV — TDD | ✅ | Specs avant code pour chaque composant |
| V — Simplicité | ✅ | Pas de LLM pour intro-question, fallback statique welcome |
| VI — Workflow | ✅ | Branche dédiée, PR, CI avant merge |

## Project Structure

### Documentation (cette feature)

```text
specs/044-tutor-flow-refonte/
├── plan.md          ← ce fichier
├── research.md      ← décisions architecturales
├── data-model.md    ← entités, services, flux
└── tasks.md         ← généré par /speckit.tasks
```

### Source Code (fichiers touchés)

```text
db/migrate/
└── YYYYMMDD_add_kind_to_messages.rb         ← NEW migration

app/models/
├── tutor_state.rb                           ← MODIFY (welcome_sent, intro_seen)
└── message.rb                               ← MODIFY (enum kind)

app/services/tutor/
├── build_welcome_message.rb                 ← NEW
└── build_intro_message.rb                   ← NEW

app/controllers/student/
├── conversations_controller.rb              ← MODIFY (create → auto-welcome + auto-open)
│                                                      (mark_intro_seen NEW action)
└── questions_controller.rb                  ← MODIFY (show → build intro if needed)

app/views/student/
├── tutor/_tutor_activated.html.erb          ← MODIFY (supprimer bouton Commencer)
├── subjects/show.html.erb                   ← MODIFY (auto-open si welcome non envoyé)
├── questions/show.html.erb                  ← MODIFY (badge intro)
└── conversations/_drawer.html.erb           ← MODIFY (afficher welcome/intro dans messages)

app/javascript/controllers/
└── chat_drawer_controller.js                ← MODIFY (action mark_intro_seen à l'ouverture)

config/routes.rb                             ← MODIFY (patch :mark_intro_seen)

spec/
├── models/tutor_state_spec.rb               ← MODIFY (welcome_sent, intro_seen)
├── models/message_spec.rb                   ← MODIFY (enum kind)
├── services/tutor/build_welcome_message_spec.rb  ← NEW
├── services/tutor/build_intro_message_spec.rb    ← NEW
├── controllers/student/conversations_controller_spec.rb  ← MODIFY
├── controllers/student/questions_controller_spec.rb      ← MODIFY
└── features/student/tutor_flow_spec.rb      ← NEW (feature Capybara E2E)
```

## Implementation Phases

### Phase A — Migration et modèles (fondation)

**Objectif**: Poser la fondation de données sans toucher l'UI.

**A1 — Migration `messages.kind`**
- Créer `db/migrate/YYYYMMDD_add_kind_to_messages.rb`
- `add_column :messages, :kind, :integer, default: 0, null: false`
- Réversible : `remove_column`

**A2 — Étendre TutorState**
- Ajouter `welcome_sent` (Boolean, default: false) au `Data.define`
- Ajouter `intro_seen` dans `QuestionState` (Boolean, default: false)
- Mettre à jour `TutorState.default` et `to_prompt` si pertinent
- Rétrocompatibilité : les enregistrements existants sans ces clés lisent `false` par défaut (via `fetch(:welcome_sent, false)` dans le type custom)

**A3 — Enum `kind` sur Message**
- Ajouter `enum :kind, { normal: 0, welcome: 1, intro: 2 }` dans `Message`
- Specs : `message_spec.rb` — vérifier les 3 valeurs et default

**Specs A** :
- `spec/models/tutor_state_spec.rb` — `welcome_sent` default false, `intro_seen` default false
- `spec/models/message_spec.rb` — enum kind, default normal

---

### Phase B — Services (logique métier)

**Objectif**: Implémenter `BuildWelcomeMessage` et `BuildIntroMessage`.

**B1 — Tutor::BuildIntroMessage** (zéro LLM, implémenter en premier)

```
Input : question, conversation
Logique slot-fill :
  hint = answer.data_hints&.first ||
         structured_correction&.dig("input_data", 0, "name") ||
         nil
  content = "Question #{question.number} — #{question.label}. " \
            "Pour progresser, #{hint ? "cherche #{hint[:location] || hint}" : "relis l'énoncé et les documents techniques"}. " \
            "Je suis là si tu as besoin d'aide — sinon, lance-toi."
Persiste : conversation.messages.create!(kind: :intro, role: :assistant, content: content)
```

**B2 — Tutor::BuildWelcomeMessage** (avec LLM)

```
Input : subject, conversation, api_key
Logique :
  n_questions = subject.questions.kept.count
  phrase = llm_call(prompt_encouragement) rescue FALLBACK_PHRASE
  content = "Bonjour ! Tu vas travailler sur #{subject.title} (#{n_questions} questions). #{phrase}"
Persiste : conversation.messages.create!(kind: :welcome, role: :assistant, content: content)
Met à jour : TutorState.with(welcome_sent: true) via UpdateTutorState
```

Fallback statique : `"Lance-toi quand tu es prêt !"`

Prompt LLM welcome (voir data-model.md) — appel direct RubyLLM, pas via ProcessMessage.

**Specs B** :
- `spec/services/tutor/build_intro_message_spec.rb`
  - Avec data_hints → slot rempli
  - Avec structured_correction.input_data → fallback slot
  - Sans aucune donnée → formulation générique
  - Message persisté avec kind: :intro
- `spec/services/tutor/build_welcome_message_spec.rb`
  - LLM success → content contient title + n_questions + phrase LLM
  - LLM failure → fallback statique, pas d'exception propagée
  - Message persisté avec kind: :welcome
  - `welcome_sent` mis à true dans TutorState après appel

---

### Phase C — Controller et routes

**Objectif**: Câbler les services dans les controllers.

**C1 — ConversationsController#create** (activation)

Après `@conversation.activate!` :
1. Appeler `Tutor::BuildWelcomeMessage.call(subject: @subject, conversation: @conversation, api_key: resolve_key)` si `!@session_record.tutor_state.welcome_sent`
2. Turbo Stream 1 : replace `tutor-activation-banner` → `_tutor_activated` (sans bouton Commencer)
3. Turbo Stream 2 : dispatch event `tutor:drawer-open` → déclenche `chat-drawer#open` via Stimulus

**C2 — QuestionsController#show**

Après `@conversation = ...` :
1. Si `@conversation` présent ET `!intro_seen_for?(@question.id)` :
   - `Tutor::BuildIntroMessage.call(question: @question, conversation: @conversation)` sauf si message intro déjà présent
2. `@has_intro_badge = intro_message_pending?(@question.id)`

**C3 — ConversationsController#mark_intro_seen** (nouvelle action)

```ruby
def mark_intro_seen
  question_id = params[:question_id].to_i
  # update TutorState question_states[question_id].with(intro_seen: true)
  head :ok
end
```

**C4 — Routes**

```ruby
resources :conversations, only: [:create] do
  member do
    patch :mark_intro_seen
    # ... routes existantes (messages, confidence)
  end
end
```

**Specs C** :
- `spec/requests/student/conversations_spec.rb` ou controller spec
  - `POST #create` → welcome message créé, turbo streams rendus
  - `PATCH #mark_intro_seen` → TutorState mis à jour, 200 OK
- `spec/requests/student/questions_spec.rb`
  - `GET #show` avec conversation active → intro message créé si absent
  - `GET #show` sans conversation → pas d'intro, pas de badge

---

### Phase D — UI (vues et Stimulus)

**Objectif**: Brancher l'auto-ouverture, le badge, et supprimer le doublon.

**D1 — `_tutor_activated.html.erb`**
- Supprimer le bouton "Commencer"
- Garder uniquement la confirmation visuelle ("Tuteur activé ✓")

**D2 — `subjects/show.html.erb`**
- Ajouter `data-action="turbo:load->chat-drawer#open"` conditionnel si `@conversation && !@conversation.tutor_state.welcome_sent` (pour le cas "tuteur déjà actif au chargement")
- Note : l'auto-open post-activation est géré par le Turbo Stream Dispatch en C1

**D3 — `questions/show.html.erb`**
- Ajouter badge "💬" ou dot indicator sur le bouton "Tutorat" si `@has_intro_badge`
- Aria-label mis à jour : "Ouvrir le tutorat IA — message en attente"

**D4 — `chat_drawer_controller.js`**
- Dans `open()`, après ouverture : si `data-conversation-id` présent, appeler `PATCH mark_intro_seen` via fetch (ou form action Stimulus)

**D5 — `_drawer.html.erb`**
- Les messages welcome et intro sont déjà affichés via la boucle existante sur `conversation.messages` — aucun changement nécessaire si kind est ignoré côté affichage.

**Specs D** :
- Feature Capybara `spec/features/student/tutor_flow_spec.rb`
  - Scenario 1 : Activation → drawer s'ouvre → message d'accueil visible
  - Scenario 2 : Retour sur page sujet → drawer ne s'ouvre pas (welcome_sent = true)
  - Scenario 3 : Page question → badge visible → ouverture drawer → message intro présent
  - Scenario 4 : Retour sur page question après ouverture → badge absent
  - Scenario 5 : Page question → élève tape réponse directement sans ouvrir drawer → envoi OK

---

### Phase E — Validation sim (post-merge)

**Objectif**: Vérifier SC-004 et SC-005 — non-divulgation et phase_rank non régressés.

**E1 — Sim baseline**
- Lancer sim sur seeds CIME (A.1-A.7) avec le nouveau flow
- Profils : `bon_eleve` (arrive avec réponse) + `eleve_paresseux`
- Vérifier : `phase_rank` ≥ baseline 043 (2.93), `non_divulgation` ≥ 4.07

**E2 — Vérification greeting non-sollicitant**
- Sur profil `bon_eleve` : premier message = réponse directe, pas de blocage tuteur
- `phase_rank` au premier tour = 1 (progression immédiate), pas de phase greeting bloquante

---

## Ordre d'implémentation recommandé

```
A1 migration → A2 TutorState → A3 Message enum
→ B1 BuildIntroMessage (specs first)
→ B2 BuildWelcomeMessage (specs first)
→ C1 conversations#create
→ C2 questions#show
→ C3 mark_intro_seen
→ C4 routes
→ D1-D5 UI
→ E1-E2 sim validation
```

## Risks & Mitigations

| Risque | Mitigation |
|---|---|
| `TutorState` rétrocompatibilité (clés absentes en DB) | `TutorStateType` existant utilise `fetch` avec default — ajouter `welcome_sent` et `intro_seen` avec `false` comme default dans le type custom |
| Auto-open drawer intrusif si JS désactivé | Dégradation gracieuse : sans JS, le drawer reste fermé, l'élève peut cliquer manuellement |
| LLM welcome timeout (> 5s) | Timeout 8s sur l'appel RubyLLM ; fallback statique si raise — flow non bloqué |
| Phase_rank régression (greeting bloquant) | SC-005 testé via sim E1-E2 avant merge ; règle prompt non-sollicitant encodée dans BuildWelcomeMessage |
| Intro message dupliqué (double render) | `QuestionsController#show` vérifie `conversation.messages.exists?(kind: :intro, question: @question)` avant de créer |

## Definition of Done

- [ ] Migration `messages.kind` propre (db:rollback fonctionne)
- [ ] `TutorState` rétrocompatible avec enregistrements existants
- [ ] `Tutor::BuildWelcomeMessage` — 4 specs passent (LLM success, LLM failure, contenu, persistance)
- [ ] `Tutor::BuildIntroMessage` — 4 specs passent (data_hints, structured_correction, générique, persistance)
- [ ] Controller specs create + mark_intro_seen
- [ ] Feature Capybara — 5 scenarios passent en CI
- [ ] Un seul bouton "Commencer" sur la page sujet (validé manuellement)
- [ ] Sim E1 : `non_divulgation` ≥ 4.07, `phase_rank` ≥ 2.93
- [ ] PR ouverte, CI vert

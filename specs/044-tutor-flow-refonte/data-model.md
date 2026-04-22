# Data Model: Feature 044 — Refonte Flow Tuteur

## Entités modifiées

### TutorState (app/models/tutor_state.rb)

Ajout de deux champs dans le `Data.define` :

```ruby
TutorState = Data.define(
  :current_phase,
  :current_question_id,
  :concepts_mastered,
  :concepts_to_revise,
  :discouragement_level,
  :question_states,
  :welcome_sent        # NEW — Boolean, default: false
)
```

**Champ `welcome_sent`** :
- `false` (default) — le message d'accueil n'a pas encore été envoyé pour ce sujet
- `true` — message d'accueil déjà envoyé, ne pas re-déclencher

Le champ `question_states` (Hash existant) est étendu :

```ruby
QuestionState = Data.define(
  :step,
  :hints_used,
  :last_confidence,
  :error_types,
  :completed_at,
  :intro_seen          # NEW — Boolean, default: false
)
```

**Champ `intro_seen`** :
- `false` (default) — message intro-question pas encore vu (badge affiché)
- `true` — élève a ouvert le drawer pour cette question (badge masqué)

> Aucune migration SQL requise — TutorState est sérialisé en JSONB dans `student_sessions.tutor_state` (colonne existante). Les nouveaux champs ont une valeur par défaut et sont rétrocompatibles.

---

### Message (app/models/message.rb)

Ajout d'un enum `kind` pour distinguer les messages système des messages de conversation normaux :

```ruby
enum :kind, {
  normal:  0,   # message tuteur normal (existant)
  welcome: 1,   # message d'accueil sujet (NEW)
  intro:   2    # message intro-question (NEW)
}
```

> Migration nécessaire : ajout colonne `kind integer default 0 not null` sur `messages`.

---

## Nouveaux services

### Tutor::BuildWelcomeMessage

```
Input:  subject (Subject), student_session (StudentSession)
Output: Result.ok(content: String) | Result.err(...)
```

- Construit le template : `"Bonjour ! Tu vas travailler sur [title] ([n] questions). [phrase LLM]"`
- Appel LLM léger (1 call, pas de streaming) pour la `PHRASE_ENCOURAGEMENT`
- Fallback statique si appel LLM échoue : `"Lance-toi quand tu es prêt !"`
- Persiste le Message (kind: :welcome) dans la Conversation
- Met à jour `TutorState#welcome_sent = true` via `UpdateTutorState`

### Tutor::BuildIntroMessage

```
Input:  question (Question), conversation (Conversation)
Output: Result.ok(content: String) | Result.err(...)
```

- Construit le template : `"Question [N] — [label]. Pour progresser, cherche [hint_or_concept]. Je suis là si tu as besoin d'aide — sinon, lance-toi."`
- Sélection du slot : `answer.data_hints.first` > `structured_correction["input_data"].first` > formulation générique
- Zéro appel LLM — entièrement déterministe
- Persiste le Message (kind: :intro) dans la Conversation
- Ne modifie PAS `TutorState` (pas de changement de phase)

---

## Flux de données

```
[Page sujet — activation]
  POST /student/:access_code/conversations
    → ConversationsController#create
    → Conversation.find_or_create (existant)
    → Tutor::BuildWelcomeMessage.call
        → LLM call (1 phrase)
        → Message.create!(kind: :welcome, role: :assistant)
        → TutorState.with(welcome_sent: true) → StudentSession.update!
    → Turbo Stream : replace banner → _tutor_activated (sans bouton Commencer)
    → Turbo Stream : dispatch event → chat-drawer#open

[Page sujet — tuteur déjà actif au chargement]
  GET /student/:access_code/subjects/:id
    → SubjectsController#show
    → if conversation && !tutor_state.welcome_sent
        → Tutor::BuildWelcomeMessage.call (même logique)
    → Render : drawer auto-open via data attribute Stimulus

[Page question — chargement]
  GET /student/:access_code/subjects/:id/questions/:id
    → QuestionsController#show
    → if conversation && !intro_seen?(question_id)
        → Tutor::BuildIntroMessage.call
            → Message.create!(kind: :intro, role: :assistant)
    → @has_intro_badge = intro_message_pending?(question_id)
    → Render : badge visible si @has_intro_badge

[Page question — ouverture drawer]
  Stimulus chat-drawer#open
    → dispatch event : mark_intro_seen
    → POST /student/:access_code/conversations/:id/mark_intro_seen
        → TutorState: question_states[q_id].with(intro_seen: true)
```

---

## Routes nouvelles / modifiées

```ruby
# Nouvelle action sur ConversationsController
member do
  patch :mark_intro_seen
end
```

---

## Contrat Tutor::BuildWelcomeMessage — prompt LLM

```
System: "Tu génères UNE SEULE phrase courte (max 15 mots) d'encouragement pour un élève de Terminale STI2D.
La phrase ne pose pas de question, ne demande rien à l'élève, et ne mentionne pas la correction.
Exemples valides : 'Tu peux le faire !' / 'Bonne chance pour ce sujet !' / 'Prends ton temps, tu y arriveras.'"

User: "Génère une phrase d'encouragement."
```

Temperature: 0.7, max_tokens: 30

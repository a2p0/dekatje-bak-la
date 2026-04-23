# Research: Feature 044 — Refonte Flow Tuteur

## Decision 1 — Rattachement du message d'accueil (welcome)

**Decision**: Le message d'accueil est rattaché à la `Conversation` existante du sujet (liée à la première question ou à toute question du sujet). Il est stocké comme un `Message` de rôle `assistant` avec un type spécial `welcome`. La `Conversation` est identifiée par le couple `(student, subject)` — déjà le cas dans `ConversationsController#create`.

**Rationale**: La `Conversation` est déjà le conteneur de tous les échanges tuteur pour un (student, subject). Ajouter un message `welcome` dedans évite de créer une nouvelle table ou un nouveau modèle. Le welcome est simplement le premier message injecté dans la conversation, visible si le drawer est ouvert sur la page sujet.

**Alternatives considered**:
- `Conversation` de type `subject_welcome` dédiée — rejetée : fragmentation inutile, ajoute une relation polymorphique complexe.
- Flag sur `StudentSession` — rejetée seule : ne stocke pas le contenu du message, seulement le statut "vu".

---

## Decision 2 — Tracking "welcome déjà envoyé"

**Decision**: Ajout d'un flag `welcome_sent: Boolean` dans le JSONB `tutor_state` de `StudentSession`. Ce flag est positionné à `true` après le premier envoi du message d'accueil pour un sujet donné.

**Rationale**: `TutorState` est déjà un `Data.define` immuable sérialisé en JSONB dans `StudentSession`. Ajouter `welcome_sent` suit exactement le même pattern que les champs existants (`current_phase`, `discouragement_level`, etc.) sans migration de colonne.

**Alternatives considered**:
- Nouveau champ booléen sur `StudentSession` — nécessite une migration, moins cohérent avec le pattern TutorState existant.
- Compter les messages de type `welcome` dans `Conversation` — possible mais plus lent (query) et couplé à la DB.

---

## Decision 3 — Génération LLM du slot `PHRASE_ENCOURAGEMENT`

**Decision**: Un nouveau service `Tutor::BuildWelcomeMessage` fait un appel LLM léger (modèle rapide, 1 appel, pas de streaming) pour générer une phrase d'encouragement non-sollicitante. Le résultat est injecté dans le template fixe. En cas d'erreur, un fallback statique est utilisé.

**Rationale**: L'appel est court et prévisible (une phrase). Il ne passe pas par le pipeline `ProcessMessage` complet (pas d'outils, pas de streaming, pas de `TutorState` update). Cela découple la génération du welcome du pipeline tuteur normal et simplifie les specs.

**Alternatives considered**:
- Réutiliser `ProcessMessage` avec un faux message user — rejeté : déclenche les tools, les transitions de phase, le streaming, la persistance — trop lourd pour un message d'accueil.
- Message purement statique — rejeté par le user (hybride slot-fill voulu).

---

## Decision 4 — Message intro-question : génération et stockage

**Decision**: Le message intro-question est généré **côté serveur au chargement de la page question** (`QuestionsController#show`), sans LLM. Les slots sont remplis depuis les données DB (`question.label`, `answer.data_hints`, `answer.structured_correction`). Le message est stocké comme `Message` de rôle `assistant` dans la `Conversation` liée à cette question, avec un champ `kind: :intro` (ou contenu vide si pas encore de conversation).

**Rationale**: Le message intro est entièrement déterministe (template + slots DB) — pas besoin de LLM pour lui. Il est court et peut être généré synchroniquement. Si la conversation n'existe pas encore, il sera créé à l'activation du tuteur.

**Alternatives considered**:
- LLM pour le message intro — rejeté : les slots data_hint/concept sont déjà structurés ; appel LLM inutile ici, contraire au slot-fill voulu.
- Génération en background job — rejeté : latence perceptible pour l'élève, complexité inutile pour un message synchrone court.

---

## Decision 5 — Badge "message en attente" sur page question

**Decision**: Le badge est rendu côté serveur dans `questions/show.html.erb` : visible si la `Conversation` existe ET que le message intro est présent mais n'a pas encore été "vu" (drawer pas encore ouvert pour cette question). Le flag "intro vu" est stocké dans `TutorState#question_states[question_id]` comme `intro_seen: Boolean`.

**Rationale**: Cohérent avec le pattern `question_states` existant dans `TutorState`. Le badge est statique au chargement — pas de polling. Il disparaît à la prochaine visite si l'élève a ouvert le drawer (Stimulus dispatch + Turbo update).

**Alternatives considered**:
- Badge géré entièrement en JS côté client — rejeté : état volatile, perdu au refresh.
- Turbo Stream push — rejeté : over-engineering pour un badge statique.

---

## Decision 6 — Auto-ouverture du drawer à l'activation

**Decision**: Après le `turbo_stream.replace` qui remplace le banner d'activation, un second Turbo Stream dispatch déclenche une action Stimulus `chat-drawer#open` via un événement custom. En pratique : `turbo_stream.action(:dispatch_event, ...)` ou un partial avec `data-action="turbo:frame-load->chat-drawer#open"`.

**Rationale**: L'auto-ouverture doit être déclenchée après le DOM update (après le replace Turbo Stream). L'approche Stimulus event dispatch est la plus légère et évite tout JS impératif dans le controller.

**Alternatives considered**:
- `redirect_to` après activation puis ouverture via param URL — rejeté : rompt le flow Turbo Stream.
- `setTimeout` JS global — rejeté : fragile, non-idiomatique Rails/Hotwire.

---

## Decision 7 — Bouton Commencer unique

**Decision**: Le bouton dans `_tutor_activated.html.erb` est supprimé. Seul le bouton en bas de `subjects/show.html.erb` est conservé. La bannière d'activation affiche uniquement la confirmation visuelle ("Tuteur activé ✓") sans bouton.

**Rationale**: Le doublon est explicitement identifié comme bug dans le draft utilisateur. La logique de navigation vers la première question non traitée est déjà présente dans `subjects/show.html.erb` via `@first_question` / `StudentSession#progression`.

---

## Constitution Check

| Principe | Statut | Note |
|---|---|---|
| I — Hotwire only | ✅ | Turbo Streams + Stimulus, zéro SPA |
| II — RGPD | ✅ | Pas de nouvelle donnée élève collectée |
| III — Security | ✅ | Clé API déjà gérée par `ResolveTutorApiKey` |
| IV — TDD | ✅ | RSpec specs à écrire avant le code |
| V — Simplicité | ✅ | Pas de LLM pour l'intro-question, fallback statique pour le welcome |
| VI — Workflow | ✅ | Plan → validation → feature branch → PR |

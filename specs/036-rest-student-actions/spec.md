# Feature Specification: REST Doctrine — Student Actions

**Feature Branch**: `036-rest-student-actions`  
**Created**: 2026-04-13  
**Status**: Draft  
**Input**: Vague 5a de la migration REST doctrine. Migrer 6 actions custom côté student vers des controllers RESTful dédiés : choix du périmètre, complétion de partie, complétion de sujet, révélation de correction, test de clé API, activation du tuteur. Les 3 actions du workflow tuteur (message, verify_spotting, skip_spotting) sont reportées à une vague 5b ultérieure car le tuteur sera repensé.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Choisir son périmètre de travail (Priority: P1)

En tant qu'élève, je veux choisir le périmètre sur lequel je vais travailler (partie commune, partie spécifique, ou les deux) afin d'adapter ma session à mes besoins d'apprentissage.

**Why this priority**: Action obligatoire avant d'attaquer un sujet avec parties communes + spécifiques. Sans ce choix, l'élève ne peut pas commencer son parcours.

**Independent Test**: Sur la page d'un sujet avec périmètres multiples, sélectionner une option, vérifier que le choix est sauvegardé et que l'élève est redirigé vers les questions correspondantes.

**Acceptance Scenarios**:

1. **Given** un sujet avec parties communes ET spécifiques, **When** l'élève choisit "Partie commune uniquement", **Then** son choix est enregistré et il est redirigé vers la première question de la partie commune
2. **Given** un élève non propriétaire de la session, **When** il tente de modifier le périmètre, **Then** l'action est rejetée

---

### User Story 2 — Marquer une partie comme terminée (Priority: P1)

En tant qu'élève, je veux déclarer qu'une partie est terminée (via le bouton "Fin de la partie commune/spécifique") afin de passer à la section suivante de mon parcours.

**Why this priority**: Transition clé du workflow multi-sections. Sans ça, un élève ne peut pas finir sa session.

**Independent Test**: Atteindre la dernière question d'une partie de section, cliquer "Fin de la partie commune", vérifier redirection vers la première question de la section suivante.

**Acceptance Scenarios**:

1. **Given** un élève sur la dernière question d'une partie commune, **When** il clique "Fin de la partie commune", **Then** la partie est marquée complétée et il est redirigé vers la première question de la partie spécifique
2. **Given** toutes les parties filtrées complétées, **When** l'élève marque la dernière, **Then** il est redirigé vers la page du sujet (fin du parcours)

---

### User Story 3 — Marquer un sujet comme terminé (Priority: P1)

En tant qu'élève, je veux déclarer un sujet comme terminé afin de conclure explicitement mon parcours sur ce sujet.

**Why this priority**: Acte final de clôture d'un parcours. Disponible depuis la page "Questions non répondues".

**Independent Test**: Depuis la page des questions non répondues d'un sujet, cliquer "Terminer le sujet", vérifier que le sujet est marqué complété et redirection vers la page sujet.

**Acceptance Scenarios**:

1. **Given** un élève sur la page des questions non répondues, **When** il clique "Terminer le sujet", **Then** le sujet est marqué complété avec un flag `completed=true` dans l'URL de retour

---

### User Story 4 — Révéler la correction d'une question (Priority: P1)

En tant qu'élève, je veux afficher la correction d'une question après avoir tenté de répondre afin de vérifier mon raisonnement.

**Why this priority**: Action la plus fréquente du mode autonome. L'élève révèle la correction après chaque tentative. Aussi la condition implicite pour marquer une question comme "répondue".

**Independent Test**: Sur une page de question, cliquer "Voir la correction", vérifier que le bloc correction s'affiche et que la question est marquée comme répondue.

**Acceptance Scenarios**:

1. **Given** une question non révélée, **When** l'élève clique "Voir la correction", **Then** la correction s'affiche dynamiquement et la question est marquée répondue
2. **Given** une question déjà révélée, **When** l'élève revient dessus, **Then** la correction reste affichée (état persistant)

---

### User Story 5 — Tester une clé API (Priority: P2)

En tant qu'élève, je veux tester si ma clé API (pour le tutorat IA) est valide afin de détecter les erreurs avant d'utiliser le tutorat.

**Why this priority**: Feedback critique pour la configuration. Sans test, l'élève ne découvre l'erreur qu'au premier usage du tuteur.

**Independent Test**: Depuis la page réglages, saisir une clé, cliquer "Tester", vérifier le feedback (valide ou erreur explicite).

**Acceptance Scenarios**:

1. **Given** une clé API valide saisie, **When** l'élève clique "Tester", **Then** un message de succès s'affiche dynamiquement
2. **Given** une clé API invalide, **When** l'élève teste, **Then** un message d'erreur explicite s'affiche sans sauvegarder la clé

---

### User Story 6 — Activer le mode tuteur (Priority: P2)

En tant qu'élève, je veux activer le mode tuteur pour un sujet afin de bénéficier de l'accompagnement IA au lieu du mode autonome simple.

**Why this priority**: Porte d'entrée du mode tuteur IA. Action unique par sujet (après activation, le mode persiste).

**Independent Test**: Depuis la page sujet, cliquer "Activer le tuteur", vérifier que la session passe en mode tuteur et qu'un message confirme l'activation.

**Acceptance Scenarios**:

1. **Given** une session en mode autonome, **When** l'élève clique "Activer le tuteur", **Then** la session passe en mode tuteur avec un état initial vide
2. **Given** une session déjà en mode tuteur, **When** l'élève clique à nouveau, **Then** l'action est idempotente (pas d'effet, pas d'erreur)

---

### Edge Cases

- Que se passe-t-il si un élève tente de modifier sa session sans être authentifié ? L'authentification existante (via `current_student`) rejette la requête.
- Que se passe-t-il si deux onglets cliquent simultanément "Fin de la partie" ? Les méthodes modèle sont idempotentes (`|=` sur les arrays, guards existants).
- Les anciennes URLs (ex: `/:access_code/subjects/:id/set_scope`) sont-elles maintenues ? Non, renommage complet en une PR, 404 standard.
- Pour `test_key` : la clé n'est jamais persistée lors du test (uniquement validation en temps réel).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT permettre à un élève propriétaire de sa session de choisir/modifier son périmètre de travail pour un sujet (commun seulement, spécifique seulement, ou les deux)
- **FR-002**: Système DOIT permettre à un élève de marquer une partie comme terminée et d'être redirigé vers la suite logique du parcours
- **FR-003**: Système DOIT permettre à un élève de marquer un sujet entier comme terminé
- **FR-004**: Système DOIT permettre à un élève de révéler la correction d'une question, ce qui déclenche aussi le marquage "répondu" dans sa progression
- **FR-005**: Système DOIT permettre à un élève de tester la validité de sa clé API sans la persister
- **FR-006**: Système DOIT permettre à un élève d'activer le mode tuteur pour un sujet, créant ou mettant à jour sa session avec `mode: :tutored`
- **FR-007**: Système DOIT préserver l'autorisation actuelle : chaque élève agit uniquement sur sa propre session et dans sa classe
- **FR-008**: Système DOIT exposer chaque action comme une ressource REST dédiée avec sémantique appropriée (update pour scope_selection, create pour les autres)
- **FR-009**: Système DOIT préserver les comportements Turbo Stream actuels (correction révélée, test clé) sans rechargement complet

### Key Entities

- **StudentSession** : modèle existant, support principal de toutes les modifications (progression JSONB, tutor_state JSONB, part_filter, mode, scope_selected)
- **ScopeSelection** : resource conceptuelle pour modifier le périmètre de travail d'une session (update sémantique)
- **Completion** (sur Subject) : resource conceptuelle pour "sujet terminé" (create)
- **PartCompletion** (nested sous Part) : resource conceptuelle pour "partie terminée" (create)
- **Correction** (sur Question) : resource conceptuelle pour "correction révélée" (create, marque aussi "répondue")
- **ApiKeyTest** : resource conceptuelle pour "validation d'une clé API" (create, sans persistance)
- **TutorActivation** : resource conceptuelle pour "passer en mode tuteur" (create idempotent)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les URL exposées suivent le pattern REST :
  - `PATCH /:access_code/subjects/:id/scope_selection`
  - `POST /:access_code/subjects/:id/completion`
  - `POST /:access_code/subjects/:id/parts/:part_id/part_completion`
  - `POST /:access_code/subjects/:subject_id/questions/:id/correction`
  - `POST /:access_code/settings/api_key_test`
  - `POST /:access_code/subjects/:id/tutor_activation`
- **SC-002**: Aucune action `set_scope`, `complete_part`, `complete`, `reveal`, `test_key` ou `activate` ne subsiste dans les controllers student concernés
- **SC-003**: Les feature specs existantes touchant ces 6 actions passent après migration
- **SC-004**: Le flow end-to-end élève (login → choix scope → parcours questions → révélation correction → fin de partie → fin de sujet) reste fonctionnel
- **SC-005**: Le test de clé API retourne un feedback visuel en moins de 3 secondes (limite API externe)
- **SC-006**: La logique métier existante (méthodes `mark_*` sur StudentSession) est préservée et continue d'être testée

## Assumptions

- Le scope `scope "/:access_code", as: :student` est préservé (pas de conversion en namespace Rails)
- Les nouvelles resources sont déclarées avec `controller:` explicite dans routes.rb (pas de `module:` applicable au scope)
- Aucun changement de schéma DB : toutes les transitions modifient des champs JSONB (progression, tutor_state) ou booleans sur `StudentSession`
- Les méthodes modèle existantes (`mark_answered!`, `mark_part_completed!`, `mark_subject_completed!`, `store_spotting!`, etc.) sont préservées telles quelles
- Les services existants (`ValidateStudentApiKey` pour test_key) sont réutilisés tels quels
- `app/javascript/controllers/settings_controller.js` contient une URL construite manuellement en JS pour test_key — elle devra être adaptée à la nouvelle URL
- Les URLs anciennes ne sont pas maintenues (pas de compatibilité arrière, migration en une PR)
- Les 3 actions tuteur (message, verify_spotting, skip_spotting) sont exclues de cette vague et reportées à une vague 5b ultérieure quand le tuteur sera repensé

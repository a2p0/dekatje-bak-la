# Feature Specification: Extraction — Structured Correction en production

**Feature Branch**: `046-extraction-structured-correction`
**Created**: 2026-04-23
**Status**: Draft
**Input**: Intégration production de la structured correction (feature 043) dans le pipeline d'extraction PDF. Approche 2 passes : passe 1 = extraction actuelle inchangée, passe 2 = enrichissement structured_correction par question déclenché automatiquement après PersistExtractedData dans le même job Sidekiq. Dégradation gracieuse si passe 2 échoue. Rétro-enrichissement des subjects existants via script rake.

## Contexte

La feature 043 (PR #57, mergée 2026-04-22) a validé que décomposer la correction en
`input_data` / `final_answers` / `intermediate_steps` / `common_errors` permet au tuteur
LLM de s'auto-discipliner pédagogiquement. Le POC couvre 7 questions (CIME, A.1–A.7)
via un script manuel. Cette feature intègre ce mécanisme directement dans le pipeline
d'extraction automatique, pour que tout nouveau sujet uploadé bénéficie de la structured
correction sans intervention manuelle.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Extraction automatique en 2 passes pour un nouveau sujet (Priority: P1)

Un enseignant uploade un sujet PDF + corrigé. Après extraction, chaque question possède
une `structured_correction` (input_data, final_answers, intermediate_steps, common_errors)
en plus de la `correction_text` brute existante. Le tuteur bénéficie immédiatement de
la structured correction sur ce sujet, sans aucune action supplémentaire.

**Why this priority**: C'est le cœur de la feature. Sans ça, la structured correction
reste un POC one-shot et ne bénéficie qu'aux 7 questions CIME déjà enrichies.

**Independent Test**: Uploader un sujet PDF + corrigé → vérifier en DB que les `answers`
ont un champ `structured_correction` non-null avec les 4 clés après extraction.

**Acceptance Scenarios**:

1. **Given** un sujet non encore extrait uploadé par l'enseignant, **When** le job d'extraction se termine, **Then** chaque `Answer` en DB a un `structured_correction` JSON contenant au minimum `input_data` et `final_answers` (non-vides pour les questions de type calculation ou text).
2. **Given** un sujet extrait, **When** la passe 2 échoue (quota API dépassé, timeout, JSON malformé), **Then** les questions sont quand même persistées avec `correction_text` valide et `structured_correction: null` — l'extraction n'est pas en échec, le job se termine en `done`.
3. **Given** un sujet extrait avec passe 2 réussie, **When** le tuteur démarre une conversation sur une question, **Then** il reçoit les sections structurées dans son contexte (BuildContext utilise structured_correction si présent, sinon fallback correction_text).

---

### User Story 2 — Rétro-enrichissement des subjects existants (Priority: P2)

Les subjects déjà en DB (avec `correction_text` mais sans `structured_correction`)
peuvent être enrichis via une commande rake lancée par le développeur. Chaque subject
est traité question par question. La commande est idempotente : elle ne ré-enrichit pas
les questions déjà enrichies.

**Why this priority**: Sans rétro-enrichissement, seuls les nouveaux sujets bénéficient
de la feature. Les sujets existants (dont CIME complet) restent en legacy.

**Independent Test**: Lancer `rake subjects:enrich_structured_correction` sur un subject
existant → vérifier que toutes ses `answers` ont `structured_correction` non-null.

**Acceptance Scenarios**:

1. **Given** un subject avec toutes ses answers en `structured_correction: null`, **When** la commande rake est lancée, **Then** toutes les answers du subject ont `structured_correction` non-null après exécution.
2. **Given** un subject partiellement enrichi (certaines answers déjà enrichies), **When** la commande rake est relancée, **Then** seules les answers avec `structured_correction: null` sont traitées — pas de doublon, pas d'écrasement.
3. **Given** un subject avec une question dont le corrigé est vide ou très court, **When** l'enrichissement tourne, **Then** la question est skippée (structured_correction reste null) et les autres questions du subject sont enrichies normalement.
4. **Given** une erreur API sur une question individuelle, **When** l'enrichissement tourne, **Then** la question est marquée en erreur (log), les suivantes continuent — la commande ne s'interrompt pas.

---

### User Story 3 — Visibilité de l'état d'enrichissement pour le développeur (Priority: P3)

Lors du rétro-enrichissement, la commande rake affiche une progression lisible :
subject traité, nombre de questions enrichies, nombre skippées, nombre en erreur.

**Why this priority**: Sans feedback, impossible de savoir si la commande s'est bien
déroulée sur de gros jeux de données.

**Independent Test**: Lancer la rake task → vérifier la sortie console.

**Acceptance Scenarios**:

1. **Given** plusieurs subjects en DB, **When** la rake task tourne, **Then** la sortie affiche pour chaque subject : nom, N questions enrichies, N skippées (déjà enrichies), N en erreur.
2. **Given** la rake task terminée, **When** on l'inspecte, **Then** un résumé final indique le total global (N subjects, N questions enrichies, N erreurs).

---

### Edge Cases

- Que se passe-t-il si la passe 2 produit un JSON valide mais avec `final_answers: []` vide pour une question de type `calculation` ? → Stocker quand même, le fallback BuildContext fonctionnera sur `correction_text`.
- Que se passe-t-il si le sujet n'a pas de corrigé attaché (`correction_pdf` absent) ? → La passe 1 échoue déjà aujourd'hui ; la passe 2 ne se déclenche pas.
- Que se passe-t-il si `structured_correction` est déjà non-null pour une question dans le job (re-extraction d'un sujet) ? → La passe 2 écrase l'enrichissement précédent.
- Passe 2 avec réponse LLM tronquée (max_tokens atteint) ? → JSON parse error → la question est skippée, `structured_correction` reste null, log d'avertissement.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le job d'extraction DOIT déclencher automatiquement une passe 2 d'enrichissement après que `PersistExtractedData` a persisté toutes les questions.
- **FR-002**: La passe 2 DOIT enrichir chaque `Answer` en DB avec un champ `structured_correction` JSON contenant : `input_data[]`, `final_answers[]`, `intermediate_steps[]`, `common_errors[]`.
- **FR-003**: La passe 2 DOIT utiliser la même clé API et le même provider que la passe 1 (résolution via `ResolveApiKey`).
- **FR-004**: Si la passe 2 échoue sur une question individuelle (erreur API, JSON invalide), le système DOIT logger l'erreur, passer à la question suivante, et terminer le job en `done` (pas `failed`).
- **FR-005**: Si la passe 2 échoue globalement (provider indisponible), le job DOIT terminer en `done` avec un avertissement dans les logs — les questions sont accessibles avec `correction_text` legacy.
- **FR-006**: `BuildContext` (tuteur) DOIT utiliser `structured_correction` si présent, et se rabattre sur `correction_text` si null (comportement actuel de 043 — déjà implémenté, pas de changement).
- **FR-007**: Une commande rake DOIT permettre d'enrichir tous les subjects existants question par question, de manière idempotente.
- **FR-008**: La commande rake DOIT accepter un paramètre optionnel pour cibler un subject spécifique (`rake subjects:enrich_structured_correction[42]`).
- **FR-009**: La commande rake DOIT afficher une progression lisible et un résumé final.

### Key Entities

- **Answer**: Entité existante. Champ `structured_correction` (JSONB, nullable) déjà migré en 043 — aucune nouvelle migration nécessaire.
- **EnrichStructuredCorrection**: Nouveau service. Reçoit une `Answer`, appelle le LLM avec `correction_text` + `explanation_text` + `context_text`, retourne un Result (ok/error + payload JSON). Ne persiste pas en DB — la persistance est à la charge de l'appelant.
- **EnrichAllAnswers**: Nouveau service orchestrateur. Itère toutes les answers d'un subject, appelle `EnrichStructuredCorrection` par question, persiste si succès, logue si erreur. Ne lève jamais d'exception. Réutilisé par le job Sidekiq et la rake task.
- **ExtractQuestionsJob** (Sidekiq): Orchestrateur existant. Appelle `EnrichAllAnswers` (qui orchestre `EnrichStructuredCorrection`) après `PersistExtractedData`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tout nouveau sujet uploadé après déploiement a 100% de ses questions enrichies avec `structured_correction` non-null (hors cas de dégradation gracieuse documentés).
- **SC-002**: La durée totale d'extraction (passe 1 + passe 2) ne dépasse pas le double de la durée actuelle (passe 1 seule) pour un sujet standard (~20 questions).
- **SC-003**: Le rétro-enrichissement d'un subject complet (7–20 questions) via rake se termine sans interruption et affiche un résumé lisible.
- **SC-004**: Si la passe 2 échoue, le tuteur continue de fonctionner normalement sur le subject concerné (fallback legacy transparent pour l'élève).
- **SC-005**: La rake task est idempotente : la relancer deux fois sur le même subject ne modifie pas les answers déjà enrichies et n'appelle pas le LLM inutilement.

## Assumptions

- Le champ `structured_correction` (JSONB nullable) existe déjà sur la table `answers` — migration 043 mergée. Aucune nouvelle migration nécessaire.
- `BuildContext` utilise déjà `structured_correction` si présent (043 mergé) — aucun changement côté tuteur.
- La passe 2 appelle le LLM question par question (N appels séquentiels), pas en batch. Coût estimé : ~$0.05–0.10 par sujet complet.
- La passe 2 utilise `correction_text` + `explanation_text` + `context_text` déjà en DB comme input — pas besoin de relire le PDF.
- La rake task s'exécute en environnement développement/production par le développeur, pas en CI.
- Le provider utilisé pour la passe 2 est le même que pour la passe 1 (clé enseignant ou fallback serveur `ANTHROPIC_API_KEY`).
- Les sujets sans corrigé attaché (`correction_pdf` absent) ne sont pas concernés — la passe 1 échoue déjà dans ce cas.
- Les questions de type `dr_reference` ou `completion` peuvent produire une `structured_correction` avec `final_answers: []` — c'est acceptable.

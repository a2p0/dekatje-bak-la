# Feature Specification: Metrics structurelles déterministes pour le tuning du prompt tuteur

**Feature Branch**: `039-structural-metrics`
**Created**: 2026-04-16
**Status**: Draft
**Input**: User description: "Ajouter des metrics structurelles déterministes au service TutorSimulation::StructuralMetrics pour tester des hypothèses de tuning du prompt tuteur sans dépendre du juge LLM (bruit ±0.50 pt). Ajouter 4 metrics: first_turn_with_transition (H1), action_verb_ratio_guiding (H2), dt_dr_leak_count_non_spotting, short_message_ratio. Ajouter un guard SKIP_JUDGE=1 dans Runner. Non-scope: pas de changement du prompt, pas de migration DB."

## Contexte

La branche parente `038-tutor-prompt-tuning` a conclu que le tuning du prompt tuteur
via le jugement LLM est **inexploitable sur des sims réduites** : le bruit du juge
atteint ±0.50 pt sur n=6 conversations identiques (cf. `specs/038-tutor-prompt-tuning/hypotheses.md`).
Deux hypothèses (H1 : transition avant texte, H2 : verbe+objet en guiding) ont été
revertées prématurément sur la base de deltas qui tombent dans le bruit de mesure.

Ce feature livre **un instrument de mesure** : des métriques calculées sur la
transcription de chaque conversation, sans appel LLM, avec une variance
quasi-nulle (σ ≈ 0.01). Le tuning lui-même n'est PAS dans ce scope : on livre
d'abord la règle, on mesure ensuite.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Mesurer H1 (transition avant texte) sans juge (Priority: P1)

Le développeur (enseignant-auteur du projet) veut savoir, après une sim CI,
à quel tour de conversation le tuteur a invoqué sa **première transition** pour
sortir de la phase `idle`. L'hypothèse H1 prédit que forcer la transition
**avant** toute émission de texte fait chuter ce tour à 1 pour toutes les
conversations ; la baseline attend un tour plus tardif.

**Why this priority**: C'est la raison d'être de ce feature. Sans cette
métrique, H1 ne peut être testée que via le juge LLM (σ ≈ 0.5) qui masque le
signal réel. Avec cette métrique (σ ≈ 0.01), un delta de 1 tour est
statistiquement incontestable dès n=5.

**Independent Test**: Lancer deux sims (baseline et H1 appliquée) avec les
mêmes profils, et vérifier que le rapport `report.md` affiche
`first_turn_with_transition` pour chaque conversation, et que sa moyenne
diminue mesurablement dans la variante H1.

**Acceptance Scenarios**:

1. **Given** une conversation simulée qui a appelé `transition(phase: "greeting")` au 1er tour assistant, **When** le rapport est généré, **Then** `first_turn_with_transition` vaut 1.
2. **Given** une conversation simulée qui a appelé `transition` seulement au 3e tour assistant, **When** le rapport est généré, **Then** `first_turn_with_transition` vaut 3.
3. **Given** une conversation simulée qui n'a jamais appelé `transition` (reste en idle), **When** le rapport est généré, **Then** `first_turn_with_transition` vaut `nil` (ou un marqueur "jamais").

---

### User Story 2 — Mesurer H2 (verbe+objet en guiding) sans juge (Priority: P1)

Le développeur veut savoir quel pourcentage des messages que le tuteur émet
**en phase guiding** commence par un verbe d'action impératif (Identifie,
Repère, Cite, Relève, Compare, Calcule) — conformément à la règle H2
explorée dans `specs/038-tutor-prompt-tuning/`.

**Why this priority**: C'est la seconde hypothèse centrale du tuning. Sans
cette métrique, H2 n'est mesurable que par un juge qualitatif bruité. La
liste des verbes est fermée et publique dans le prompt H2, ce qui rend la
regex déterministe et simple à valider.

**Independent Test**: Lancer deux sims (baseline et H2 appliquée) et
vérifier que `action_verb_ratio_guiding` affiché dans le rapport augmente
nettement dans la variante H2 (cible : de ~0.20 baseline à ≥0.70 H2).

**Acceptance Scenarios**:

1. **Given** une conversation en phase guiding avec 3 messages tuteur dont 2 commencent par "Identifie" ou "Calcule", **When** la métrique est calculée, **Then** `action_verb_ratio_guiding` vaut 0.67.
2. **Given** une conversation qui n'a jamais atteint la phase guiding, **When** la métrique est calculée, **Then** `action_verb_ratio_guiding` vaut `nil` (pas de division par zéro).
3. **Given** un message commençant par "  identifie " (minuscule + espaces parasites), **When** la métrique est calculée, **Then** le message est compté comme action-verb (matching case-insensitive + trim).
4. **Given** un message commençant par "Identifie," ou "Identifie." (verbe suivi de ponctuation), **When** la métrique est calculée, **Then** le message est compté comme action-verb (strip ponctuation finale du 1er mot avant comparaison).

---

### User Story 3 — Économiser le coût du juge pendant les itérations (Priority: P1)

Le développeur lance plusieurs sims par jour pour comparer des variantes de
prompt. Lorsque les metrics structurelles suffisent au verdict, il veut
désactiver le juge LLM pour **diviser le coût sim par ~2** (le juge consomme
~50% du budget tokens selon les mesures de 038).

**Why this priority**: Sans ce guard, itérer sur 3 hypothèses coûte ~$1.80
(sims complètes avec juge). Avec le guard, le même cycle coûte ~$0.90,
laissant de la marge sous le cap SC-007 ($2) pour une sim de validation
finale qui, elle, réactive le juge.

**Independent Test**: Exécuter `SKIP_JUDGE=1 rake tutor:simulate[...]` et
vérifier que le `raw.json` produit contient un marqueur explicite
"juge désactivé" dans le bloc évaluation, et qu'aucun appel n'a été fait
au client juge (vérifiable via mock en spec).

**Acceptance Scenarios**:

1. **Given** `SKIP_JUDGE=1` dans l'environnement, **When** le Runner exécute une simulation, **Then** le client juge n'est jamais appelé et le champ `evaluation` du résultat contient un marqueur `"skipped" => true`.
2. **Given** `SKIP_JUDGE` absent (ou `=0`), **When** le Runner exécute une simulation, **Then** le client juge est appelé comme avant (rétrocompatibilité).
3. **Given** une sim avec `SKIP_JUDGE=1`, **When** le rapport Markdown est généré, **Then** le bloc "Évaluation qualitative" est remplacé par un message lisible "Juge désactivé (SKIP_JUDGE=1)" au lieu d'une erreur ou d'un tableau vide.

---

### User Story 4 — Contrôler les contournements du prompt (Priority: P2)

Le développeur veut un indicateur qui **monitoring** : est-ce que le tuteur
cite `DT\d+` ou `DR\d+` ailleurs qu'en phase spotting (leak vers l'élève) ?
Et est-ce que la règle des 60 mots par message tient ?

**Why this priority**: Ces métriques ne sont pas centrales pour H1/H2 mais
détectent les régressions silencieuses sur des règles déjà établies. Elles
sont quasi-gratuites à ajouter une fois qu'on touche au service.

**Independent Test**: Lancer une sim baseline et vérifier que les deux
nouvelles métriques apparaissent dans le rapport avec des valeurs plausibles
(leak count bas, short_message_ratio ≥ 0.7).

**Acceptance Scenarios**:

1. **Given** une conversation contenant 2 messages en phase guiding mentionnant "DT1", **When** la métrique est calculée, **Then** `dt_dr_leak_count_non_spotting` vaut 2.
2. **Given** une conversation de 5 messages tuteur dont 4 font ≤60 mots, **When** la métrique est calculée, **Then** `short_message_ratio` vaut 0.80.

---

### Edge Cases

- **Conversation sans message assistant** (ex: erreur LLM au 1er tour) : les métriques doivent retourner des valeurs sentinelles stables sans lever d'exception. Convention :
  - `short_message_ratio == 0.0` (pas `nil`) pour permettre une agrégation cohérente dans le résumé global — distinguer "aucun message observé" de "phase absente" n'apporte rien pour cette métrique.
  - `action_verb_ratio_guiding == nil` (car distinguer "guiding jamais atteint" de "0 verbes en guiding" change la lecture de H2).
  - `first_turn_with_transition == nil` (pas de tour observé).
  - `dt_dr_leak_count_non_spotting == 0` (pas de message → pas de leak).
- **Phase jamais atteinte** : si la phase guiding n'est jamais atteinte, `action_verb_ratio_guiding` vaut `nil`, pas `0.0` (distinguer "phase absente" de "0 verbes").
- **Historique de phases indisponible** : le `TutorState` courant ne garde pas l'historique des phases par message. On capture cet historique pendant la sim via le `Runner` (tableau `phase_per_turn`), pas via une migration DB.
- **Rétrocompatibilité spec existant** : la signature `StructuralMetrics.compute(conversation:)` doit continuer à fonctionner sans second argument (retourne alors les nouvelles métriques nil-safely).
- **Mock du judge_client** : avec `SKIP_JUDGE=1`, le spec RSpec doit vérifier via `expect(judge_client).not_to receive(:complete)` (ou équivalent) qu'aucun appel n'a eu lieu.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le service de calcul de métriques structurelles DOIT exposer une métrique `first_turn_with_transition` indiquant le rang (1-indexé) du tour assistant où la première transition de phase hors de `idle` s'est produite, ou `nil` si aucune transition n'a eu lieu.
- **FR-002**: Le service DOIT exposer une métrique `action_verb_ratio_guiding` indiquant le ratio (0.0 à 1.0 ou `nil`) des messages tuteur émis **en phase guiding** dont le premier mot (après trim, lowercase, et strip de la ponctuation finale éventuelle) appartient à la liste fermée : `Identifie, Repère, Cite, Relève, Compare, Calcule`.
- **FR-003**: Le service DOIT exposer une métrique `dt_dr_leak_count_non_spotting` indiquant le nombre de messages tuteur mentionnant `DT\d+` ou `DR\d+` dans une phase autre que `spotting`. Quand `phase_per_turn` n'est pas fourni (appel rétrocompat), la métrique compte TOUS les messages tuteur qui mentionnent `DT\d+` ou `DR\d+` — c'est le cas "diagnostic sans info de phase" : on préfère signaler tous les candidats à leak plutôt que rien.
- **FR-004**: Le service DOIT exposer une métrique `short_message_ratio` indiquant le ratio des messages tuteur dont la longueur en mots est ≤ 60 (règle déjà présente dans le prompt).
- **FR-005**: Les nouvelles métriques DOIVENT être calculées sans appel LLM et avec une variance < 0.05 sur runs identiques.
- **FR-006**: Le `Runner` du système de simulation DOIT capturer l'historique de la phase à chaque tour assistant (tableau `phase_per_turn`) et le rendre disponible au service de métriques pour calcul de FR-001.
- **FR-007**: Le `Runner` DOIT exposer un guard activé par la variable d'environnement `SKIP_JUDGE=1` qui désactive tout appel au client juge sans casser le flot d'exécution.
- **FR-008**: Avec `SKIP_JUDGE=1`, le champ `evaluation` du résultat par profil DOIT contenir un marqueur explicite (par ex. `{ "skipped" => true }`) pour différencier ce cas d'une erreur juge.
- **FR-009**: Le générateur de rapport Markdown DOIT rendre les 4 nouvelles métriques dans la section "Métriques structurelles" de chaque profil ET dans le "Résumé global" (moyenne/somme selon la nature de la métrique).
- **FR-010**: Le générateur de rapport DOIT afficher un message lisible "Juge désactivé (SKIP_JUDGE=1)" à la place du tableau qualitatif quand `evaluation["skipped"] == true`.
- **FR-011**: La signature publique `TutorSimulation::StructuralMetrics.compute(conversation:)` DOIT rester rétrocompatible : appelable sans nouvel argument, les 4 nouvelles métriques retournent alors des valeurs sentinelles cohérentes (FR-001 → `nil`, FR-002 → `nil`, FR-003 → compté quand même, FR-004 → compté quand même).
- **FR-012**: Chaque nouvelle métrique DOIT être couverte par au moins un spec RSpec positif et un spec d'edge case (phase absente, message vide, liste vide).
- **FR-013**: Le guard `SKIP_JUDGE=1` DOIT être couvert par un spec RSpec qui vérifie via double/mock que `judge_client` n'est pas invoqué.

### Key Entities *(include if feature involves data)*

- **StructuralMetrics result** : un hash retourné par `compute`, contenant les 6 métriques existantes (`phase_rank`, `avg_message_length_words`, `open_question_ratio`, `regex_intercepts`, `hints_used`, `message_count_*`) **plus** les 4 nouvelles (`first_turn_with_transition`, `action_verb_ratio_guiding`, `dt_dr_leak_count_non_spotting`, `short_message_ratio`). Ce hash est sérialisé dans le `raw.json` produit par le Runner, consommé par le script d'agrégation et par le `ReportGenerator`.
- **phase_per_turn** : un tableau de chaînes (phases nommées) capturé par le Runner, indexé par rang de tour assistant (1-indexé). Exemple : `["greeting", "reading", "spotting", "guiding", "guiding"]`. Utilisé exclusivement pour calculer FR-001, non persisté en base.
- **SKIP_JUDGE marker** : un hash `{ "skipped" => true }` inséré à la place du hash d'évaluation du juge dans le résultat de profil. Discriminant du cas erreur juge (qui utilise déjà `{ "error" => ... }`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Les 4 nouvelles métriques sont calculables sur n'importe quelle conversation de simulation en moins de 50 ms (contrainte : zéro appel réseau, calcul Ruby local).
- **SC-002**: La variance des 4 nouvelles métriques sur **deux runs identiques** (même prompt, même seed, 6 conversations chacun) est < 0.05 (vs. ±0.50 observé pour les scores du juge sur le même échantillon).
- **SC-003**: Avec `SKIP_JUDGE=1`, le coût d'une sim complète (15 conversations, 5 profils × 3 questions) chute d'au moins 40% mesuré en tokens OpenRouter consommés.
- **SC-004**: La signature existante `StructuralMetrics.compute(conversation:)` continue à passer tous les specs existants sans modification (rétrocompatibilité stricte).
- **SC-005**: Le rapport `report.md` généré inclut les 4 nouvelles métriques par profil ET en résumé global sans perte de lisibilité (validation manuelle : un rapport est lisible de bout en bout par un humain non initié au code).
- **SC-006**: Une sim réelle n=2 (1 profil × 2 questions) tournée en CI avec `SKIP_JUDGE=1` produit un `raw.json` valide sans appel au juge (vérifiable dans les logs CI : aucune ligne "Évaluation…").

## Assumptions

- Le développeur solo est l'unique utilisateur de ce feature ; il connaît le code de `TutorSimulation` et la convention speckit.
- Les metrics vivent dans `app/services/tutor_simulation/structural_metrics.rb` (emplacement existant, code Ruby pur).
- Le guard `SKIP_JUDGE` est un outil de développement interne, jamais utilisé en production (pas de chemin de prod impacté).
- La liste des verbes de H2 est fermée et figée (`Identifie, Repère, Cite, Relève, Compare, Calcule`) ; si une future hypothèse H2' change cette liste, ce sera un nouveau feature speckit.
- La capture de `phase_per_turn` se fait in-memory dans le Runner pendant la sim ; aucune migration DB ni persistance nouvelle.
- Le comportement `Tutor::ProcessMessage` en production reste strictement inchangé.
- La rétrocompatibilité de la signature `compute(conversation:)` est atteinte en rendant `phase_per_turn:` un kwarg optionnel avec défaut `nil`, et en dégradant FR-001 à `nil` quand l'historique n'est pas fourni.

## Dependencies

- S'appuie sur `TutorSimulation::Runner`, `TutorSimulation::StructuralMetrics`, `TutorSimulation::ReportGenerator` (existants).
- S'appuie sur `Tutor::ApplyToolCalls::TRANSITION_MATRIX` (lecture seule, pour la liste des phases valides).
- Consomme `Conversation#tutor_state.current_phase` et `Message.role` / `Message.content` (lecture seule).
- **Aucune dépendance** sur un changement du prompt tuteur (`Tutor::BuildContext`).

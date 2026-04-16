# Feature Specification: Câblage des outils du tuteur au LLM

**Feature Branch**: `037-tutor-wire-tools`
**Created**: 2026-04-15
**Status**: Draft
**Input**: User description: "Câbler les 4 outils du tuteur (transition, update_learner_model, request_hint, evaluate_spotting) à RubyLLM via chat.with_tools. Actuellement le LLM voit les outils listés en texte dans le prompt système mais ne peut pas les appeler physiquement — la sim du 2026-04-15 montre que la phase finale du tuteur reste à 0/7 car chunk.tool_calls est toujours vide, le tuteur reste bloqué en phase idle et répond directement sans suivre le workflow greeting→reading→spotting→guiding→validating→feedback."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Le tuteur suit le workflow pédagogique en phases (Priority: P1)

Un élève démarre une conversation avec le tuteur sur une question. Le tuteur doit
suivre le workflow pédagogique structuré : accueil (greeting), lecture guidée
(reading), repérage des données (spotting), guidage (guiding), validation
(validating), feedback (feedback), puis clôture (ended). À chaque transition de
phase, l'état interne du tuteur doit effectivement changer et être persisté.

**Why this priority** : c'est l'objectif premier du tuteur. Sans transitions
de phase effectives, le tuteur court-circuite le parcours pédagogique et
délivre les réponses prématurément, ce qui est incompatible avec la règle
absolue "ne jamais donner la réponse directement".

**Independent Test** : lancer une conversation, envoyer des messages successifs,
et vérifier que la phase courante progresse selon la matrice de transitions
(`greeting → reading → spotting → guiding → validating → feedback → ended`) —
avec confirmation via simulation que la phase finale moyenne atteint un seuil
cible (voir SC-001).

**Acceptance Scenarios** :

1. **Given** une conversation en phase initiale `idle` avec aucun message
   assistant,
   **When** l'élève envoie son premier message,
   **Then** le tuteur effectue une transition `idle → greeting` puis
   `greeting → reading`.
2. **Given** une conversation en phase `reading`,
   **When** l'élève indique qu'il a lu la question,
   **Then** le tuteur transite vers `spotting` en associant la question courante.
3. **Given** une conversation où l'élève a donné une réponse finale,
   **When** le tuteur évalue la réponse,
   **Then** la conversation transite vers `validating` puis `feedback` puis `ended`.

---

### User Story 2 — Le tuteur met à jour son modèle de l'élève (Priority: P2)

À mesure que l'élève interagit, le tuteur identifie les concepts maîtrisés,
les concepts à revoir, et ajuste un niveau de découragement (0-3) en fonction
du ton et des difficultés exprimées. Ces mises à jour doivent être persistées
pour adapter la suite de la conversation.

**Why this priority** : l'adaptation pédagogique est un différenciateur clé
mais reste inopérant tant que les transitions de phase (US1) ne fonctionnent
pas. Sans US1, le modèle apprenant reste vide.

**Independent Test** : dans une conversation jouée, inspecter après N tours
que les concepts maîtrisés, concepts à revoir et niveau de découragement
ne sont plus leurs valeurs initiales.

**Acceptance Scenarios** :

1. **Given** un élève qui démontre la maîtrise d'un concept,
   **When** le tuteur identifie ce concept,
   **Then** la liste des concepts maîtrisés se voit ajouter le concept sans doublon.
2. **Given** un élève qui exprime un doute ou une erreur,
   **When** le tuteur met à jour le modèle avec un delta de découragement de 1,
   **Then** le niveau de découragement augmente de 1 (plafonné à 3 maximum).

---

### User Story 3 — Le tuteur propose des indices progressifs (Priority: P2)

En phase de guidage ou de repérage, le tuteur peut proposer des indices de
niveau croissant (1 à 5). Chaque indice doit suivre strictement le précédent :
pas de saut de niveau, pas de doublon, plafonné à 5.

**Why this priority** : essentiel à la pédagogie socratique mais dépend de
US1 (phase `guiding` atteignable) et US2 (contexte élève disponible).

**Independent Test** : dans une conversation en phase `guiding`, compter le
nombre d'indices demandés et vérifier qu'il correspond à la progression
monotone 1, 2, 3... avec refus de tout saut ou dépassement.

**Acceptance Scenarios** :

1. **Given** une question en phase `guiding` sans indice donné,
   **When** le tuteur demande un indice de niveau 1,
   **Then** le compteur d'indices utilisés de la question passe à 1.
2. **Given** une question avec 2 indices déjà donnés,
   **When** le tuteur demande un indice de niveau 4 (saut),
   **Then** l'opération est refusée et l'état reste inchangé.

---

### User Story 4 — Le tuteur évalue le repérage des données (Priority: P2)

En phase `spotting`, l'élève indique en langage libre où se trouvent les
données utiles. Le tuteur évalue sa réponse et décide : succès (passage au
guidage), échec (relance plus directive), ou révélation forcée après 3 échecs.

**Why this priority** : bloc spécifique BAC STI2D, dépendant de US1 (phase
`spotting` atteignable).

**Independent Test** : dans une conversation en phase `spotting`, vérifier
que trois types de résultats (succès, échec, révélation forcée) sont
distingués et que les deux premiers (succès et révélation forcée) déclenchent
la transition vers `guiding`.

**Acceptance Scenarios** :

1. **Given** une conversation en phase `spotting`,
   **When** l'élève identifie correctement la source des données,
   **Then** le tuteur évalue un succès et transite vers `guiding`.
2. **Given** une conversation en phase `spotting` après 3 échecs,
   **When** le tuteur déclenche une révélation forcée,
   **Then** les indices de localisation sont révélés et la phase passe à `guiding`.

---

### Edge Cases

- **Transition interdite** : si le LLM tente une transition non autorisée par
  la matrice (ex. `greeting → guiding`), le serveur refuse et l'état reste
  inchangé ; une trace d'erreur technique est conservée, non exposée à
  l'élève.
- **Argument requis manquant** : si un argument obligatoire est absent
  (ex. `transition` sans `phase`), l'appel est ignoré côté serveur.
- **Outil inconnu** : si le LLM invente un outil non déclaré, l'appel est
  silencieusement ignoré.
- **Aucun appel d'outil dans la réponse** : la conversation continue mais
  l'état du tuteur reste identique (toléré, mais flagué dans les métriques
  qualité).
- **Niveau d'indice hors bornes** : une demande d'indice niveau 6+ est refusée.
- **Argument mal typé** : si le LLM envoie des types incorrects (ex. un
  niveau textuel au lieu d'un entier), l'appel est coercé si possible ou
  ignoré.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** : Le système MUST exposer au LLM, lors de chaque appel de
  conversation, la capacité d'invoquer 4 outils nommés : `transition`,
  `update_learner_model`, `request_hint`, `evaluate_spotting`.
- **FR-002** : Chaque outil MUST être décrit avec un schéma structuré
  (nom, description, paramètres typés, paramètres requis/optionnels) compris
  nativement par le LLM — et non uniquement mentionné en texte libre dans
  le prompt.
- **FR-003** : Lorsque le LLM invoque un outil, le système MUST capturer
  l'appel (nom + arguments) et l'appliquer à l'état de la conversation
  via le pipeline de traitement existant.
- **FR-004** : Le prompt système MUST instruire explicitement le LLM
  d'appeler les outils aux moments adéquats (notamment `transition` à
  chaque changement de phase) plutôt que de se contenter d'une narration.
- **FR-005** : Les garde-fous serveur existants (matrice de transitions,
  progression monotone des indices, plafonnement du découragement,
  restriction de l'évaluation du repérage à la phase `spotting`) MUST
  rester appliqués après le câblage, indépendamment de ce que propose
  le LLM.
- **FR-006** : En cas d'erreur d'invocation (argument manquant, transition
  interdite, outil inconnu), le système MUST conserver l'état inchangé
  et ne MUST PAS exposer l'erreur brute à l'élève.
- **FR-007** : Les outils MUST être câblés pour tous les fournisseurs LLM
  supportés (Anthropic, OpenRouter, OpenAI, Google) via l'abstraction
  LLM unifiée utilisée aujourd'hui.
- **FR-008** : Le câblage NE DOIT PAS briser le streaming token-par-token
  existant : les messages continuent de s'afficher progressivement côté
  élève pendant que les appels d'outils sont capturés.
- **FR-009** : Le système MUST autoriser la première transition depuis
  la phase initiale `idle` vers `greeting`. Aujourd'hui la matrice des
  transitions autorisées ne contient pas `idle` comme phase source, ce
  qui empêcherait toute sortie de l'état initial même après câblage des
  outils.

### Key Entities

- **Outil tuteur** : capacité structurée que le LLM peut invoquer,
  caractérisée par un nom, une description et une signature d'arguments.
  Les 4 outils concernés :
  - `transition` (phase cible, identifiant de question optionnel)
  - `update_learner_model` (concept maîtrisé, concept à revoir, delta
    découragement)
  - `request_hint` (niveau 1-5)
  - `evaluate_spotting` (résultat : succès / échec / révélation forcée)
- **État du tuteur** : état pédagogique persisté par conversation (phase
  courante, question courante, concepts maîtrisés/à revoir, découragement,
  état par question), modifié par l'application des appels d'outils.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : Lors d'une simulation tuteur (5 profils d'élèves × 3 questions
  × 5 tours), le score moyen "phase finale atteinte" passe de **0 / 7**
  (baseline sim 2026-04-15) à **au moins 4 / 7**.
- **SC-002** : Dans la même simulation, le score "Respect du process"
  (échelle 1-5) passe de **3.1** à **au moins 4.0**.
- **SC-003** : Dans la même simulation, le score "Non-divulgation"
  passe de **3.5** à **au moins 4.2** (plus de phase = moins de fuite de
  valeurs chiffrées).
- **SC-004** : Dans au moins **80 %** des conversations de simulation,
  le tuteur invoque au moins un outil `transition` dans les 3 premiers
  tours (preuve que les outils sont bien atteignables depuis le LLM).
- **SC-005** : Aucune régression sur la suite de tests existante : la CI
  GitHub Actions reste verte.

## Assumptions

- Le pipeline existant de traitement des messages tuteur (validation,
  construction du contexte, appel LLM, parsing des appels d'outils,
  application, mise à jour d'état, diffusion) n'est **pas** remis en cause.
  Seules l'étape d'appel LLM et la construction du prompt système sont
  modifiées.
- L'abstraction LLM côté serveur supporte nativement la déclaration d'outils
  (fonction calling) pour tous les providers activés.
- Les schémas d'arguments des 4 outils sont dérivés du code existant
  d'application des appels d'outils (contrat implicite actuel) et sont
  stables dans le cadre de cette feature.
- La simulation `rake tutor:simulate` est la source de vérité pour mesurer
  les gains (SC-001 à SC-004). Elle peut être lancée en CI via le workflow
  manuel existant.
- Aucune migration de base de données n'est requise : l'état du tuteur
  et la conversation disposent déjà de tous les champs nécessaires.
- Le tuning fin du prompt pédagogique reste **hors scope** ; l'objectif
  est uniquement de rendre les outils appelables et d'ajouter une
  instruction minimale d'usage.
- Le comparatif entre modèles LLM pour la tâche tuteur reste **hors scope**.

# Feature Specification: Tuning itératif du prompt tuteur

**Feature Branch**: `038-tutor-prompt-tuning`
**Created**: 2026-04-16
**Status**: Draft
**Input**: Améliorer les scores pédagogiques du tuteur (guidage, process, focalisation) via tuning itératif du prompt système, en gardant la config LLM validée (Haiku 4.5 tuteur + Sonnet 4.6 juge).

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Le tuteur guide avec des questions précises (Priority: P1)

Un élève en phase `guiding` pose une question ouverte ou évasive. Le tuteur
doit lui répondre par **une question ciblée** qui oriente l'attention vers
un élément précis du document ou de l'énoncé, plutôt que par une relance
générale.

**Why this priority** : c'est le critère qui a le plus besoin de progresser
(guidage 3.00 → cible ≥4.0). Une question précise produit un apprentissage
effectif ; une question vague laisse l'élève sans direction.

**Dépendance d'ordonnancement** : l'observation du guidage nécessite que
la phase `guiding` soit effectivement atteinte, ce qui dépend de US2
(Process). US2 doit donc être implémentée avant US1 — c'est un choix
d'exécution, pas une différence de priorité.

**Independent Test** : sur 5 conversations en phase `guiding`, vérifier
qu'au moins 4 sur 5 des relances du tuteur commencent par un verbe d'action
orienté (identifier, repérer, calculer, comparer) et ciblent un objet
nommé — pas "Qu'est-ce que tu en penses ?".

**Acceptance Scenarios** :

1. **Given** l'élève demande "Tu peux m'aider ?",
   **When** le tuteur est en phase `guiding` avec une question à résoudre,
   **Then** la prochaine réponse du tuteur pose une question ciblée sur
   un élément du document (ex. "Dans le DTS1, quelle valeur correspond
   à la conductivité de la laine de roche ?"), pas une relance générique.
2. **Given** l'élève a identifié un élément incorrect,
   **When** le tuteur évalue sa réponse,
   **Then** le tuteur recadre en demandant de vérifier une source précise
   plutôt qu'en donnant la bonne réponse.

---

### User Story 2 — Le tuteur respecte le process en appelant transition tôt (Priority: P1)

Dès le premier message de l'élève, le tuteur doit enregistrer la
transition `idle → greeting`, puis enchaîner rapidement sur `reading`
et `spotting`. Les transitions tardives ou omises font baisser le score
"Respect du process".

**Why this priority** : score actuel 2.53/5, cible ≥3.5. Le workflow
phase par phase est la promesse pédagogique du tuteur.

**Independent Test** : sur 10 conversations, mesurer le tour moyen
auquel la phase `spotting` est atteinte. Cible : ≤ tour 2 en moyenne.

**Acceptance Scenarios** :

1. **Given** une nouvelle conversation (phase `idle`),
   **When** le tuteur reçoit le premier message,
   **Then** il appelle `transition(phase: "greeting")` **avant** de
   formuler sa réponse textuelle.
2. **Given** le tuteur a salué (phase `greeting`),
   **When** il reçoit le prochain message,
   **Then** il enchaîne `greeting → reading → spotting` sans s'attarder
   inutilement en `reading`.

---

### User Story 3 — Le tuteur reste focalisé sur la question courante (Priority: P2)

Quand l'élève dérive (question hors sujet, confusion de question), le
tuteur recentre explicitement vers la question courante en mentionnant
son numéro et son objectif.

**Why this priority** : focalisation 3.40 → cible ≥4.0. Évite la dilution
pédagogique observée (ex. l'élève parle de matériaux non présents dans
le DTS1 et le tuteur suit).

**Independent Test** : sur 5 conversations, vérifier qu'en cas de dérive
explicite de l'élève, le tuteur recadre dans son message suivant en
citant la question (numéro ou objet).

**Acceptance Scenarios** :

1. **Given** l'élève mentionne des matériaux non pertinents pour la
   question,
   **When** le tuteur répond,
   **Then** il ne valide pas la dérive et redirige explicitement vers
   l'objet de la question courante.

---

### Edge Cases

- **Élève hors sujet total** (profil `eleve_hors_sujet`) : le tuteur
  recadre au 1er message, n'entre pas dans la discussion parasite.
- **Élève qui demande directement la réponse** : le tuteur refuse
  poliment et propose un indice gradué (niveau 1 d'abord).
- **5 tours épuisés sans phase `guiding` atteinte** : comportement
  actuel acceptable (limite sim), pas de scope de changement.
- **Non-régression non-divulgation** : aucun des nouveaux prompts ne
  doit faire fuiter de valeurs chiffrées issues de `correction_text`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** : Le système MUST formuler, en phase `guiding`, des
  questions orientées vers un élément nommé du document ou de l'énoncé
  plutôt que des relances génériques.
- **FR-002** : Le système MUST invoquer l'outil `transition` avec
  `phase: "greeting"` comme **premier acte** du premier appel LLM de
  toute nouvelle conversation (sortie d'`idle`), avant toute émission
  de texte.
- **FR-003** : Le système MUST recentrer explicitement l'élève sur la
  question courante (par son numéro ou son objectif) lorsqu'une dérive
  est détectée dans l'entrée élève.
- **FR-004** : Le système MUST conserver le score moyen de
  non-divulgation au-dessus de 4.5/5 après tuning (non-régression).
- **FR-005** : Le système MUST conserver le score moyen de
  bienveillance au-dessus de 4.0/5 après tuning (non-régression).
- **FR-006** : Le tuning MUST être validé par itérations courtes
  (sim réduite, ~2 conversations) avant tout run complet, pour
  contenir le coût total sous un budget raisonnable.

### Key Entities

- **Prompt système tuteur** : texte structuré en sections (règles
  pédagogiques, contexte sujet, utilisation des outils, phase active).
  C'est la seule entité modifiée par cette feature.
- **Run de simulation réduite** : 1 question × 2 profils × 5 tours
  = 2 conversations. Utilisé pour l'itération rapide.
- **Run de simulation complète** : 3 questions × 5 profils × 5 tours
  = 15 conversations. Utilisé pour validation finale.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : Score moyen **Guidage progressif** passe de **3.00/5** à
  **≥ 4.0/5** sur un run complet (15 conversations, juge Sonnet 4.6).
- **SC-002** : Score moyen **Respect du process** passe de **2.53/5**
  à **≥ 3.5/5** sur le même run.
- **SC-003** : Score moyen **Focalisation** passe de **3.40/5** à
  **≥ 4.0/5**.
- **SC-004** : Score moyen **Non-divulgation** reste **≥ 4.5/5**
  (non-régression).
- **SC-005** : Score moyen **Bienveillance** reste **≥ 4.0/5**
  (non-régression).
- **SC-006** : **Phase finale moyenne** (rang /7) reste **≥ 3.0** (pas
  de régression sur la capacité à progresser dans le workflow).
- **SC-007** : Coût total du tuning (toutes itérations + run complet
  final) reste **≤ $2** (limite de budget pour valider la méthode).
- **SC-008** : Aucune régression sur la suite de tests existante
  (CI GitHub Actions verte).

## Assumptions

- La config LLM est **figée** : Haiku 4.5 en tuteur, Haiku 4.5 en élève
  simulé, Sonnet 4.6 en juge. Tout changement de modèle est hors scope.
- Le pipeline tuteur est opérationnel (PR #49 mergée, tools câblés).
- La baseline de référence est le run `24503225082` du 2026-04-16
  (Haiku/Haiku/Sonnet) : rank 3.00, non-div 4.53, guid 3.00,
  bienv 4.00, focal 3.40, process 2.53.
- L'atteinte des cibles peut nécessiter 3 à 5 itérations de prompt,
  chacune validée par une sim réduite (~$0.05).
- La sim complète finale (~$0.60) ne sera lancée qu'une fois les
  itérations réduites jugées concluantes.
- Le coût total prévu reste sous $2 — si budget dépassé sans atteindre
  toutes les cibles, documenter les gains partiels et clore la feature.
- Aucun changement de schéma DB, aucun nouvel outil, aucune
  modification UI dans cette feature.

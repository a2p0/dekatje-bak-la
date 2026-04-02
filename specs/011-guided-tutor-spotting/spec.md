# Feature Specification: Tuteur guidé — Micro-tâches de repérage

**Feature Branch**: `011-guided-tutor-spotting`
**Created**: 2026-04-01
**Status**: Draft
**Input**: User description: "Tuteur guidé avec micro-tâches de repérage pour vérifier la compréhension des questions BAC avant correction"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Repérage avant correction (Priority: P1)

Un élève en mode tuteur arrive sur une question. Avant de pouvoir voir la correction, il doit identifier le type de tâche demandé et les sources de données utiles via un encart interactif (clics uniquement, pas d'écriture).

**Why this priority**: C'est le cœur de la feature — la vérification de compréhension avant correction. L'échec au BAC est souvent dû à une mauvaise lecture de la question et à l'incapacité de repérer les données utiles. Cette interaction force la lecture attentive sans friction (que des clics).

**Independent Test**: Un élève en mode tuteur voit l'encart "Avant de répondre" sur chaque question, sélectionne le type de tâche et les sources, clique [Vérifier], reçoit un feedback correct/incorrect, puis peut accéder à la correction.

**Acceptance Scenarios**:

1. **Given** un élève en mode tuteur sur une question dont le type est "calculation" et les sources sont "DT2" et "mise en situation", **When** il sélectionne "Calculer une valeur" et coche "DT2" + "Mise en situation", **Then** le feedback indique que les deux réponses sont correctes.
2. **Given** un élève en mode tuteur sur une question, **When** il sélectionne le mauvais type de tâche, **Then** le feedback explique le type correct (ex: "Cette question te demande de justifier, pas de calculer").
3. **Given** un élève en mode tuteur, **When** il oublie de cocher une source dans les checkboxes, **Then** le feedback liste les sources manquées avec une indication (ex: "Tu as oublié le DT2 — regarde le tableau des caractéristiques").
4. **Given** un élève en mode tuteur, **When** il coche une source qui n'est pas nécessaire, **Then** le feedback signale les sources en trop.
5. **Given** un élève en mode tuteur qui n'a pas encore complété ou skippé le repérage, **When** il regarde la page, **Then** le bouton [Voir la correction] n'est PAS visible.
6. **Given** un élève en mode tuteur, **When** il clique {passer}, **Then** l'encart de repérage disparaît et le bouton [Voir la correction] apparaît.
7. **Given** un élève qui a déjà complété le repérage et revient sur la question, **Then** l'encart affiche le résultat (feedback), pas le formulaire, et [Voir la correction] est visible.

---

### User Story 2 — Activation du mode tuteur (Priority: P2)

Un élève qui a configuré une clé API mais dont le mode est "autonome" voit une proposition d'activer le mode tuteur quand il commence un sujet.

**Why this priority**: C'est le point d'entrée du mode tuteur. Sans cette proposition, les élèves ne découvriront pas la fonctionnalité.

**Independent Test**: Un élève en mode autonome avec une clé API voit une bannière sur la page de mise en situation. En cliquant "Activer le mode tuteur", son mode passe à tuteur et l'encart de repérage apparaît sur les questions.

**Acceptance Scenarios**:

1. **Given** un élève en mode autonome avec une clé API configurée, **When** il accède à la page de mise en situation d'un sujet, **Then** une bannière propose d'activer le mode tuteur.
2. **Given** un élève en mode autonome sans clé API, **When** il accède à la page de mise en situation, **Then** aucune bannière n'est affichée.
3. **Given** un élève en mode tuteur, **When** il accède à la page de mise en situation, **Then** aucune bannière n'est affichée (déjà activé).
4. **Given** un élève qui clique "Activer le mode tuteur", **When** il navigue vers une question, **Then** l'encart de repérage est visible.

---

### User Story 3 — Chat adaptatif avec contexte de repérage (Priority: P3)

Après la correction, l'élève peut demander une explication via le chat. Le tuteur IA connaît le résultat du repérage (sources manquées, type de tâche erroné) et adapte sa réponse en conséquence.

**Why this priority**: Le chat existant fonctionne déjà. Cette story l'enrichit avec le contexte du repérage pour des réponses plus ciblées.

**Independent Test**: Un élève qui a raté le repérage des sources ouvre le chat après la correction. Le tuteur mentionne spontanément les sources manquées et guide l'élève vers les bonnes données.

**Acceptance Scenarios**:

1. **Given** un élève qui a manqué une source lors du repérage, **When** il clique {expliquer la correction} et ouvre le chat, **Then** le tuteur mentionne la source manquée et guide vers les données.
2. **Given** un élève qui a correctement identifié toutes les sources, **When** il ouvre le chat, **Then** le tuteur part du bon point ("Tu avais bien repéré les données.").
3. **Given** un élève en mode autonome (pas de repérage), **When** il ouvre le chat, **Then** le tuteur fonctionne comme avant (pas de contexte de repérage).

---

### User Story 4 — Mode autonome inchangé (Priority: P1)

Les élèves en mode autonome (sans tuteur) conservent exactement le même parcours qu'avant : question → correction → navigation. Aucun encart de repérage, aucune étape supplémentaire.

**Why this priority**: Priorité critique — pas de régression pour les utilisateurs existants.

**Independent Test**: Un élève en mode autonome navigue entre les questions et voit la correction sans aucun encart de repérage ni bannière.

**Acceptance Scenarios**:

1. **Given** un élève en mode autonome, **When** il accède à une question, **Then** l'encart "Avant de répondre" n'est PAS affiché.
2. **Given** un élève en mode autonome, **When** il clique [Voir la correction], **Then** la correction s'affiche directement sans étape intermédiaire.

---

### Edge Cases

- Si une question n'a pas de `data_hints` → L'encart de repérage n'affiche que la partie "type de tâche" (pas de checkboxes sources).
- Si une question n'a pas d'`answer` associée → Pas d'encart de repérage (rien à vérifier).
- Si l'élève passe le repérage sur une question puis revient → L'état "skipped" est persisté, l'encart ne réapparaît pas.
- Si les sources dans `data_hints` contiennent des valeurs non-standard → On normalise en catégories connues (DT, DR, énoncé, mise en situation). Les sources non reconnues sont ignorées.
- Si toutes les sources possibles sont correctes pour une question → Les checkboxes sont toutes cochées correctement, le feedback est positif.

## Clarifications

### Session 2026-04-01

- Q: L'encart de repérage bloque-t-il l'accès à la correction ? → A: Oui, bloquant. [Voir la correction] n'apparaît qu'après [Vérifier] ou {passer}.
- Q: Le feedback de repérage montre-t-il les explications des data_hints ? → A: Oui, affiche source + localisation (ex: "DT2 — tableau des caractéristiques").

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT afficher un encart "Avant de répondre" sur chaque question pour les élèves en mode tuteur, contenant un choix de type de tâche (radio) et un choix de sources de données (checkboxes). L'encart DOIT bloquer l'accès à la correction : le bouton [Voir la correction] n'apparaît qu'après [Vérifier] ou {passer}.
- **FR-002**: Les choix radio du type de tâche DOIVENT inclure le type correct (basé sur le type de réponse de la question) et 2-3 distracteurs choisis parmi les autres types possibles.
- **FR-003**: Les checkboxes de sources DOIVENT lister toutes les sources possibles pour le sujet (documents techniques existants, documents réponse existants, énoncé de la question, mise en situation). Les réponses correctes sont déterminées par les indications de données de la question.
- **FR-004**: Le système DOIT valider les réponses de l'élève et afficher un feedback immédiat : correct/incorrect pour le type de tâche, et sources correctes/manquées/en trop pour les données. Pour les sources manquées, le feedback DOIT inclure la localisation (ex: "DT2 — tableau des caractéristiques").
- **FR-005**: L'encart de repérage DOIT être skippable via un lien {passer}.
- **FR-006**: L'état du repérage (réponses, résultat) DOIT être persisté pour chaque question afin qu'un retour sur la question affiche le résultat et non le formulaire.
- **FR-007**: Le système DOIT proposer l'activation du mode tuteur aux élèves en mode autonome qui ont une clé API configurée, via une bannière sur la page de mise en situation.
- **FR-008**: Le prompt du tuteur IA DOIT inclure le résultat du repérage (sources manquées, type erroné) pour adapter ses réponses dans le chat.
- **FR-009**: Un lien {expliquer la correction} DOIT être affiché après la correction en mode tuteur, ouvrant le chat avec un message contextuel pré-rempli.
- **FR-010**: Le mode autonome NE DOIT PAS être affecté — aucun encart de repérage, aucune étape supplémentaire, aucune bannière.

### Key Entities

- **État du tuteur** : état du parcours guidé par élève et par sujet. Contient l'état de repérage par question (type choisi, sources cochées, résultat de la vérification). Fait partie de la session élève existante.
- **Résultat de repérage** : pour chaque question — type de tâche correct/incorrect, sources correctes/manquées/en trop. Utilisé pour le feedback immédiat et pour enrichir le contexte du tuteur IA.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: L'encart de repérage est complété (pas skippé) par au moins 70% des élèves en mode tuteur sur au moins la moitié de leurs questions.
- **SC-002**: Le repérage prend moins de 30 secondes par question (que des clics, pas d'écriture).
- **SC-003**: Aucune régression fonctionnelle ou de performance sur le mode autonome.
- **SC-004**: Le tuteur IA mentionne les sources manquées dans 100% des conversations post-correction quand l'élève a raté le repérage.

## Assumptions

- Le type de réponse (`answer_type`) est renseigné pour toutes les questions validées.
- Les indications de données (`data_hints`) sont renseignées pour la majorité des questions extraites. Les questions sans indications affichent uniquement la partie type de tâche.
- L'élève a déjà une session créée au moment de la navigation vers les questions.
- Le mode tuteur est un choix par sujet (pas un réglage global).
- L'encart de repérage fonctionne sans appel IA — tout est basé sur les données déjà en base.
- Le chat adaptatif (Story 3) utilise le provider/modèle IA déjà configuré par l'élève.

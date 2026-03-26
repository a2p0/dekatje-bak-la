# Feature Specification: DekatjeBakLa — Application d'entraînement BAC STI2D

**Feature Branch**: `001-bac-training-app`
**Created**: 2026-03-26
**Status**: Draft
**Input**: Application Rails 8 d'entraînement aux examens BAC STI2D. Double authentification : enseignants et élèves (sans email, RGPD mineurs). Pipeline extraction PDF asynchrone. Espace élève en 3 modes (lecture, révision, tutorat IA streaming). Multi-provider IA. Déploiement Coolify + Neon PostgreSQL.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Enseignant : créer une classe et des comptes élèves (Priority: P1)

Un enseignant crée son compte, se connecte, crée une classe avec un code d'accès unique, génère les comptes élèves et imprime les fiches de connexion.

**Why this priority**: Sans classe ni comptes élèves, aucun élève ne peut se connecter — tout le reste en dépend.

**Independent Test**: Un enseignant peut créer une classe, générer 5 comptes élèves et télécharger les fiches de connexion sans aucune autre feature active.

**Acceptance Scenarios**:

1. **Given** un enseignant non connecté, **When** il s'inscrit avec email + mot de passe, **Then** son compte est créé et il est redirigé vers son tableau de bord.
2. **Given** un enseignant connecté, **When** il crée une classe "Terminale SIN 2026", **Then** un code d'accès unique lisible est généré (ex: `terminale-sin-2026`).
3. **Given** une classe créée, **When** l'enseignant génère 30 comptes élèves, **Then** les identifiants sont créés (prenom.nom + suffixe si doublon) et les fiches PDF sont téléchargeables.
4. **Given** un élève avec des identifiants, **When** il accède à `/{access_code}` et saisit username + password, **Then** il est connecté et ne voit que les sujets de sa classe.

---

### User Story 2 — Enseignant : uploader un sujet et valider l'extraction (Priority: P2)

L'enseignant uploade un PDF de sujet BAC. Le système extrait automatiquement les questions, corrections et data_hints. L'enseignant valide et publie.

**Why this priority**: Feature centrale — sans contenu extrait et validé, les élèves n'ont rien à réviser.

**Independent Test**: Un enseignant peut uploader un PDF, attendre l'extraction, valider les questions et publier le sujet à une classe.

**Acceptance Scenarios**:

1. **Given** un enseignant connecté, **When** il uploade un PDF de sujet, **Then** un job d'extraction démarre dans les 5 secondes et le statut est visible en temps réel.
2. **Given** l'extraction terminée, **When** l'enseignant consulte les questions, **Then** il voit une vue côte-à-côte : données extraites + iframe du PDF original.
3. **Given** une question extraite, **When** l'enseignant la valide, **Then** elle passe en statut "validée".
4. **Given** au moins une question validée, **When** l'enseignant publie, **Then** il peut assigner le sujet à une ou plusieurs classes.
5. **Given** une extraction échouée, **When** l'enseignant consulte le statut, **Then** un message d'erreur explicite s'affiche avec un bouton "Réessayer".

---

### User Story 3 — Élève : s'entraîner en mode lecture (Priority: P3)

L'élève navigue dans un sujet assigné, consulte les questions et DT/DR. Le contexte est toujours accessible via un panneau latéral.

**Why this priority**: Mode de base sans IA — accessible à tous sans clé API.

**Independent Test**: Un élève peut naviguer dans un sujet complet, consulter tous les DT/DR et reprendre là où il s'est arrêté, sans clé API.

**Acceptance Scenarios**:

1. **Given** un élève connecté avec un sujet assigné, **When** il ouvre le sujet, **Then** il peut naviguer question par question.
2. **Given** un élève sur une question, **When** il consulte la page, **Then** un panneau contextuel affiche la mise en situation et l'objectif de la partie, accessible à tout moment.
3. **Given** une question avec un DT associé, **When** l'élève clique sur le DT, **Then** le PDF s'affiche en iframe + lien téléchargement.
4. **Given** un élève qui quitte et revient, **When** il ouvre le sujet, **Then** il reprend à la dernière question consultée.

---

### User Story 4 — Élève : réviser avec corrections et feedback IA (Priority: P4)

L'élève rédige sa réponse, consulte la correction officielle et les data_hints. Avec une clé API, il peut demander un feedback IA.

**Why this priority**: Valeur pédagogique principale — distingue l'app d'un simple PDF.

**Independent Test**: Un élève peut saisir une réponse, afficher la correction avec data_hints, et obtenir un feedback IA si clé configurée.

**Acceptance Scenarios**:

1. **Given** un élève sur une question, **When** il saisit sa réponse, **Then** elle est sauvegardée automatiquement.
2. **Given** un élève ayant saisi une réponse, **When** il clique "Voir la correction", **Then** la correction s'affiche avec les data_hints ("Les données étaient dans DT1, tableau...").
3. **Given** un élève avec clé API, **When** il demande un feedback, **Then** l'IA identifie les éléments justes, manquants ou erronés.
4. **Given** un élève sans clé API, **When** il essaie d'obtenir un feedback, **Then** un message l'invite à configurer sa clé API.

---

### User Story 5 — Élève : tutorat IA en temps réel (Priority: P5)

L'élève engage une conversation avec un agent tuteur. L'agent guide sans jamais donner la réponse, peut générer des fiches de révision et référencer les leçons.

**Why this priority**: Feature premium nécessitant une clé API et les features précédentes.

**Independent Test**: Un élève avec clé API peut engager une conversation, recevoir des réponses streamées et générer une fiche de révision.

**Acceptance Scenarios**:

1. **Given** un élève avec clé API, **When** il envoie un message au tuteur, **Then** la réponse commence à s'afficher dans les 2 secondes (streaming).
2. **Given** une conversation active, **When** l'élève demande la réponse directement, **Then** l'agent refuse et pose une question pour guider.
3. **Given** un concept identifié, **When** l'élève clique "Générer une fiche de révision", **Then** une fiche structurée est générée en français.
4. **Given** une erreur IA, **When** elle se produit, **Then** un message clair s'affiche avec un lien vers la configuration.

---

### Edge Cases

- Deux élèves avec le même nom dans une classe → suffixe numérique automatique (prenom.nom2).
- Élève accédant à un sujet d'une autre classe → redirection 403.
- Extraction PDF échouée à mi-parcours → job "failed", retry possible.
- Clé API expirée en cours de conversation → message d'erreur, lien configuration.
- PDF dépassant la limite de taille → message d'erreur immédiat avant upload.
- Sujet dépublié après assignation → retiré des classes, retour en draft.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT permettre aux enseignants de créer un compte avec email + mot de passe.
- **FR-002**: Le système DOIT générer un code d'accès unique lisible pour chaque classe.
- **FR-003**: Le système DOIT créer des comptes élèves sans collecte d'email (username + password uniquement).
- **FR-004**: Le système DOIT permettre à un élève de se connecter via `/{access_code}` + username + password.
- **FR-005**: Le système DOIT isoler les données d'un élève à sa classe.
- **FR-006**: Le système DOIT permettre l'upload de PDFs de sujets (20 MB max) avec DT et DR associés.
- **FR-007**: Le système DOIT extraire asynchronement les questions, corrections et data_hints depuis les PDFs.
- **FR-008**: Le système DOIT notifier l'enseignant en temps réel du statut d'extraction.
- **FR-009**: Le système DOIT permettre à l'enseignant de valider, modifier et publier les questions extraites.
- **FR-010**: Le système DOIT afficher un panneau contextuel (mise en situation + objectif partie) accessible à tout moment dans l'espace élève.
- **FR-011**: Le système DOIT permettre à l'élève de consulter les DT/DR en PDF natif (viewer + téléchargement).
- **FR-012**: Le système DOIT persister la progression de l'élève question par question.
- **FR-013**: Le système DOIT afficher les data_hints après révélation de la correction.
- **FR-014**: Le système DOIT chiffrer les clés API enseignant et élève (jamais en clair ni dans les logs).
- **FR-015**: Le système DOIT supporter 4 providers IA : Anthropic, OpenRouter, OpenAI, Google Gemini.
- **FR-016**: Le système DOIT streamer les réponses de l'agent tutorat en temps réel.
- **FR-017**: L'agent tutorat NE DOIT JAMAIS donner la réponse directement à l'élève.
- **FR-018**: Le système DOIT permettre à l'enseignant de réinitialiser le mot de passe d'un élève.
- **FR-019**: Le système DOIT exporter les fiches de connexion élèves en PDF imprimable.
- **FR-020**: Le système DOIT appliquer un soft delete sur les sujets et questions.

### Key Entities

- **User (enseignant)**: Identifié par email, propriétaire de classes et sujets, clé API optionnelle pour l'extraction.
- **Student (élève)**: Identifié par username dans une classe, sans email, clé API optionnelle pour le tutorat.
- **Classroom**: Classe avec code d'accès unique, relie enseignant et élèves, associée à des sujets.
- **Subject**: Sujet BAC avec mise en situation, divisé en parties, contient des documents techniques.
- **Part**: Partie d'un sujet (commune ou spécifique), avec objectif pédagogique.
- **Question**: Question avec énoncé, barème, type de réponse et contexte local.
- **Answer**: Correction officielle avec data_hints et concepts clés.
- **TechnicalDocument (DT/DR)**: PDF associé à un sujet, référencé par des questions.
- **StudentSession**: Session de travail d'un élève sur un sujet, avec progression persistée.
- **Conversation**: Historique de conversation tutorat pour une question donnée.
- **ExtractionJob**: Suivi asynchrone de l'extraction PDF avec statut et logs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un enseignant peut créer une classe et générer 30 comptes élèves en moins de 5 minutes.
- **SC-002**: L'extraction d'un sujet PDF de 20 pages démarre en moins de 5 secondes après upload.
- **SC-003**: 80% des questions sont correctement extraites d'un sujet BAC typique sans correction manuelle.
- **SC-004**: Un élève peut reprendre sa session et retrouver sa progression en moins de 10 secondes.
- **SC-005**: Les réponses de l'agent tutorat commencent à s'afficher en moins de 2 secondes.
- **SC-006**: Aucune donnée personnelle élève n'est accessible hors de sa classe.
- **SC-007**: Le mode lecture (Mode 0) est accessible sans aucune clé API configurée.
- **SC-008**: L'interface est utilisable sur une connexion lente (aucune ressource CDN externe).

## Assumptions

- Les élèves utilisent des appareils fournis par l'établissement (PC ou tablette), pas exclusivement mobile.
- L'enseignant distribue les fiches de connexion en présentiel — pas d'envoi par email.
- Les sujets BAC sont des PDFs natifs (générés numériquement), pas des scans (OCR hors MVP).
- Un élève appartient à une seule classe à la fois dans le MVP.
- Le mode offline n'est pas requis — une connexion Internet est disponible en classe.
- Les sujets BAC STI2D ont une structure hiérarchique : 1 sujet → 2-5 parties → N questions.
- L'enseignant a accepté les conditions d'utilisation de son provider IA.

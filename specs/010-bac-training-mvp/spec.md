# Feature Specification: DekatjeBakLa — BAC Training MVP

**Feature Branch**: `010-bac-training-mvp`
**Created**: 2026-03-29
**Status**: Draft
**Input**: User description: "DekatjeBakLa — Application web d'entraînement aux examens BAC pour lycéens STI2D en Martinique."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Inscription et connexion enseignant (Priority: P1)

Un enseignant s'inscrit avec prénom, nom, email et mot de passe. Il reçoit un email de confirmation, clique le lien, et accède à son tableau de bord enseignant.

**Why this priority**: Sans authentification enseignant, rien d'autre ne fonctionne. C'est la porte d'entrée de l'application.

**Independent Test**: Peut être testé en s'inscrivant, confirmant l'email, se connectant, et vérifiant l'accès au dashboard.

**Acceptance Scenarios**:

1. **Given** un visiteur sur la page d'inscription, **When** il remplit prénom, nom, email et mot de passe, **Then** un email de confirmation est envoyé et un message l'indique.
2. **Given** un email de confirmation reçu, **When** l'enseignant clique le lien, **Then** son compte est confirmé et il est redirigé vers le login.
3. **Given** un enseignant confirmé, **When** il se connecte avec email et mot de passe, **Then** il arrive sur le tableau de bord enseignant.
4. **Given** un enseignant connecté, **When** il clique "Se déconnecter", **Then** sa session est terminée et il est redirigé vers le login.
5. **Given** un visiteur non connecté, **When** il tente d'accéder à `/teacher/`, **Then** il est redirigé vers la page de connexion.

---

### User Story 2 — Gestion des classes et des élèves (Priority: P1)

Un enseignant crée une classe (nom, année scolaire, spécialité), ce qui génère un code d'accès unique. Il ajoute des élèves (individuellement ou en masse) — les identifiants sont générés automatiquement. Il peut exporter les fiches de connexion en PDF ou Markdown, et réinitialiser les mots de passe.

**Why this priority**: Les classes et élèves sont nécessaires pour que les élèves puissent se connecter et accéder aux sujets.

**Independent Test**: Créer une classe, ajouter un élève, vérifier que les identifiants sont générés et que l'export PDF fonctionne.

**Acceptance Scenarios**:

1. **Given** un enseignant connecté, **When** il crée une classe avec nom, année et spécialité, **Then** la classe apparaît dans sa liste avec un code d'accès unique.
2. **Given** une classe existante, **When** l'enseignant ajoute un élève (prénom, nom), **Then** un identifiant (prenom.nom) et un mot de passe sont générés et affichés une seule fois.
3. **Given** un doublon de nom dans la classe, **When** l'enseignant ajoute l'élève, **Then** un suffixe numérique est ajouté (jean.dupont2).
4. **Given** une classe avec des élèves, **When** l'enseignant exporte les fiches, **Then** un PDF A4 imprimable avec les identifiants est téléchargé.
5. **Given** une classe existante, **When** l'enseignant utilise l'ajout en masse (liste prénom nom par ligne), **Then** tous les élèves sont créés avec identifiants générés.
6. **Given** un élève existant, **When** l'enseignant réinitialise son mot de passe, **Then** un nouveau mot de passe est généré et affiché.
7. **Given** le tableau de bord enseignant, **When** l'enseignant consulte ses classes, **Then** chaque classe affiche le nombre d'élèves et le code d'accès.

---

### User Story 3 — Upload et extraction de sujets PDF (Priority: P1)

Un enseignant upload un sujet d'examen (5 fichiers PDF : énoncé, DT, DR vierge, DR corrigé, questions corrigées). L'extraction automatique par IA découpe le sujet en parties, questions et réponses. L'enseignant voit la progression de l'extraction.

**Why this priority**: Sans sujets extraits, il n'y a pas de contenu pour les élèves.

**Independent Test**: Uploader un sujet avec 5 PDFs, vérifier que l'extraction produit des parties et questions.

**Acceptance Scenarios**:

1. **Given** un enseignant connecté, **When** il accède à "Nouveau sujet", **Then** un formulaire demande titre, année, type d'examen, spécialité, région et 5 fichiers PDF.
2. **Given** le formulaire rempli avec tous les PDFs, **When** l'enseignant soumet, **Then** le sujet est créé et l'extraction démarre automatiquement.
3. **Given** une extraction en cours, **When** l'enseignant consulte le sujet, **Then** il voit le statut "Extraction en cours...".
4. **Given** une extraction terminée, **When** l'enseignant consulte le sujet, **Then** il voit les parties et questions extraites avec un message de succès.
5. **Given** une extraction échouée, **When** l'enseignant consulte le sujet, **Then** il voit le message d'erreur et un bouton "Relancer l'extraction".
6. **Given** le formulaire de sujet, **When** un fichier PDF manque, **Then** le formulaire affiche une erreur et empêche la soumission.

---

### User Story 4 — Validation et publication des questions (Priority: P1)

Un enseignant consulte les questions extraites par partie, avec le PDF énoncé affiché côte à côte. Il peut éditer les questions en ligne, les valider, les supprimer. Quand au moins une question est validée, il peut publier le sujet et l'assigner à ses classes.

**Why this priority**: La validation garantit la qualité du contenu avant qu'il n'arrive aux élèves.

**Independent Test**: Ouvrir un sujet extrait, valider une question, publier, assigner à une classe.

**Acceptance Scenarios**:

1. **Given** un sujet avec extraction terminée, **When** l'enseignant clique sur une partie, **Then** il voit la liste des questions à gauche et le PDF énoncé à droite.
2. **Given** une question affichée, **When** l'enseignant clique "Valider", **Then** le statut passe à "validé" et le badge change de couleur.
3. **Given** une question affichée, **When** l'enseignant modifie le label ou les points et sauvegarde, **Then** les modifications sont enregistrées sans rechargement de page.
4. **Given** une question, **When** l'enseignant clique "Supprimer", **Then** la question disparaît de la liste (suppression douce).
5. **Given** un sujet avec au moins une question validée, **When** l'enseignant clique "Publier", **Then** le sujet passe en statut "publié" et il est redirigé vers la page d'assignation.
6. **Given** un sujet sans question validée, **When** l'enseignant voit le bouton "Publier", **Then** le bouton est désactivé avec un message explicatif.
7. **Given** la page d'assignation, **When** l'enseignant coche des classes et enregistre, **Then** le sujet est assigné aux classes sélectionnées.
8. **Given** un sujet publié, **When** l'enseignant clique "Dépublier", **Then** le sujet repasse en brouillon.

---

### User Story 5 — Connexion élève et navigation des sujets (Priority: P1)

Un élève se connecte via l'URL de sa classe (/{code_accès}) avec son identifiant et mot de passe. Il voit la liste des sujets assignés à sa classe avec sa progression. Il choisit un sujet et commence à travailler.

**Why this priority**: C'est l'entrée dans l'expérience élève — sans ça, pas d'apprentissage.

**Independent Test**: Se connecter en tant qu'élève, voir les sujets assignés, cliquer sur un sujet.

**Acceptance Scenarios**:

1. **Given** un élève avec des identifiants, **When** il accède à `/{code_accès}`, **Then** il voit un formulaire de connexion avec le nom de la classe.
2. **Given** le formulaire de connexion, **When** l'élève entre des identifiants corrects, **Then** il est redirigé vers la liste des sujets.
3. **Given** des identifiants incorrects, **When** l'élève tente de se connecter, **Then** un message d'erreur s'affiche.
4. **Given** la liste des sujets, **When** l'élève consulte, **Then** il voit uniquement les sujets publiés assignés à sa classe, avec un pourcentage de progression pour chaque.
5. **Given** un sujet non commencé, **When** l'élève clique "Commencer", **Then** il est redirigé vers la première question de la première partie.
6. **Given** un sujet en cours, **When** l'élève clique "Continuer", **Then** il est redirigé vers la première question non terminée.
7. **Given** un élève connecté, **When** il clique "Se déconnecter", **Then** sa session est terminée.

---

### User Story 6 — Navigation question par question avec contexte (Priority: P1)

Un élève navigue les questions une par une au sein d'une partie. La sidebar affiche le contexte (mise en situation, objectif de la partie, documents DT/DR). Il peut naviguer entre les questions et les parties.

**Why this priority**: C'est le coeur de l'expérience d'apprentissage — l'élève doit pouvoir lire et comprendre chaque question dans son contexte.

**Independent Test**: Naviguer entre les questions, vérifier que la sidebar affiche le contexte correct, ouvrir un document DT.

**Acceptance Scenarios**:

1. **Given** un élève sur une question, **When** il regarde la sidebar, **Then** il voit la mise en situation du sujet, l'objectif de la partie, et les liens vers les documents.
2. **Given** la page question sur desktop, **When** l'élève consulte, **Then** la sidebar est visible en permanence à gauche.
3. **Given** la page question sur mobile, **When** l'élève clique le menu hamburger, **Then** la sidebar s'ouvre en overlay.
4. **Given** une question affichée, **When** l'élève clique "Question suivante", **Then** la question suivante s'affiche.
5. **Given** la dernière question d'une partie, **When** l'élève clique le bouton de navigation, **Then** il est redirigé vers les sujets.
6. **Given** la sidebar, **When** l'élève clique sur une autre question dans la liste, **Then** il est redirigé directement vers cette question.
7. **Given** la sidebar, **When** l'élève clique sur une autre partie, **Then** il est redirigé vers la première question non terminée de cette partie.
8. **Given** un document DT dans la sidebar, **When** l'élève clique le lien, **Then** le PDF s'ouvre dans un nouvel onglet.
9. **Given** une question non encore corrigée, **When** l'élève consulte les documents, **Then** le DR corrigé et les questions corrigées ne sont pas visibles.

---

### User Story 7 — Révélation de la correction (Priority: P1)

Après avoir travaillé sur une question, l'élève peut révéler la correction officielle. Il voit la correction, l'explication, les indications sur la localisation des données utiles et les concepts clés. La question est marquée comme terminée.

**Why this priority**: La correction est la valeur pédagogique principale — l'élève apprend de ses erreurs.

**Independent Test**: Cliquer "Voir la correction", vérifier que tous les éléments s'affichent et que la progression est mise à jour.

**Acceptance Scenarios**:

1. **Given** une question avec une réponse disponible, **When** l'élève clique "Voir la correction", **Then** la correction officielle s'affiche sous la question.
2. **Given** la correction affichée, **When** l'élève regarde, **Then** il voit : la correction (texte vert), l'explication pédagogique, les données utiles (source + localisation), et les concepts clés (badges).
3. **Given** la correction révélée, **When** l'élève revient sur cette question plus tard, **Then** la correction est toujours visible.
4. **Given** la correction révélée, **When** l'élève consulte la sidebar, **Then** les documents DR corrigé et questions corrigées sont maintenant visibles.
5. **Given** une question sans réponse en base, **When** l'élève consulte, **Then** le bouton "Voir la correction" n'apparaît pas.
6. **Given** une correction révélée, **When** l'élève consulte la liste des questions dans la sidebar, **Then** la question est marquée comme terminée (✓).

---

### User Story 8 — Configuration clé API élève (Priority: P2)

Un élève accède à une page de réglages où il configure son mode de travail par défaut (révision autonome ou tutorat IA), son provider IA, son modèle, et sa clé API. Il peut tester sa clé avant de sauvegarder.

**Why this priority**: Nécessaire avant de pouvoir utiliser le tutorat IA, mais l'application est déjà utilisable en Mode 1 sans clé.

**Independent Test**: Accéder aux réglages, configurer une clé, la tester, sauvegarder.

**Acceptance Scenarios**:

1. **Given** un élève connecté, **When** il clique "Réglages" dans la sidebar ou la liste des sujets, **Then** il accède à la page de réglages.
2. **Given** la page réglages, **When** l'élève sélectionne un provider, **Then** le dropdown modèles se met à jour avec les modèles disponibles pour ce provider, avec indicateurs de coût.
3. **Given** un provider et un modèle sélectionnés, **When** l'élève entre une clé API et clique "Tester", **Then** un test de connexion est effectué et le résultat s'affiche (succès vert ou erreur rouge).
4. **Given** le formulaire rempli, **When** l'élève clique "Enregistrer", **Then** les réglages sont sauvegardés et un message de confirmation s'affiche.
5. **Given** le champ clé API, **When** l'élève clique l'icône oeil, **Then** la clé devient visible/masquée.
6. **Given** aucune clé configurée, **When** l'élève tente d'utiliser le tutorat IA, **Then** un message l'invite à configurer sa clé avec un lien vers les réglages.

---

### User Story 9 — Tutorat IA en streaming (Priority: P2)

Un élève ouvre le chat tutorat depuis la page question. Un tuteur IA bienveillant le guide pas à pas sans donner la réponse. Les réponses arrivent en streaming (token par token). Le tuteur connaît la correction officielle (confidentielle) et les insights de l'élève des sessions précédentes.

**Why this priority**: C'est la fonctionnalité différenciante — l'accompagnement personnalisé par IA. Mais l'app est utile sans (Mode 1 correction seule).

**Independent Test**: Ouvrir le chat, envoyer un message, vérifier que la réponse arrive en streaming et que le tuteur ne donne pas la réponse directement.

**Acceptance Scenarios**:

1. **Given** un élève avec une clé API configurée sur une page question, **When** il clique "Tutorat", **Then** le chat s'ouvre dans un drawer à droite (desktop) ou en overlay (mobile).
2. **Given** le chat ouvert, **When** l'élève envoie un message, **Then** la réponse du tuteur s'affiche progressivement (streaming token par token).
3. **Given** une conversation en cours, **When** le tuteur répond, **Then** il guide l'élève par étapes, valorise ses tentatives, et ne donne jamais la réponse directement.
4. **Given** un élève qui revient sur une question précédemment discutée, **When** il ouvre le chat, **Then** l'historique de la conversation est affiché.
5. **Given** une clé API avec crédits insuffisants, **When** l'élève envoie un message, **Then** un message d'erreur clair s'affiche avec un lien vers les réglages.
6. **Given** une clé API invalide, **When** l'élève envoie un message, **Then** un message d'erreur indique que la clé est invalide avec un lien vers les réglages.
7. **Given** un streaming en cours, **When** l'élève tente d'envoyer un autre message, **Then** l'input est désactivé jusqu'à la fin du streaming.
8. **Given** un élève qui a discuté de plusieurs questions, **When** le tuteur commence une nouvelle conversation, **Then** le system prompt inclut les insights des conversations précédentes (concepts maîtrisés, lacunes identifiées).

---

### User Story 10 — Navigation globale et pages essentielles (Priority: P1)

L'application dispose d'une home page, d'une navigation cohérente entre toutes les sections, et de pages de base fonctionnelles (dashboard enseignant, liste des sujets, page sujet).

**Why this priority**: Sans navigation cohérente, l'utilisateur ne peut pas accéder aux fonctionnalités même si elles existent.

**Independent Test**: Naviguer dans toute l'application sans avoir à entrer manuellement une URL.

**Acceptance Scenarios**:

1. **Given** un visiteur sur la page d'accueil, **When** il consulte, **Then** il voit un lien vers la connexion enseignant et un champ pour entrer un code d'accès élève.
2. **Given** un enseignant connecté sur le dashboard, **When** il consulte, **Then** il voit ses classes et ses sujets avec des liens vers toutes les actions possibles.
3. **Given** un enseignant sur la liste des sujets, **When** il consulte, **Then** il voit un bouton "Nouveau sujet" visible et chaque sujet a un lien vers sa page détail.
4. **Given** un enseignant sur la page d'un sujet, **When** il consulte, **Then** il voit les PDFs, le statut d'extraction, les parties (liens), les stats de validation, et les actions disponibles (publier/archiver/assigner).
5. **Given** n'importe quelle page enseignant, **When** l'enseignant consulte, **Then** un menu/header permet de naviguer vers le dashboard, les classes, les sujets, et la déconnexion.
6. **Given** un élève connecté, **When** il navigue, **Then** il peut toujours accéder aux réglages et à la déconnexion depuis n'importe quelle page.

---

### Edge Cases

- Que se passe-t-il quand un sujet assigné est dépublié pendant qu'un élève y travaille ?
- Comment le système gère un élève qui tente d'accéder au sujet d'une autre classe ?
- Que se passe-t-il quand l'extraction IA retourne un JSON invalide ou incomplet ?
- Comment le système gère la perte de connexion pendant le streaming du tutorat ?
- Que se passe-t-il si deux enseignants créent des classes avec des paramètres identiques ?
- Comment le système gère un mot de passe étudiant vide ou trop court ?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT permettre l'inscription enseignant avec prénom, nom, email et mot de passe, et envoyer un email de confirmation.
- **FR-002**: Le système DOIT authentifier les enseignants via email/mot de passe après confirmation.
- **FR-003**: Le système DOIT permettre la création de classes avec génération automatique d'un code d'accès unique.
- **FR-004**: Le système DOIT générer automatiquement des identifiants élèves (prenom.nom) avec gestion des doublons par suffixe numérique.
- **FR-005**: Le système NE DOIT PAS collecter d'email pour les élèves (conformité RGPD mineurs).
- **FR-006**: Le système DOIT permettre l'export des fiches de connexion élèves en PDF et Markdown.
- **FR-007**: Le système DOIT permettre l'upload de 5 fichiers PDF obligatoires par sujet (énoncé, DT, DR vierge, DR corrigé, questions corrigées).
- **FR-008**: Le système DOIT extraire automatiquement les parties, questions et réponses depuis le PDF via IA.
- **FR-009**: Le système DOIT permettre la validation question par question avec édition inline.
- **FR-010**: Le système DOIT conditionner la publication à au moins une question validée.
- **FR-011**: Le système DOIT permettre l'assignation des sujets publiés aux classes.
- **FR-012**: Le système DOIT authentifier les élèves via code d'accès classe + identifiant + mot de passe, sans email.
- **FR-013**: Le système DOIT afficher les questions une par une avec le contexte accessible en permanence (mise en situation, objectif, documents).
- **FR-014**: Le système DOIT suivre la progression de chaque élève par sujet (questions vues, questions corrigées).
- **FR-015**: Le système DOIT afficher la correction complète (correction, explication, données utiles, concepts clés) quand l'élève la demande.
- **FR-016**: Le système DOIT masquer le DR corrigé et les questions corrigées jusqu'à la révélation de la correction.
- **FR-017**: Le système DOIT permettre la configuration d'une clé API par l'élève avec choix du provider et du modèle.
- **FR-018**: Le système DOIT fournir un tutorat IA en streaming qui guide l'élève sans donner la réponse.
- **FR-019**: Le système DOIT extraire des insights structurés (concepts maîtrisés, lacunes) après chaque conversation tuteur.
- **FR-020**: Le système DOIT fournir une navigation cohérente permettant d'accéder à toutes les fonctionnalités sans URL manuelle.

### Key Entities

- **Enseignant (User)**: Compte Devise, possède des classes et des sujets, peut configurer un template de prompt tuteur.
- **Classe (Classroom)**: Nom, année scolaire, spécialité, code d'accès unique. Contient des élèves.
- **Élève (Student)**: Prénom, nom, identifiant généré, mot de passe (sans email). Appartient à une classe. Possède clé API chiffrée, provider, modèle.
- **Sujet (Subject)**: Titre, année, type examen, spécialité, région, 5 PDFs attachés, statut (brouillon → validation → publié → archivé).
- **Partie (Part)**: Numéro, titre, objectif, type de section (commun/spécifique). Appartient à un sujet.
- **Question**: Numéro, label, contexte, points, type de réponse, statut (brouillon/validé). Appartient à une partie.
- **Réponse (Answer)**: Correction, explication, données utiles (localisation sources), concepts clés. Appartient à une question.
- **Session élève (StudentSession)**: Progression JSON par question (vu/corrigé). Lie élève et sujet.
- **Conversation**: Messages JSON, provider utilisé, tokens consommés. Lie élève et question.
- **Insight élève (StudentInsight)**: Type (maîtrisé/difficulté/erreur/note), concept, texte. Lie élève et sujet.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un enseignant peut créer un sujet complet (upload → extraction → validation → publication → assignation) en moins de 15 minutes.
- **SC-002**: Un élève peut se connecter et commencer à travailler sur un sujet en moins de 1 minute.
- **SC-003**: 100% des pages de l'application sont accessibles via des liens de navigation (aucune URL manuelle requise).
- **SC-004**: La correction s'affiche en moins de 2 secondes après le clic.
- **SC-005**: Le premier token du tuteur IA arrive en moins de 3 secondes après l'envoi du message.
- **SC-006**: L'application est utilisable sur mobile (toutes les pages sont responsive).
- **SC-007**: Aucune donnée personnelle élève (email, clé API en clair) n'est exposée dans les logs ou l'interface.
- **SC-008**: Les feature specs Capybara couvrent les 10 user stories avec 100% des acceptance scenarios testés.

## Assumptions

- Les enseignants et élèves disposent d'une connexion internet stable.
- Les élèves utilisent des navigateurs modernes (Chrome, Firefox, Safari récents).
- Les clés API sont fournies par les élèves ou leurs parents — l'application ne fournit pas de clés.
- Le modèle gratuit OpenRouter (Qwen3) est disponible mais avec des limitations de débit.
- L'extraction IA peut échouer sur certains PDFs mal formatés — l'enseignant peut relancer manuellement.
- L'application est en français uniquement pour le MVP.
- Le déploiement se fait sur un VPS via Coolify (Docker + Nixpacks).

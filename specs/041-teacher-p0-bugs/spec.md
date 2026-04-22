# Feature Specification: Teacher P0 bug fixes

**Feature Branch**: `041-teacher-p0-bugs`
**Created**: 2026-04-16
**Status**: Draft
**Input**: User description: "Fix trois bugs produit P0 côté enseignant: téléchargement des identifiants générés avant perte, action destroy pour Subject (soft-delete), feedback extraction IA moins opaque. Scope minimal, pas de refonte visuelle."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Télécharger les identifiants générés avant perte (Priority: P1)

Quand un enseignant vient d'inscrire un ou plusieurs élèves dans une classe, il voit une seule fois un bandeau affichant leurs identifiants et mots de passe en clair. Aujourd'hui, s'il rafraîchit ou navigue ailleurs, ces mots de passe sont perdus et il doit tous les réinitialiser. Cette story garantit qu'il peut à ce moment précis télécharger une fiche PDF imprimable des identifiants affichés, directement depuis le bandeau, avant qu'ils ne disparaissent.

**Why this priority** : perte de données critique pour l'enseignant — sans ce garde-fou, chaque rafraîchissement accidentel demande un reset massif des mots de passe élèves. C'est le bug ayant le plus gros impact fonctionnel.

**Independent Test** : un enseignant inscrit un ou plusieurs élèves, vérifie que le bandeau "Identifiants générés" contient un bouton de téléchargement, clique dessus et reçoit un PDF contenant les fiches de connexion des élèves concernés.

**Acceptance Scenarios**:

1. **Given** un enseignant vient d'inscrire 3 élèves via l'ajout en lot, **When** la page de détail de la classe s'affiche avec le bandeau ambre des identifiants générés, **Then** le bandeau contient un bouton "Télécharger la fiche PDF" cliquable qui télécharge un PDF de la classe.
2. **Given** l'enseignant voit le bandeau des identifiants, **When** il clique sur le bouton de téléchargement, **Then** un fichier PDF est proposé au navigateur avec les fiches de connexion de la classe.
3. **Given** l'enseignant voit le bandeau des identifiants, **When** il rafraîchit la page sans avoir cliqué, **Then** le bandeau disparaît (comportement inchangé).

---

### User Story 2 — Archiver un sujet (Priority: P1)

Un enseignant qui crée un sujet par erreur, ou qui veut retirer un ancien sujet de sa liste de travail, n'a actuellement aucun moyen de le supprimer depuis l'interface. Cette story ajoute un bouton "Archiver le sujet" sur la page de détail d'un sujet. L'action archive le sujet (soft-delete : il disparaît de la liste mais reste récupérable en base), après une confirmation explicite.

**Why this priority** : bloqueur fonctionnel — aucun recours utilisateur pour corriger une création erronée ou faire le ménage. Équivalent P1 au P0-a car ça évite aussi un reset/manipulation DB manuel.

**Independent Test** : un enseignant crée un sujet, ouvre sa page de détail, clique sur "Archiver", confirme le dialogue, et vérifie que le sujet ne figure plus dans la liste de ses sujets.

**Acceptance Scenarios**:

1. **Given** un enseignant consulte la page de détail d'un sujet qu'il possède, **When** la page est affichée, **Then** un bouton "Archiver le sujet" de style secondaire/danger est visible (hors CTA principal).
2. **Given** l'enseignant clique sur "Archiver le sujet", **When** la page affiche une demande de confirmation, **Then** l'enseignant doit confirmer explicitement avant que l'action ne s'exécute.
3. **Given** l'enseignant confirme l'archivage, **When** l'action aboutit, **Then** il est redirigé vers la liste de ses sujets, un message de succès apparaît, et le sujet n'apparaît plus dans la liste.
4. **Given** l'enseignant annule le dialogue de confirmation, **When** il annule, **Then** le sujet reste intact et aucune redirection n'a lieu.
5. **Given** un sujet a été archivé, **When** l'enseignant liste ses sujets, **Then** le sujet archivé n'y figure pas.

---

### User Story 3 — Suivre la progression d'une extraction (Priority: P2)

Quand l'enseignant upload un sujet, l'extraction IA peut durer 1 à 3 minutes. Aujourd'hui il voit uniquement un spinner et la mention "Extraction en cours…", sans aucune indication temporelle — il ferme souvent l'onglet par impatience. Cette story affiche une indication relative du temps écoulé ("démarrée il y a 45 secondes") qui se rafraîchit au fil de l'extraction, et s'assure que les lecteurs d'écran sont notifiés quand le statut change (processing → done/failed).

**Why this priority** : pas un blocage strict (l'extraction se termine en arrière-plan), mais impact fort sur la confiance utilisateur. P2 car moins critique qu'une perte de données ou qu'une action manquante.

**Independent Test** : un enseignant uploade un sujet, ouvre la page du sujet pendant l'extraction, et vérifie que "Extraction en cours…" est accompagné d'un texte temporel relatif ; il constate qu'après un rafraîchissement, le texte est mis à jour (ex. "démarrée il y a 1 minute").

**Acceptance Scenarios**:

1. **Given** une extraction est en cours pour un sujet, **When** l'enseignant consulte la page de détail du sujet, **Then** il voit le statut "Extraction en cours…" complété d'un délai relatif depuis le démarrage du job.
2. **Given** une extraction est en cours, **When** la page se rafraîchit (manuellement ou via mise à jour automatique), **Then** le délai relatif est recalculé et affiché à jour.
3. **Given** une extraction passe de `processing` à `done` ou `failed`, **When** la zone de statut change, **Then** un utilisateur de lecteur d'écran est notifié du changement de statut.

---

### Edge Cases

- **Bandeau sans élèves générés** : si aucun élève n'a été ajouté dans la session précédente, le bandeau ne s'affiche pas et le bouton de téléchargement n'apparaît pas. Comportement inchangé.
- **Export PDF en erreur** : si le service d'export PDF échoue (ex. aucun élève dans la classe), la requête de téléchargement retourne une erreur standard. Pas de modification du service d'export dans cette feature.
- **Sujet déjà archivé** : la route d'archivage n'est exposée que pour les sujets actifs. Tenter d'archiver un sujet déjà archivé retourne une erreur standard (non trouvé).
- **Sujet archivé visible dans d'autres vues** : les écrans qui chargent des sujets via le scope actif filtrent déjà correctement. Aucune vue ne doit charger un sujet archivé par accident.
- **Extraction sans timestamp de démarrage** : si un job d'extraction très ancien n'a pas de timestamp de démarrage (données héritées), afficher "Extraction en cours…" sans la mention temporelle (fallback gracieux).
- **Extraction de longue durée (> 1 h)** : le texte relatif reste lisible (ex. "démarrée il y a plus d'une heure" ou équivalent standard).

## Requirements *(mandatory)*

### Functional Requirements

**P0-a — Téléchargement des identifiants générés**

- **FR-001** : Le bandeau d'identifiants générés affiché sur la page de détail d'une classe MUST contenir un bouton permettant de télécharger la fiche PDF de la classe.
- **FR-002** : Le bouton MUST rester conforme au design system existant (variante primaire ou équivalente pour un CTA d'action immédiate).
- **FR-003** : Le téléchargement MUST utiliser l'export PDF existant de la classe sans modification du service d'export.
- **FR-004** : Le bandeau et ses identifiants éphémères MUST conserver leur comportement actuel (affichés une seule fois, effacés de la session après lecture).

**P0-b — Archivage d'un sujet**

- **FR-005** : L'enseignant MUST pouvoir déclencher l'archivage d'un sujet qu'il possède depuis la page de détail du sujet.
- **FR-006** : L'action d'archivage MUST demander une confirmation explicite avant exécution.
- **FR-007** : L'archivage MUST être un soft-delete : le sujet reste en base mais n'apparaît plus dans les listes actives.
- **FR-008** : Après archivage réussi, l'enseignant MUST être redirigé vers la liste de ses sujets avec un message de confirmation.
- **FR-009** : Le sujet archivé MUST ne plus apparaître dans la liste des sujets, ni dans les sujets récents de la page d'accueil.
- **FR-010** : Seul le propriétaire du sujet MUST pouvoir l'archiver (autorisation existante).
- **FR-011** : Le bouton d'archivage MUST être placé de façon visible mais pas concurrent du CTA principal (variante danger/ghost, pas primaire).

**P0-c — Feedback extraction IA**

- **FR-012** : Pendant une extraction en cours, le statut affiché MUST être accompagné d'une indication du temps écoulé depuis le démarrage du job.
- **FR-013** : Le délai affiché MUST être lisible en langage humain et en français (ex. "démarrée il y a 45 secondes", "démarrée il y a 2 minutes").
- **FR-014** : Le délai MUST être recalculé à chaque rendu de la zone de statut (manuel ou via rafraîchissement automatique).
- **FR-015** : Les changements d'état de l'extraction (processing → done/failed) MUST être annoncés aux technologies d'assistance.
- **FR-016** : Si le timestamp de démarrage est absent, le statut MUST continuer de s'afficher sans planter (fallback sans mention temporelle).

**Transverses**

- **FR-017** : Aucune refonte visuelle n'est autorisée dans cette feature (hors scope 027).
- **FR-018** : Chaque story MUST être couverte par un test de fonctionnalité utilisateur indépendant.
- **FR-019** : La suppression d'une classe est hors scope de cette feature.

### Key Entities

- **Classroom** : classe d'élèves. Attribut pertinent ici : possède un export PDF de fiches de connexion.
- **Subject** : sujet pédagogique. Attribut pertinent : marqueur d'archivage (soft-delete) permettant de le filtrer des listes actives sans perte de données.
- **Generated credentials (éphémère)** : paire identifiant/mot de passe en clair créée lors de l'inscription d'un élève ; n'existe que le temps d'un affichage unique.
- **ExtractionJob** : job d'extraction d'un sujet. Attributs pertinents : statut (pending/processing/done/failed) et timestamp de démarrage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : Pour 100 % des enseignants affichant le bandeau d'identifiants générés, un bouton de téléchargement de fiche PDF est présent et fonctionnel sans rafraîchissement préalable.
- **SC-002** : La perte involontaire de mots de passe en clair après inscription d'un élève (nécessitant un reset manuel) est réduite à zéro lorsqu'un enseignant utilise le nouveau bouton.
- **SC-003** : Un enseignant peut archiver un sujet créé par erreur en moins de 15 secondes (depuis la page de détail du sujet jusqu'à la redirection), sans manipulation de base de données.
- **SC-004** : 100 % des sujets archivés disparaissent des listes actives de l'enseignant dans la même requête.
- **SC-005** : Pendant une extraction en cours, 100 % des affichages de statut pour les jobs disposant d'un timestamp de démarrage contiennent une indication du temps écoulé lisible en français.
- **SC-006** : Les utilisateurs de lecteurs d'écran reçoivent une notification automatique lors de tout changement du statut d'extraction (processing → done/failed) sur la page de détail du sujet.

## Assumptions

- L'export PDF d'une classe est opérationnel et couvre les besoins de la story P0-a sans modification.
- Le modèle Sujet utilise déjà un mécanisme de soft-delete exposé via un scope actif. Aucune migration n'est nécessaire.
- L'action d'archivage d'un sujet n'a pas d'effet de cascade observable côté UI dans cette feature (les parties, questions et sessions liées restent en base et pourront être gérées ultérieurement).
- Les fichiers PDF attachés à un sujet archivé restent stockés tant que le soft-delete n'est pas purgé (comportement par défaut acceptable).
- Les enseignants disposent d'un navigateur moderne compatible avec les confirmations standards du projet.
- La suppression d'une classe est traitée dans une feature ultérieure (nécessite une migration de marqueur d'archivage sur la classe et une étude de cascade).
- Le bandeau des identifiants générés continue d'être effacé après première consultation : la feature ne change pas ce comportement mais fournit une porte de sortie avant la perte.
- La feature ne traite aucune migration de données.

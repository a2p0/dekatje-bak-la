# Feature Specification: Desktop Question Layout (questions#show)

**Feature Branch**: `064-desktop-question-layout`
**Created**: 2026-05-11
**Status**: Draft
**Input**: Bundle de design exporté depuis claude.ai/design (`tmp/design-bundle/`) — refonte du layout desktop élève pour `questions#show` : 3 écrans (lecture, correction, tutorat), split 50/50 question | DT viewer, top navbar, drawer Tibo 60/40. Source visuelle : `tmp/design-bundle/project/directions/student-desktop.jsx`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Lecture d'une question en desktop (Priority: P1)

L'élève accède à une question du sujet depuis un écran large (≥1024px). Au lieu d'une colonne unique sous une sidebar, il voit simultanément l'énoncé de la question à gauche et le document technique (DT) référencé à droite. Il peut consulter le DT sans quitter la question, ni dérouler un drawer, ni cliquer un onglet.

**Why this priority** : C'est le mode dominant d'usage (lecture > correction > tutorat) et c'est le bénéfice principal du desktop : voir question + DT côte-à-côte économise des allers-retours visuels et accélère le travail.

**Independent Test** : Connecter un élève sur un écran ≥1024px, ouvrir une question avec DT référencé, vérifier que la question est dans la moitié gauche et le DT dans la moitié droite, sans interaction.

**Acceptance Scenarios** :

1. **Given** un élève connecté sur un écran ≥1024px, **When** il ouvre une question référençant DT1, **Then** la question s'affiche dans la colonne gauche (50%) et le DT1 dans la colonne droite (50%), tous deux visibles sans scroll horizontal.
2. **Given** un élève sur un écran <1024px, **When** il ouvre la même question, **Then** le layout mobile actuel s'applique (colonne unique, DT en partial inline) sans modification.
3. **Given** un élève sur desktop visualisant une question référençant plusieurs DT (par exemple "DT1, DT2"), **When** la page charge, **Then** le viewer affiche le PDF DT du sujet et un bandeau référence liste tous les DT/DR cités par la question.
4. **Given** un élève sur desktop, **When** le sujet n'a aucun PDF DT attaché OU la question ne référence aucun DT, **Then** la colonne droite affiche un état vide (placeholder neutre) sans casser le layout 50/50.

---

### User Story 2 — Consultation de la correction en desktop (Priority: P1)

Après avoir répondu, l'élève accède à la correction. Sur desktop, il voit à gauche les cartes de correction (réponse + calcul + data hints) et à droite le DT reste affiché, avec un badge indiquant la donnée utile sur la page concernée.

**Why this priority** : La correction est le second pilier du parcours élève. La continuité visuelle (DT toujours visible) renforce l'apprentissage : l'élève voit immédiatement où trouver la donnée mentionnée dans les data hints.

**Independent Test** : Marquer une question comme répondue, naviguer vers l'écran correction, vérifier la présence simultanée des cartes correction (gauche) et du DT avec son badge "donnée utile" (droite).

**Acceptance Scenarios** :

1. **Given** un élève sur desktop ayant répondu à une question, **When** il consulte la correction, **Then** la colonne gauche affiche : carte verte (réponse finale), carte verte (détail calcul), carte jaune outlined (data hints) — dans cet ordre.
2. **Given** un élève en correction sur desktop, **When** l'`Answer` de la question possède des `data_hints` non vides, **Then** la colonne droite affiche le PDF DT du sujet avec un bandeau "Donnée utile" en haut listant le `source` et le `location` du premier data hint pertinent.
3. **Given** un élève sur écran <1024px en correction, **When** il accède à la correction, **Then** le layout mobile actuel s'applique sans modification.

---

### User Story 3 — Tutorat Tibo en desktop (Priority: P1)

L'élève déclenche Tibo depuis le bouton de la navbar. Sur desktop, le drawer Tibo remplace la colonne DT droite : 60% chat à gauche, 40% panneau contexte (rappel question + objectif partie) à droite. L'élève peut dialoguer avec Tibo sans perdre de vue la question.

**Why this priority** : C'est la feature signature et le contexte question pendant le chat est le différenciateur pédagogique. Sans contexte visible, le tutorat redevient un chat générique.

**Independent Test** : Ouvrir une question sur desktop, cliquer le bouton "Tibo" de la navbar, vérifier que le chat occupe 60% (à gauche) et un panneau contexte question 40% (à droite), tout en gardant la navbar accessible.

**Acceptance Scenarios** :

1. **Given** un élève sur desktop sur une question, **When** il clique le bouton Tibo dans la navbar, **Then** le drawer s'ouvre **par-dessus la colonne DT droite** (overlay `position: fixed top-0 right-0`, largeur ~60vw max 900px), le chat occupe ~60% du drawer (à gauche dans le drawer) et un panneau contexte ~40% (à droite dans le drawer) ; la colonne question gauche initiale (sous le drawer) reste visible si l'écran est assez large.
2. **Given** un élève sur écran <1024px, **When** il déclenche Tibo, **Then** le drawer full-screen actuel s'applique sans modification.
3. **Given** un élève sur desktop avec Tibo ouvert, **When** il ferme Tibo, **Then** le drawer disparaît (transform `translate-x-full`), la colonne DT redevient pleinement visible, sans rechargement de page.

---

### User Story 4 — Navigation entre parties et questions en desktop (Priority: P2)

Sur desktop, la sidebar des parties (présente en mobile et dans le layout desktop actuel) n'est plus permanente. L'élève accède à la navigation via un bouton "Parties" dans la navbar, qui ouvre un popover listant les parties et leurs questions.

**Why this priority** : Indispensable pour la liberté de saut entre questions (cf. mode relecture, sujet complété), mais secondaire pour le flux linéaire question-après-question qui est piloté par les boutons précédent/suivant.

**Independent Test** : Cliquer le bouton "Parties" dans la navbar desktop, vérifier qu'un popover/drawer s'ouvre avec la liste des parties et questions ; cliquer une question pour y naviguer.

**Acceptance Scenarios** :

1. **Given** un élève sur desktop, **When** il clique "Parties" dans la navbar, **Then** un popover/drawer s'ouvre listant toutes les parties du sujet et leurs questions, avec marquage des questions répondues.
2. **Given** un élève avec le popover ouvert, **When** il clique sur une question, **Then** il est navigué vers cette question, le popover se ferme.
3. **Given** un élève sur écran <1024px, **When** il consulte la navigation, **Then** la sidebar/drawer mobile actuel s'affiche sans modification (inchangé).

---

### Edge Cases

- **Sujet sans PDF DT attaché OU question sans `dt_references`** : La colonne droite affiche un état neutre (message minimal) ; le layout 50/50 reste équilibré.
- **Question avec plusieurs DT cités (`dt_references = ["DT1", "DT2"]`)** : Le bandeau référence liste tous les codes dans l'ordre fourni ; le PDF affiché reste le DT unique du sujet (`Subject.dt_file`).
- **Data hints sans champ `source` correspondant à un DT** : Le bandeau "donnée utile" affiche le `location` brut sans préfixe DT spécifique.
- **Sidebar parties + drawer Tibo ouverts simultanément** : Les deux sont des overlays `position: fixed` (sidebar à gauche, drawer à droite). Pour éviter la cacophonie visuelle, un seul overlay actif à la fois (ouvrir Tibo ferme Parties et inversement, via événements DOM customs `overlay:open`/`overlay:close`).
- **Redimensionnement fenêtre** (≥1024 → <1024 ou inverse) en cours de session : La page applique le bon layout au rechargement / au resize via media queries CSS ; pas de gestion JS spéciale requise pour MVP.
- **Question DT marqué `filled_file` (DR corrigé)** : N'est visible qu'en mode correction ; en lecture, seul le DR vierge est dans la colonne droite.
- **Élève sans Tibo actif (clé API absente)** : Le bouton Tibo dans la navbar est désactivé ou affiche un tooltip vers les réglages — comportement identique au mobile actuel.
- **Question avec énoncé très court** : Carte question gauche garde sa largeur 50%, ne se rétrécit pas — gap visuel acceptable.
- **DT avec PDF lourd (>5MB)** : Iframe PDF prend son temps à charger ; un état de chargement neutre s'affiche dans la colonne droite.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001** : Le système MUST afficher un layout split 50/50 (question | DT viewer) sur la page `questions#show` à partir d'une largeur d'écran de 1024px.
- **FR-002** : Le système MUST préserver le layout mobile actuel (colonne unique + sidebar drawer + DT partial inline) pour les écrans <1024px sans modification.
- **FR-003** : Le système MUST afficher une top navbar sur desktop contenant : logo "DekatjeBakLa", tabs (Mes sujets, Progression, Réglages), bouton "Parties", bouton Tibo, avatar élève.
- **FR-004** : Le système MUST afficher un breadcrumb sous la navbar contenant Sujet › Partie › Question (numéro).
- **FR-005** : Le système MUST afficher la colonne droite (DT viewer) avec : viewer PDF du `Subject.dt_file` attaché, bandeau référence listant les `question.dt_references`, et bandeau "donnée utile" si applicable en mode correction.
- **FR-006** : Le système MUST permettre à l'élève d'ouvrir un popover/drawer "Parties" depuis la navbar desktop, listant toutes les parties et questions du sujet courant, avec état répondu/non-répondu.
- **FR-007** : Le système MUST permettre à l'élève de cliquer une question dans le popover Parties pour y naviguer ; la navigation ferme le popover.
- **FR-008** : Le système MUST, en mode correction sur desktop, afficher dans la colonne gauche les cartes : réponse (vert), détail calcul (vert outlined), data hints (jaune outlined), dans cet ordre.
- **FR-009** : Le système MUST, en mode correction sur desktop, afficher dans la colonne droite le PDF DT du sujet avec un bandeau "Donnée utile" affichant le `source` et le `location` du premier `Answer.data_hints` (les data hints sont `[{source, location}]`, sans numéro de page).
- **FR-010** : Le système MUST permettre à l'élève d'ouvrir Tibo depuis la navbar desktop ; le drawer remplace la colonne DT droite et présente chat (60% gauche) + panneau contexte (40% droite, contenant rappel question et objectif partie).
- **FR-011** : Le système MUST permettre à l'élève de fermer Tibo en desktop ; la colonne droite revient au DT viewer sans rechargement.
- **FR-012** : Le système MUST garantir qu'un seul overlay (Parties popover OU Tibo drawer) soit actif à la fois en desktop.
- **FR-013** : Le système MUST conserver les fonctionnalités existantes du mode lecture / correction / tutorat sans régression (boutons précédent/suivant, accès correction, fermeture drawer, etc.).
- **FR-014** : Le système MUST afficher la colonne droite avec un état neutre/vide quand `Subject.dt_file` n'est pas attaché OU `question.dt_references` est vide, en conservant le ratio 50/50.

### Non-Functional Requirements

- **NFR-001** : Le système MUST satisfaire l'accessibilité clavier : navbar tabbable, popover Parties et drawer Tibo ouvrable/fermable via clavier, focus trap dans les overlays.
- **NFR-002** : Le système MUST respecter la palette Radical existante (tokens `rad-*` définis dans `tailwind.config`) — aucune nouvelle couleur introduite.
- **NFR-003** : Le système MUST charger la page desktop sans nouvelle requête réseau supplémentaire vs. le layout mobile (les données question + DT sont déjà fetchées).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : Un élève qui ouvre une question sur un écran ≥1024px voit le contenu de la question et du DT principal simultanément sans aucune interaction supplémentaire (scroll, click).
- **SC-002** : Un élève qui consulte la correction sur desktop accède aux trois cartes (réponse, calcul, data hints) et au DT avec badge "donnée utile" sans changer d'écran ni dérouler.
- **SC-003** : Un élève qui dialogue avec Tibo sur desktop conserve la visibilité de la question (rappel) et de l'objectif partie tout au long de la conversation.
- **SC-004** : Aucune régression sur les specs feature mobile existantes (`student_*` + `questions#show` + `corrections` + drawer Tibo) — 100% des tests existants passent en CI.
- **SC-005** : Les nouveaux specs feature desktop (3 user stories US1, US2, US3) passent en CI sur le viewport ≥1024px.
- **SC-006** : Un élève peut naviguer entre toutes les questions du sujet courant via le popover Parties en ≤3 clics depuis n'importe quelle question.

## Assumptions

- **Cible utilisateur** : Lycéens (Terminale STI2D, Martinique) utilisant principalement mobile ; usage desktop minoritaire mais réel (révisions à domicile sur ordinateur familial).
- **Viewport cible** : Le design est dessiné à 1280×820 (laptop standard). Le breakpoint `lg:` (1024px) couvre cette cible et étend aux écrans plus larges (jusqu'à FullHD).
- **Drawer Tibo desktop** : La structure HTML du drawer existante (mobile) est conservée ; seul le styling/positionnement change via media queries `lg:`.
- **Sidebar parties existante** : Le markup ERB de la sidebar (`_sidebar.html.erb`) est réutilisé tel quel, repositionné en popover via classes Tailwind / Stimulus.
- **DT viewer** : Réutilise l'iframe PDF existante (`Subject.dt_file` est un `has_one_attached` — un seul PDF par sujet, pas de modèle `TechnicalDocument` séparé). Les onglets DT/DR du design d'origine sont remplacés par un bandeau-liste des références citées par la question.
- **data_hints** : Structure `[{source, location}]` (JSONB), sans champ `page`. Le bandeau "donnée utile" affiche `source · location` textuellement.
- **Navbar desktop** : Nouveau composant (la précédente `NavBarComponent` a été supprimée par PR #79 selon mémoire). Implémentée dans `layouts/student.html.erb` sous condition `lg:` (cachée en mobile).
- **Pas de gestion JS du resize** : Les bascules mobile↔desktop pendant une session se font via CSS media queries pures. Les overlays JS (popover, drawer) se contentent d'être inertes en mobile.
- **Conformité RGPD/Constitution** : Aucune nouvelle donnée collectée ; aucune modification du modèle de données ; aucun nouvel appel IA.
- **Pas de nouvelle dépendance frontend** : Implémentation 100% Stimulus + Tailwind existants.
- **Pas de migration DB** : Aucun changement schema requis.

## Out of Scope

- Refonte du layout `subjects/index` desktop (déjà mergée par PR #79).
- Refonte du layout teacher (slice B, PR séparée ultérieure — déjà identifiée dans bundle design).
- Refonte de la navbar mobile (supprimée par PR #79, non réintroduite).
- Mode sombre desktop (le design ne le couvre pas explicitement ; report post-MVP si requis).
- Surlignage / annotations PDF (post-MVP, déjà noté dans CLAUDE.md).
- Stats progression élève en navbar desktop (la tab "Progression" pointe vers la page existante, ne fait l'objet d'aucune refonte).
- Tests de régression visuelle (screenshots) — non couverts par la stack Capybara actuelle.
- Séparation du PDF DT en documents distincts avec onglets DT1/DT2/DT3 — nécessiterait un modèle `TechnicalDocument` qui n'existe pas en prod (post-MVP, mentionné dans CLAUDE.md).
- Extraction du numéro de page depuis `data_hints[].location` (champ texte libre, parsing fragile).

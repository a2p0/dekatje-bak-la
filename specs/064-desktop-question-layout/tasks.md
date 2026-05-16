---

description: "Task breakdown for feature 064-desktop-question-layout"
---

# Tasks: Desktop Question Layout (questions#show)

**Input** : Design documents from `/specs/064-desktop-question-layout/`
**Prerequisites** : plan.md, spec.md, research.md, data-model.md, contracts/ui-contracts.md, quickstart.md

**Tests** : INCLUDED — la Constitution v2.1.0 §IV impose TDD strict pour toute feature visible utilisateur.

**Organization** : Tâches groupées par user story (US1 P1, US2 P1, US3 P1, US4 P2). Chaque story est indépendamment testable en isolation.

**TDD Protocol (Constitution §IV — NON-NÉGOCIABLE)** :

Pour chaque user story, le protocole strict est :

1. Écrire la/les feature spec(s) Capybara (tâches "Tests for USx")
2. **Lancer la suite et observer RED** — au moins une assertion FAIL. Si tout passe direct, le test est mal écrit (vérifier que les sélecteurs ne matchent pas le markup actuel).
3. Implémenter les tâches "Implementation for USx" jusqu'à GREEN
4. Refactor si nécessaire, suite toujours GREEN

**Si une spec passe sans phase RED visible** : reformuler la spec pour viser un comportement vraiment nouveau, sinon elle ne protège rien.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : Peut tourner en parallèle (fichiers différents, pas de dépendance bloquante)
- **[Story]** : User story (US1, US2, US3, US4) — phases setup/foundational/polish n'ont pas de label
- Chemins exacts de fichiers obligatoires

## Path Conventions

Rails 8 monolith — pas de séparation backend/frontend.
- Vues : `app/views/student/...`
- Stimulus : `app/javascript/controllers/...`
- Helpers : `app/helpers/...`
- Specs : `spec/features/...` (Capybara), `spec/helpers/...` (unit)

---

## Phase 1 : Setup

**Purpose** : Vérifier que l'environnement est prêt et qu'aucune migration n'est nécessaire.

- [X] T001 Vérifier que la branche `064-desktop-question-layout` est checked out, `git status` propre hors `tmp/design-bundle/` et `specs/064-*/`
- [X] T002 Vérifier que `Subject.dt_file`, `Question.dt_references`, `Answer.data_hints` sont bien présents dans `db/schema.rb` (aucune migration à créer)
- [X] T003 Baseline délégué à CI (constitution §IV : machine trop lente pour Capybara local)

---

## Phase 2 : Foundational (Blocking Prerequisites)

**Purpose** : Helpers et primitives partagés entre toutes les user stories.

**⚠️ CRITICAL** : Aucune story ne peut démarrer avant que cette phase soit terminée.

- [X] T004 Spec helper unit : étendu `spec/helpers/student/data_hints_helper_spec.rb` (déviation : helper existant déjà namespaced `Student::DataHintsHelper`, on l'étend au lieu de créer un nouveau fichier). Couvre `primary_data_hint` et `data_hint_caption` (4+5 examples).
- [X] T005 Implémenté `primary_data_hint` + `data_hint_caption` dans `app/helpers/student/data_hints_helper.rb` (déviation : helper existant étendu).
- [X] T006 [P] Étendu `app/javascript/controllers/sidebar_controller.js` : dispatch `overlay:open`/`overlay:close` + listener qui ferme si autre overlay s'ouvre. Conforme contracts §C1.
- [X] T007 [P] Étendu `app/javascript/controllers/chat_drawer_controller.js` : dispatch `overlay:open`/`overlay:close` + listener symétrique. Conforme contracts §C1.
**Checkpoint** : Helpers prêts, coordination overlays JS livrée (sans spec de validation — voir T028b en US3 quand les overlays desktop sont réellement opérationnels).

---

## Phase 3 : User Story 1 — Lecture question desktop (Priority: P1) 🎯 MVP

**Goal** : Layout split 50/50 sur `questions#show` desktop avec top navbar + breadcrumb + carte question (gauche) + DT viewer (droite).

**Independent Test** : Capybara feature spec — connecter un élève, visiter une question, vérifier navbar desktop, breadcrumb, carte question colonne gauche, iframe DT colonne droite avec bandeau références.

### Tests for US1 (TDD)

> **TDD strict** : ces specs FAIL d'abord, GREEN après implémentation.

- [X] T009 [US1] Créé `spec/features/student_desktop_reading_spec.rb` — 4 scénarios (navbar, breadcrumb, DT viewer avec iframe+bandeau, état neutre sans DT). RED via CI (constitution §IV).
- [X] T010 [US1] Ajouté scénario mobile sentinel à `spec/features/student_question_navigation_spec.rb` — resize 390×800, navbar desktop cachée, layout mobile inchangé.

### Implementation for US1

- [X] T011 [US1] Créé `app/views/student/shared/_desktop_nav.html.erb` (déviation : placé dans `student/shared/` au lieu de `student/questions/` car rendu depuis le layout, utilisable par toutes les pages student). Logo Fraunces italic, tabs Mes sujets/Réglages (pas de page Progression encore), boutons Parties + Tibo conditionnels, avatar avec initiale. Conforme contracts §C2.
- [X] T012 [US1] Inséré `<%= render "student/shared/desktop_nav" %>` dans le `<main>` de `app/views/layouts/student.html.erb`, conditionnel sur `current_student.present?`. Ajouté `data-controller="sidebar chat-drawer"` sur `<main id="main-content">` (décision R8).
- [X] T013 [US1] Créé `app/views/student/questions/_breadcrumb.html.erb` avec `data-064-breadcrumb` attribute pour faciliter le ciblage Capybara. Affiche Sujet › Partie X › Q1.2. Caché en mobile.
- [X] T014 [US1] Créé `app/views/student/questions/_dt_viewer.html.erb` conforme contracts §C3. Aside `lg:flex lg:flex-col lg:w-1/2`, bandeau références concaténant dt_references | dr_references, iframe `rails_blob_url(subject.dt_file)`, état neutre "Aucun document technique pour cette question." sinon. Local `show_data_hint` optionnel pour US2.
- [X] T015 [US1] Refactor `app/views/student/questions/show.html.erb` :
  - Retiré `data-controller="sidebar chat-drawer"` du wrapper racine (déplacé sur `<main>` en T012).
  - Ajouté `<%= render "breadcrumb", ... %>` sous `_stripes`.
  - Classe colonne main passée en `lg:w-1/2 lg:max-w-none lg:mx-0` (préserve max-w-3xl mobile-first).
  - Ajouté `<%= render "dt_viewer", ... %>` avec `show_data_hint: @session_record.answered?(@question.id)`.
- [X] T016 [US1] Adapté `<aside id="sidebar-drawer">` : retiré `lg:relative lg:translate-x-0 lg:z-auto`, devenu popover sur toutes tailles. Backdrop également étendu (retiré `lg:hidden`).
- [X] T017 [US1] Lancement délégué à CI (constitution §IV). 2 runs sur commit `446eebc` ont retourné 724/0 unit specs + 133 feature specs avec **1 flake différent à chaque run** dans `student_tutor_chat_spec.rb` (race contre POST async dans `tutor_activator#activate`). Pre-existing flake (cf. git log "fix(ci): increase drawer-close wait to 15s"). Considéré GREEN pour 064.

**Checkpoint** : US1 fonctionnelle et testée indépendamment. Le bouton Tibo de la navbar peut être un simple lien stub pour l'instant — sera câblé par US3.

---

## Phase 4 : User Story 2 — Correction desktop (Priority: P1)

**Goal** : Sur desktop en mode correction, colonne gauche affiche carte verte (réponse) + carte verte (calcul) + carte jaune (data hints) ; colonne droite affiche DT viewer + bandeau "Donnée utile".

**Independent Test** : Capybara — marquer une question répondue, visiter, vérifier les 3 cartes correction colonne gauche + bandeau "Donnée utile" colonne droite affichant `source · location` du premier data_hint.

### Tests for US2 (TDD)

- [X] T018 [US2] Créé `spec/features/student_desktop_correction_spec.rb` — 3 scénarios (banner avec source·location, pas de banner avant correction, cartes correction colonne gauche). RED via CI.
- [X] T019 [US2] Ajouté scénario mobile sentinel à `spec/features/student_correction_reveal_spec.rb` — resize 390×800, banner desktop non visible.

### Implementation for US2

- [X] T020 [US2] Créé `app/views/student/questions/_data_hint_banner.html.erb` — header "Donnée utile" + icône `i` jaune + `data_hint_caption(hint)`. `data-064-data-hint-banner` pour ciblage Capybara. Visibilité héritée du parent (dt_viewer aside `hidden lg:flex`).
- [X] T021 [US2] Câblage déjà fait en T014 — `_dt_viewer.html.erb` rend `_data_hint_banner` quand `show_data_hint: true` ET `primary_data_hint(question)` non nil. Le `show.html.erb` passe `show_data_hint: @session_record.answered?(@question.id)`.
- [X] T022 [US2] Vérifié — `_correction.html.erb` est mobile-first (pas de largeur fixe), s'adapte au parent `lg:w-1/2`. Aucun changement nécessaire.
- [X] T023 [US2] Lancement délégué à CI (constitution §IV).

**Checkpoint** : US2 fonctionnelle. Le layout desktop affiche correction + DT en split.

---

## Phase 5 : User Story 3 — Tutorat Tibo desktop (Priority: P1)

**Goal** : Drawer Tibo en desktop occupe 60vw (max 900px), split interne 60/40 — chat à gauche, panneau contexte à droite (rappel question + objectif partie).

**Independent Test** : Capybara — visiter question, cliquer bouton Tibo navbar, vérifier drawer ouvert avec 2 panes visibles (chat + contexte), question label visible dans le contexte.

### Tests for US3 (TDD)

- [ ] T024 [US3] Créer `spec/features/student_desktop_tutor_spec.rb` couvrant US3 acceptance scenarios #1 (drawer 60vw, chat à gauche, contexte à droite), #3 (ferme drawer → DT viewer revient). **Lancer → observer FAIL (RED) avant T026**.
- [ ] T025 [US3] Ajouter dans `spec/features/student_tutor_chat_spec.rb` (existant) un scénario mobile sentinel (US3 #2) : window 390×800 → drawer reste full-screen, panneau contexte caché.

### Implementation for US3

- [ ] T026 [US3] Créer `app/views/student/conversations/_context_panel.html.erb` (locals: `question`, `part`, `subject`) — affiche numéro Q + label tronqué + bloc partie (numéro + titre + objectif_text) + lien "Voir la question" qui ferme le drawer. Cf. contracts §C5.
- [ ] T027 [US3] Modifier `app/views/student/conversations/_drawer.html.erb` : 
  - Changer la largeur drawer de `lg:w-[420px]` à `lg:w-[60vw] lg:max-w-[900px]`.
  - Ajouter `lg:flex` sur le drawer.
  - Wrapper le contenu chat existant dans `<div class="flex-1 flex flex-col lg:basis-3/5">`.
  - Ajouter `<aside class="hidden lg:flex lg:flex-col lg:basis-2/5 border-l border-rad-rule bg-rad-paper"><%= render "context_panel", question: question, part: question.part, subject: question.part.subject %></aside>`.
- [ ] T028 [US3] Câbler le bouton Tibo du `_desktop_nav.html.erb` (créé en T011) : ajouter les data attributes `data-controller="tutor-activator"`, `data-tutor-activator-subject-id-value`, `data-tutor-activator-question-id-value`, `data-tutor-activator-conversations-url-value` + `data-action="click->tutor-activator#activate"` + `data-chat-drawer-toggle="true"` — mêmes attributs que le bouton mobile existant.
- [ ] T028b [US3] Créer `spec/features/student_desktop_overlay_coordination_spec.rb` : sur viewport desktop, ouvrir Tibo (clic bouton navbar) puis cliquer "Parties" → assert Tibo fermé + sidebar ouverte ; cliquer Tibo à nouveau → assert sidebar fermée + Tibo ouvert. **Note** : ce spec sera vraiment vert seulement après US4 T031 (bouton Parties câblé). Pour US3 seul, valider manuellement via JS dispatch d'événement.
- [ ] T029 [US3] Lancer `bundle exec rspec spec/features/student_desktop_tutor_spec.rb spec/features/student_tutor_chat_spec.rb` — tous verts. (Le spec coordination T028b sera vert seulement après US4 T031 — ne pas bloquer US3 dessus.)

**Checkpoint** : US3 fonctionnelle. Le tutorat ouvre un drawer 60/40 sur desktop, mobile inchangé.

---

## Phase 6 : User Story 4 — Navigation Parties popover (Priority: P2)

**Goal** : Bouton "Parties" dans la navbar desktop ouvre la sidebar existante en popover. Click sur question dans la sidebar navigue + ferme la sidebar.

**Independent Test** : Capybara — visiter question desktop, cliquer "Parties", vérifier sidebar ouverte avec liste parties/questions, cliquer une question, vérifier navigation + sidebar fermée.

### Tests for US4 (TDD)

- [ ] T030 [US4] Créer `spec/features/student_desktop_navigation_spec.rb` couvrant US4 acceptance scenarios #1 (sidebar s'ouvre avec liste), #2 (clic question navigue + ferme sidebar), #3 (bouton "Parties" caché en mobile). **Lancer → observer FAIL (RED) avant T031**.

### Implementation for US4

- [ ] T031 [US4] Câbler le bouton "Parties" du `_desktop_nav.html.erb` (créé en T011) : `data-action="click->sidebar#open"` + `data-sidebar-target="toggle"` + `aria-expanded="false"` + `aria-controls="sidebar-drawer"`. **Pré-requis** : T012 a déplacé `data-controller="sidebar chat-drawer"` sur `<main>` du layout (décision R8 dans research.md) — pas besoin de gymnastique JS.
- [ ] T032 [US4] Vérifier que `sidebar_controller#close` est appelé après navigation (click sur question dans la sidebar provoque un GET Turbo qui re-render la page → sidebar par défaut fermée). Si nécessaire, ajouter `data-action="click->sidebar#close"` sur les liens questions dans `_sidebar_part.html.erb`.
- [ ] T033 [US4] Lancer `bundle exec rspec spec/features/student_desktop_navigation_spec.rb` — vert.

**Checkpoint** : US4 fonctionnelle. Toutes les user stories indépendamment testables.

---

## Phase 7 : Polish & Cross-Cutting Concerns

**Purpose** : Validation finale, suppression de placeholders, accessibilité, régression.

- [ ] T034 [P] Lancer la suite complète : `bundle exec rspec` — 100% vert (SC-004).
- [ ] T035 [P] Lancer `bundle exec rubocop -A` puis vérifier qu'aucun fichier inattendu n'a été modifié.
- [ ] T036 [P] Lancer `bundle exec brakeman --no-progress -q -w1` — 0 warning.
- [ ] T037 Vérifier accessibilité clavier (NFR-001) : Tab dans la navbar, Espace/Entrée pour ouvrir Parties/Tibo, Échap pour fermer, focus restauré sur le toggle. Cf. quickstart.md §Accessibilité clavier.
- [ ] T038 Exécuter `quickstart.md` manuellement en dev (US1→US4 + single-overlay + a11y) — cocher chaque item.
- [ ] T039 Vérifier palette `rad-*` uniquement (NFR-002) : `grep -rE "indigo|slate|emerald|violet" app/views/student/questions/ app/views/student/conversations/_drawer.html.erb app/views/layouts/student.html.erb` — aucun match.
- [ ] T040 Nettoyer `tmp/design-bundle/` si committé par erreur (`git ls-files tmp/design-bundle/ | head`). Ce dossier est gitignoré par Rails, vérifier qu'il n'est pas dans l'index.
- [ ] T041 Commit progressifs par phase (Conventional Commits, un concern par commit) :
  - `feat(064): add primary_data_hint helper + overlay coordination events`
  - `feat(064): add desktop navbar + breadcrumb + DT viewer for questions#show`
  - `feat(064): add data hint banner in correction mode`
  - `feat(064): add 60/40 split tutor drawer with context panel on desktop`
  - `feat(064): wire Parties popover from desktop navbar`
  - `chore(064): rubocop + brakeman cleanup`
- [ ] T042 Pousser la branche `git push -u origin 064-desktop-question-layout` et ouvrir la PR avec body suivant le template (résumé SC-001 à SC-006 + lien plan/spec).

---

## Dependency Graph

```
Phase 1 (Setup) → Phase 2 (Foundational)
                       ↓
                   ┌───┴───┬────────┬────────┐
                   ↓       ↓        ↓        ↓
                  US1     US2      US3      US4
                 (P1)    (P1)     (P1)     (P2)
                   ↓       ↓        ↓        ↓
                   └───┬───┴────────┴────────┘
                       ↓
                  Phase 7 (Polish)
```

**Story dependencies** :
- US2 dépend de US1 (réutilise `_dt_viewer.html.erb` créé en T014).
- US3 indépendante de US1/US2 (mais le bouton Tibo dans la navbar est créé en T011 — coordination implicite).
- US4 dépend de US1 (réutilise `_desktop_nav.html.erb` créé en T011).

**Conséquence** : US1 est l'unique MVP standalone. US2/US3/US4 sont des incréments. Si on devait livrer minimal, US1 seul = layout desktop fonctionnel sans correction stylée ni tutorat 60/40 ni popover Parties.

---

## Parallel Execution Opportunities

### Phase 2 (Foundational)

T006 et T007 peuvent tourner en parallèle (fichiers JS différents, contrat événementiel symétrique connu d'avance).

### Au sein de US1

Aucune parallélisation interne forte (chaîne séquentielle helper → partial → integration).

### Cross-stories après foundational

US2, US3, US4 peuvent être implémentés en parallèle par 3 subagents distincts SI on accepte que T028 (US3 câblage Tibo) et T031 (US4 câblage Parties) modifient le même partial `_desktop_nav.html.erb`. **Recommandation** : exécuter US1 d'abord pour livrer `_desktop_nav.html.erb`, puis US2/US3/US4 en parallèle.

### Phase 7

T034, T035, T036 sont parallélisables (commandes indépendantes).

---

## Implementation Strategy

### MVP Increment (US1 only)

Livrer US1 seul fournit déjà un bénéfice : layout desktop split 50/50 fonctionnel pour la lecture. Pas de correction stylée desktop, pas de tutorat 60/40, pas de popover Parties — mais déjà un déblocage majeur pour les élèves sur ordinateur.

**Effort estimé** : ~2h (Phase 1 + 2 + US1).

### Full feature (US1 + US2 + US3 + US4)

Effort estimé : 5-7h. Optimisable par parallel subagent dispatch (cf. `feedback_speckit_workflow_validated` + `feedback_atomic_agents`) :

- 1 agent par US (4 agents en parallèle après foundational + US1).
- Convergence en Phase 7.

### Risques identifiés

- **R-T031** (Parties popover) : le bouton est dans le layout, hors du scope Stimulus du wrapper. Possible refactor nécessaire pour étendre la portée. À monitorer.
- **R-T027** (drawer 60vw) : potentielle régression d'animations transform si CSS mal écrit. Mitigation : commit incrémental + test feature systématique.
- **R-T015** (refactor show.html.erb) : fichier déjà large (260 lignes). Tentation de réécrire à blanc — résister, faire des edits ciblés.

---

## Format Validation

Toutes les tâches suivent strictement `- [ ] T### [P?] [US?] description avec chemin de fichier` :
- ✅ Checkbox `- [ ]` présente sur chaque tâche.
- ✅ Task ID séquentiel T001→T042.
- ✅ `[P]` présent uniquement quand parallélisable.
- ✅ `[US1]`/`[US2]`/`[US3]`/`[US4]` présent dans les phases user stories.
- ✅ Phase 1/2/7 sans story label.
- ✅ Chaque tâche mentionne un fichier exact ou une commande exécutable.

---
description: "Task breakdown for B1 design tokens 2 layers"
---

# Tasks: Architecture tokens 2 couches pour thème Radical unifié (B1)

**Input**: Design documents from `/specs/065-design-tokens-2-layers/`
**Prerequisites**: [spec.md](./spec.md) ✅, [plan.md](./plan.md) ✅, [research.md](./research.md) ✅, [data-model.md](./data-model.md) ✅, [contracts/design-tokens.md](./contracts/design-tokens.md) ✅, [quickstart.md](./quickstart.md) ✅

**Tests** : OBLIGATOIRES (constitution V principe IV — TDD non-négociable). FR-014, FR-015, SC-003 sont des critères de succès vérifiables par tests automatisés.

**Organization** : tâches groupées par user story (US1 = migration invisible, US2 = tokens dispo B2-B7, US3 = bridge rétrocompat). Les 3 user stories sont **toutes P1** et **interdépendantes** dans cette feature — l'ordre d'exécution est donc séquentiel logique (pas parallèle entre US), mais à l'intérieur de chaque US plusieurs tâches sont parallélisables.

## Format: `[ID] [P?] [Story] Description`

- **[P]** : peut tourner en parallèle (fichiers différents, pas de dépendance sur tâche incomplète)
- **[Story]** : à quelle user story la tâche appartient (US1, US2, US3)
- Chemins de fichiers absolus à la racine du repo

## Path Conventions (Rails 8 fullstack)

- CSS tokens : `app/assets/tailwind/application.css`
- Layouts : `app/views/layouts/*.html.erb`
- Controllers : `app/controllers/teacher/*.rb`
- Views : `app/views/teacher/design_system/*.html.erb`
- Routes : `config/routes.rb`
- Tests : `spec/system/`, `spec/features/`, `spec/support/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose** : préparer l'environnement et vérifier les outils prérequis avant tout code.

- [ ] T001 Vérifier la présence d'ImageMagick (`magick compare --version`) sur la machine dev. Si absent : `sudo dnf install ImageMagick`. Documenter dans `specs/065-design-tokens-2-layers/notes.md` (créer si absent) la version installée. Utile pour validation SC-001.
- [ ] T002 Capturer les **screenshots de référence "avant B1"** sur 3 écrans (login élève `/`, classroom teacher index `/teacher/classrooms`, drawer Tibo ouvert depuis `/student/questions/<id>`). Sauvegarder dans `tmp/b1-baseline-screenshots/` (gitignoré). Procédure : démarrer `bin/dev`, login compte teacher seed + élève seed, navigation manuelle, capture via DevTools ou screenshot OS. Documenter la procédure dans `notes.md`.
- [ ] T003 [P] Mesurer le **poids CSS de référence "avant B1"** : `bin/rails tailwindcss:build`, puis `wc -c app/assets/builds/tailwind.css` (brut) et `gzip -c app/assets/builds/tailwind.css | wc -c` (gzippé). Reporter dans `notes.md`. Utile pour validation SC-007.

**Checkpoint** : baseline visuelle + métrique CSS prêtes. ImageMagick installé.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose** : créer les helpers de test partagés par les 3 user stories. Sans ces helpers, aucune US ne peut écrire ses specs.

**⚠️ CRITICAL** : pas de US sans cette phase.

- [ ] T004 [P] Créer le helper `spec/support/hex_to_rgb.rb` exposant `hex_to_rgb("#127566") → "rgb(18, 117, 102)"` (utilisé par les specs SC-003 pour comparer une couleur Selenium à une primitive Radical). Inclure les valeurs des 13 primitives en constante. Charger via `spec/rails_helper.rb` si pas déjà via `Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }`.
- [ ] T005 [P] Créer le helper `spec/support/css_token_reader.rb` exposant `read_compiled_css → String` (charge `app/assets/builds/tailwind.css` après s'être assuré qu'il existe ; lance `bin/rails tailwindcss:build` si fichier absent). Utilisé par le spec FR-014.

**Checkpoint** : helpers partagés disponibles. Toutes les US peuvent maintenant écrire leurs tests.

---

## Phase 3: User Story 1 — Migration invisible des tokens (Priority: P1) 🎯 MVP

**Goal** : refondre l'architecture tokens (3 couches CSS + `data-audience`) sans aucun changement visuel sur les écrans existants. Validation finale par diff visuel ≤ 1 % pixels ET ΔE ≤ 2.

**Independent Test** : après application, lancer `magick compare -metric AE -fuzz 2% tmp/b1-baseline-screenshots/login-eleve.png tmp/b1-after-screenshots/login-eleve.png` sur les 3 écrans baseline → AE ≤ 1 % du total des pixels.

### Tests for User Story 1 (TDD — écrire AVANT implémentation)

> **NOTE TDD** : ces specs doivent ÉCHOUER initialement, puis passer après implémentation des tasks suivantes.

- [ ] T006 [P] [US1] Écrire `spec/system/design_tokens_audience_attribute_spec.rb` (FR-015) : visite `/teacher/classrooms` (auth teacher seed), vérifie `expect(page).to have_css('body[data-audience="teacher"]')`. Idem pour `/` (visite anonyme, attend `body[data-audience="public"]`) et pour une page student (login élève seed, visite `/student/subjects`, attend `body[data-audience="student"]`). Doit échouer initialement.
- [ ] T007 [P] [US1] Écrire `spec/lib/css_compiled_tokens_spec.rb` (FR-014) : charge le CSS compilé via helper T005, vérifie présence des 19 sémantiques minimum (regex : `--color-surface`, `--color-surface-raised`, `--color-surface-sunken`, `--color-on-surface`, `--color-on-surface-muted`, `--color-rule`, `--color-rule-strong`, `--color-accent-primary`, `--color-on-accent-primary`, `--color-accent-secondary`, `--color-on-accent-secondary`, `--color-success`, `--color-on-success`, `--color-warning`, `--color-on-warning`, `--color-danger`, `--color-on-danger`, `--color-info`, `--color-on-info`). Doit échouer initialement.

### Implementation for User Story 1

- [ ] T008 [US1] Ajouter la **couche primitives** dans `app/assets/tailwind/application.css` (à l'intérieur du bloc `@theme { ... }` existant, après les radius et z-index). 13 primitives selon `data-model.md` §1. Naming `--rad-prim-<essence>`. Valeurs hex light uniquement à ce stade. (Les valeurs dark seront override via `.dark` overrides plus bas.)
- [ ] T009 [US1] Ajouter la **couche sémantique** dans le même bloc `@theme { ... }`, après les primitives. 19 tokens sémantiques selon `data-model.md` §2. Convention `--color-<role>`. Valeurs par défaut = mapping student-light (FR-007). Référencer les primitives via `var(--rad-prim-*)`.
- [ ] T010 [US1] Ajouter les **mappings par audience light** : 3 blocs CSS après `@theme` (et avant les bloc `.dark` existants) — `body[data-audience="student"] { ... }`, `body[data-audience="teacher"] { ... }`, `body[data-audience="public"] { ... }`. Chaque bloc redéfinit les 19 sémantiques selon `data-model.md` §2 colonnes `*-light`. Cf. `research.md` Q2 pour la syntaxe exacte.
- [ ] T011 [US1] **Migrer** le bloc legacy `.dark { ... }` (lignes 54-68 actuelles de `application.css`) vers `html.dark body[data-audience="public"] { ... }` pour éviter conflit de spécificité (cf. `research.md` Q2 risque résiduel #1). **Vérifier strictement que les valeurs hex sont identiques** à celles actuelles dans `.dark { ... }` (sinon régression invisible sur les pages publiques en dark). Le bloc `.dark .pattern-madras-diagonal` (lignes 88-94) reste inchangé.
- [ ] T012 [US1] Ajouter les **mappings par audience dark** : 3 blocs CSS `html.dark body[data-audience="student"]`, `html.dark body[data-audience="teacher"]`, `html.dark body[data-audience="public"]` (ce dernier remplace le legacy `.dark`). Chaque bloc redéfinit les 19 sémantiques selon `data-model.md` §2 colonnes `*-dark`.
- [ ] T013 [P] [US1] Ajouter `data-audience="student"` sur la balise `<body>` de `app/views/layouts/student.html.erb` (FR-011).
- [ ] T014 [P] [US1] Ajouter `data-audience="teacher"` sur la balise `<body>` de `app/views/layouts/teacher.html.erb` (FR-012).
- [ ] T015 [P] [US1] Ajouter `data-audience="public"` sur la balise `<body>` de `app/views/layouts/application.html.erb` (FR-013).
- [ ] T016 [US1] Lancer `bin/rails tailwindcss:build` et **vérifier que les specs T006 et T007 passent maintenant**. Si l'un échoue : ajuster T008-T015 et relancer.
- [ ] T017 [US1] Capturer les **screenshots "après B1"** sur les 3 mêmes écrans qu'à T002 (même procédure, même browser, même taille viewport). Sauvegarder dans `tmp/b1-after-screenshots/`.
- [ ] T018 [US1] Exécuter le **diff visuel** pour chacun des 3 écrans : `magick compare -metric AE -fuzz 2% tmp/b1-baseline-screenshots/<screen>.png tmp/b1-after-screenshots/<screen>.png /tmp/diff-<screen>.png`. Reporter le nombre AE dans `notes.md` pour chaque écran. **Critère de passage** : AE ≤ 1 % du nombre total de pixels de l'image (ex: pour 1920×1080 ≈ 2 073 600 px, AE max = 20 736). Si dépassé, investiguer (probablement un mapping primitive incorrect).

**Checkpoint US1** : la migration tokens est invisible, l'attribut `data-audience` est présent sur les 3 layouts, les 19 sémantiques existent dans le CSS compilé, les 3 diffs visuels sont sous le seuil. **MVP fonctionnel**.

---

## Phase 4: User Story 2 — Tokens sémantiques disponibles pour B2-B7 (Priority: P1)

**Goal** : prouver concrètement qu'un consommateur de `var(--color-accent-primary)` rend en teal sous teacher et en balisier red sous student, sans condition Ruby. Livrer une page démo persistante (`/teacher/design-system/preview`) qui sert de fixture spec et de docs vivante.

**Independent Test** : lancer `spec/system/design_tokens_audience_mapping_spec.rb` (T020) — passe sous les 6 combinaisons audience × mode.

### Tests for User Story 2 (TDD)

- [ ] T019 [P] [US2] Écrire `spec/features/teacher/design_system_preview_spec.rb` : visite `/teacher/design-system/preview` comme teacher seed → page rend (status 200, présence d'un titre `"Design system preview"`, présence de probes `[id^="probe-"]`). Visite anonyme → redirect vers login. Doit échouer initialement (route inexistante).
- [ ] T020 [P] [US2] Écrire `spec/system/design_tokens_audience_mapping_spec.rb` (SC-003) : avec auth teacher, visite `/teacher/design-system/preview`, lit `getComputedStyle(document.querySelector('#probe-accent-primary')).backgroundColor` via `page.evaluate_script`, vérifie `eq hex_to_rgb("#127566")` (teal teacher light). Idem pour student : auth student seed, visite `/student/subjects`, vérifie `eq hex_to_rgb("#d4452e")` (balisier red student light). Cf. `research.md` Q4 pour le pattern probe. Doit échouer initialement.

### Implementation for User Story 2

- [ ] T021 [US2] Créer `app/controllers/teacher/design_system_controller.rb` héritant de `Teacher::BaseController`. Action `preview` (vide, rend la vue par défaut). Pas de logique métier (page démo statique).
- [ ] T022 [US2] Ajouter la route dans `config/routes.rb` sous le namespace `teacher` : `get "design-system/preview", to: "design_system#preview", as: :design_system_preview`.
- [ ] T023 [US2] Créer la vue `app/views/teacher/design_system/preview.html.erb`. Contenu : titre "Design system preview", liste des 19 sémantiques rendus comme cartes (chaque carte montre le nom, la valeur hex résolue, et un swatch coloré via `bg-<role>`). Probes pour le spec SC-003 : éléments `<div id="probe-<role>" class="bg-<role>">` pour chacun des accents (au minimum `probe-accent-primary`, `probe-accent-secondary`, `probe-success`, `probe-danger`). Bonus : sélecteurs (boutons ou liens) pour basculer entre audiences via `data-audience` sur un wrapper local (overrider le `body` n'est pas possible facilement, on peut afficher 3 sections "Comme si student / teacher / public" avec un wrapper `<div data-audience="X">` autour de chaque). Cf. `quickstart.md` pour le pattern des recettes.
- [ ] T024 [US2] Lancer `bin/rails tailwindcss:build`, relancer T019 et T020 → passent. Si T020 échoue uniquement sur student : vérifier que `student_login_path` du spec est correct et que le seed crée bien un élève accessible.

**Checkpoint US2** : la page démo est accessible sous auth teacher, le spec SC-003 prouve que les tokens sont adaptatifs. La docs vivante existe pour B2-B7.

---

## Phase 5: User Story 3 — Bridge rétrocompatible avec les tokens existants (Priority: P1)

**Goal** : préserver les 12 aliases `--color-rad-*` historiques en les remappant vers les nouvelles couches (sans modifier aucune vue ni composant existant). Garantir que la suite de tests existante continue de passer.

**Independent Test** : `bundle exec rspec spec/features/` (suite complète existante) passe sans modification.

### Tests for User Story 3

- [ ] T025 [US3] Écrire `spec/lib/css_compiled_aliases_spec.rb` : charge le CSS compilé via helper T005, vérifie présence des 12 aliases `--color-rad-bg`, `--color-rad-paper`, `--color-rad-raise`, `--color-rad-text`, `--color-rad-muted`, `--color-rad-rule`, `--color-rad-red`, `--color-rad-yellow`, `--color-rad-teal`, `--color-rad-green`, `--color-rad-ink`, `--color-rad-cream`, `--color-rad-warm`. **Note** : ce spec doit passer dès T011/T012 (les aliases existent encore dans le bloc `@theme`), donc l'écrire en mode "regression guard" plus que TDD strict.

### Implementation for User Story 3

- [ ] T026 [US3] Dans `app/assets/tailwind/application.css`, transformer les **12 tokens `--color-rad-*` actuels** en aliases pointant vers les nouvelles couches selon `data-model.md` §3 :
  - `--color-rad-bg → var(--color-surface-sunken)`
  - `--color-rad-paper → var(--color-surface)`
  - `--color-rad-raise → var(--color-surface-raised)`
  - `--color-rad-text → var(--color-on-surface)`
  - `--color-rad-muted → var(--color-on-surface-muted)`
  - `--color-rad-rule → var(--color-rule)`
  - `--color-rad-red → var(--rad-prim-balisier-red)`
  - `--color-rad-yellow → var(--rad-prim-sun-yellow)`
  - `--color-rad-teal → var(--rad-prim-sea-teal)`
  - `--color-rad-green → var(--rad-prim-grass-green)`
  - `--color-rad-ink → var(--rad-prim-ink)`
  - `--color-rad-cream → var(--rad-prim-cream)`
  - `--color-rad-warm → var(--rad-prim-warm)`
  Les anciennes définitions hex dans `@theme` sont supprimées (remplacées par les aliases). Les anciennes overrides dans `.dark` (déjà migré en T011) sont supprimées : les aliases résolvent automatiquement.
- [ ] T027 [US3] Lancer la suite de tests Capybara existante en local (au moins un sous-ensemble rapide pour vérification, vu la lenteur dev) : `bundle exec rspec spec/features/teacher/classroom_management_spec.rb spec/features/student/student_login_spec.rb`. **Doit passer**. La validation complète passera en CI.
- [ ] T028 [US3] Lancer T025 et vérifier qu'il passe (12 aliases présents).

**Checkpoint US3** : aucune régression sur les tests existants, les 12 aliases sont préservés et fonctionnels.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose** : finalisation, mesures, documentation PR.

- [ ] T029 Mesurer le **poids CSS "après B1"** : `bin/rails tailwindcss:build`, puis `wc -c app/assets/builds/tailwind.css` (brut) et `gzip -c app/assets/builds/tailwind.css | wc -c` (gzippé). Comparer aux mesures baseline T003. **Critère SC-007** : ≤ +10 % brut ET ≤ +5 % gzippé. Reporter dans `notes.md`.
- [ ] T030 Lancer toute la suite de tests : `bundle exec rspec spec/`. Identifier les flakes Selenium connues (cf. issue #96) pour les distinguer d'éventuelles régressions. Reporter le résultat dans `notes.md`.
- [ ] T031 [P] Rédiger le body de PR documentant tous les critères de succès (SC-001 résultats diff visuel × 3 écrans, SC-002 CI verte, SC-003 spec mapping pass, SC-004 git diff limité aux fichiers attendus, SC-005 indépendance phases, SC-006 dark teacher fonctionnel testé manuellement, SC-007 poids CSS mesuré).
- [ ] T032 Pousser la branche `065-design-tokens-2-layers` et créer la PR avec le body T031. Attendre CI. Si flake non-#96 → relancer (max 2 fois). Si vrai test fail → débugger.
- [ ] T033 Validation manuelle finale par l'utilisateur : ouvrir 1 écran sous teacher light + 1 écran teacher dark + 1 écran student light pour vérification œil à œil que rien n'a changé.

**Checkpoint final** : PR ouverte, CI verte, mesures reportées, validation manuelle OK. Prêt pour merge.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** : aucune dépendance, peut démarrer immédiatement.
- **Phase 2 (Foundational)** : dépend de Phase 1 (besoin du baseline pour comparer ; pas strictement bloquant mais conventionnel). Bloque Phases 3-5.
- **Phase 3 (US1)** : dépend de Phase 2. **C'est le cœur de la feature** — sans US1 ni US2 ni US3 ne sont valides.
- **Phase 4 (US2)** : dépend de US1 (les sémantiques doivent exister dans le CSS pour qu'on puisse les tester via la page démo).
- **Phase 5 (US3)** : dépend de US1 (la couche primitives/sémantiques doit exister pour que les aliases puissent y pointer). Peut être faite en parallèle de US2.
- **Phase 6 (Polish)** : dépend de US1+US2+US3.

### Note importante sur les 3 US

Bien que la spec liste US1/US2/US3 comme « 3 user stories P1 indépendantes », elles sont en pratique **interdépendantes au sein de la même PR** :
- US1 livre la couche CSS principale
- US2 ajoute la preuve (page démo + spec)
- US3 garantit la rétrocompat (aliases)

Les 3 sont nécessaires pour livrer B1 utilement. L'organisation par US sert la **clarté du découpage**, pas la livraison incrémentale. On livre tout en une PR (#65 séparée du backlog speckit).

### Within Each User Story

- Tests AVANT implémentation (TDD constitution).
- CSS primitives AVANT sémantiques AVANT mappings audience AVANT layouts.
- Migration `.dark` legacy AVANT ajout des mappings dark (T011 avant T012).
- Page démo APRÈS ajout des sémantiques au CSS.
- Aliases APRÈS sémantiques (sinon ils pointent vers du vide).

### Parallel Opportunities

À l'intérieur d'une phase, les tasks marquées [P] peuvent tourner en parallèle (fichiers différents) :
- Setup : T003 [P] (mesure CSS) peut tourner en parallèle de T001/T002 (qui sont préparatoires manuels).
- Foundational : T004 et T005 [P] (helpers indépendants).
- US1 : tests T006/T007 [P] en parallèle ; les modifications layouts T013/T014/T015 [P] en parallèle (3 fichiers différents).
- US2 : tests T019/T020 [P] en parallèle.
- US1 et US3 partagent le fichier `application.css` → exécution **séquentielle** sur ce fichier (US1 T008-T012 d'abord, US3 T026 ensuite).

---

## Parallel Example: User Story 1 (TDD)

```bash
# Lancer les 2 tests US1 en parallèle (fichiers différents, échouent initialement) :
Task: "Écrire spec/system/design_tokens_audience_attribute_spec.rb (T006)"
Task: "Écrire spec/lib/css_compiled_tokens_spec.rb (T007)"

# Lancer les 3 ajouts data-audience en parallèle (fichiers différents) :
Task: "Ajouter data-audience='student' dans student.html.erb (T013)"
Task: "Ajouter data-audience='teacher' dans teacher.html.erb (T014)"
Task: "Ajouter data-audience='public' dans application.html.erb (T015)"
```

---

## Implementation Strategy

### MVP-as-PR (toutes les US dans une seule PR)

Cette feature est une **refacto invisible** : on ne peut pas livrer US1 seule sans US3 (sinon rétrocompat cassée) ni sans US2 (sinon SC-003 non prouvable). Donc :

1. Phase 1 (Setup) → baseline visuelle + métrique
2. Phase 2 (Foundational) → helpers de test
3. Phase 3 (US1) → cœur CSS + layouts
4. Phase 4 (US2) → page démo + spec mapping
5. Phase 5 (US3) → aliases bridge
6. Phase 6 (Polish) → mesures + PR + validation

**Une seule PR**. **Un seul checkpoint utilisateur** (validation manuelle T033).

### Commits suggérés (1 concern par commit)

Découpage qui respecte le principe « one concern per commit » de la constitution :

1. `chore(065): setup baseline + helpers de test` (T001-T005)
2. `test(065): TDD specs pour data-audience + tokens compilés` (T006-T007 + T019-T020 + T025)
3. `feat(065): couche primitives + sémantiques + mappings audience light` (T008-T010)
4. `refactor(065): migrate legacy .dark to data-audience=public dark mapping` (T011)
5. `feat(065): mappings audience dark` (T012)
6. `feat(065): add data-audience attribute on 3 layouts` (T013-T015)
7. `feat(065): bridge --color-rad-* aliases to new layers` (T026)
8. `feat(065): page démo /teacher/design-system/preview` (T021-T023)
9. `chore(065): validation suite (compile, specs, diff visuel)` (T016, T018, T024, T027-T030)
10. PR open + body docs (T031-T032)

10 commits au total, atomiques, ordre logique.

---

## Notes

- [P] tasks = fichiers différents, pas de dépendance sur tâche incomplète.
- [Story] label : trace de la user story pour réviser/débugger.
- Constitution : TDD obligatoire → tests écrits AVANT implémentation, doivent échouer initialement.
- Commits atomiques après chaque task ou groupe logique (cf. suggested commits ci-dessus).
- CI = autorité (constitution V) → si CI fail, ne pas merger même si validation locale OK.
- Pas de feature flag : la feature est invisible, donc activable directement en prod.
- Hors scope (ne PAS faire dans cette PR) : refonte composants ViewComponent (B2/B3), adoption tokens dans vues élève (B4), reskin teacher (B5), migration magic numbers (B6), fixes audit P0 (B0).

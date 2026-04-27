# Tasks: Filtrage des sujets par spécialité de classe (051)

**Input**: Design documents from `/specs/051-specialty-subject-filter/`
**Prerequisites**: plan.md ✅, spec.md ✅, data-model.md ✅, quickstart.md ✅

**TDD**: Constitution IV impose TDD mandatory — specs écrites et en échec AVANT le code de production.

> ⚠️ **APPROBATION REQUISE** (Constitution VI.1) : ce document est un plan, pas un feu vert.
> Ne démarrer T001 qu'après approbation explicite : "go", "fais-le", "implémente", ou "on y va".
> Un "ok" seul ne suffit pas.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Service fondation + factories — bloquant pour toutes les user stories

- [X] T001 **[RED]** Écrire `spec/services/subject_access_policy_spec.rb` — tester : `full_access?` true si spécialités identiques (sujet AC + classe AC), false si différentes (sujet AC + classe EE), false si sujet tronc_commun ; `tc_only?` inverse de `full_access?` ; `accessible_parts` retourne toutes les parties si full_access, seulement les parties `common` si tc_only ; normalisation string downcase (sujet "SIN" + classe "sin" → full_access) ; sujet tronc_commun → `accessible_parts` retourne uniquement parties common — vérifier que la spec échoue avant T002
- [X] T002 **[GREEN]** Créer `app/services/subject_access_policy.rb` — implémenter `full_access?(subject, classroom)`, `tc_only?(subject, classroom)`, `accessible_parts(subject_parts, subject, classroom)` avec normalisation `subject.specialty.to_s == classroom.specialty.to_s.downcase` — faire passer T001 ; `Part#section_type` est l'enum utilisé pour filtrer (common/specific), `Part#specialty` est optionnel (nil pour parts common)
- [X] T003 [P] Mettre à jour `spec/factories/classrooms.rb` — ajouter traits `:ac`, `:ee`, `:sin`, `:itec` qui définissent `specialty` correspondant (string : "AC", "EE", "SIN", "ITEC")
- [X] T004 [P] Mettre à jour `spec/factories/subjects.rb` — ajouter traits `:ac`, `:ee`, `:sin`, `:itec`, `:tronc_commun` qui définissent `specialty` correspondant (enum integer Rails)

**Checkpoint**: `bundle exec rspec spec/services/subject_access_policy_spec.rb` vert

---

## Phase 2: User Story 1 — Accès filtré à la liste des sujets (Priority: P1) 🎯 MVP

**Goal**: Les sujets incompatibles avec la spécialité de la classe affichent le badge "partie commune uniquement" dans la liste

**Independent Test**: Connecter un élève AC, afficher la liste → sujets AC sans badge, sujets EE/SIN/ITEC et tronc_commun avec badge

### Specs (TDD)

- [X] T005 [US1] **[RED]** Écrire spec feature `spec/features/student_specialty_filter_spec.rb` — contexte "élève AC sur liste de sujets" : sujet AC visible sans badge, sujet EE visible avec texte "partie commune uniquement", sujet tronc_commun visible avec texte "partie commune uniquement" ; edge case : sujet sans partie spécifique (que des parties common) accessible à tous sans badge — vérifier que la spec échoue avant T006

### Implémentation

- [X] T006 [US1] **[GREEN]** Mettre à jour `app/controllers/student/subjects_controller.rb#index` — enrichir `@subjects` avec un helper ou variable locale indiquant si chaque sujet est `tc_only?` pour la classe courante (via `SubjectAccessPolicy`) ; après modif vérifier `bundle exec rspec spec/features/student_tutor_*` pour détecter régression
- [X] T007 [US1] **[GREEN]** Mettre à jour `app/views/student/subjects/index.html.erb` — afficher badge/mention "partie commune uniquement" conditionnel sur le flag `tc_only` pour chaque sujet dans la liste — faire passer T005

**Checkpoint**: `bundle exec rspec spec/features/student_specialty_filter_spec.rb` — contexte liste vert

---

## Phase 3: User Story 2 — Accès bloqué à la partie spécifique (Priority: P1)

**Goal**: Les parties spécifiques d'un sujet incompatible sont inaccessibles — redirection avec message informatif, y compris via URL directe

**Independent Test**: Élève EE tente d'accéder à une partie spécifique AC → redirection avec message. Élève EE accède à la partie commune du même sujet → succès.

### Specs (TDD)

- [X] T008 [US2] **[RED]** Compléter `spec/features/student_specialty_filter_spec.rb` — contexte "élève EE sur sujet AC" : accès partie commune OK, accès partie spécifique AC → redirection avec message, accès via URL directe à question en partie spécifique AC → redirection (blocage HTTP, pas seulement UI) — vérifier que la spec échoue avant T009

### Implémentation

- [X] T009 [US2] **[GREEN]** Mettre à jour `app/controllers/student/subjects_controller.rb#show` — avant de naviguer vers une partie, vérifier via `SubjectAccessPolicy` que la partie est accessible ; si partie spécifique et `tc_only?` → redirect avec message "Ce sujet ne propose pas de partie spécifique pour votre spécialité (X)." ; après modif vérifier `bundle exec rspec spec/features/student_tutor_*`
- [X] T010 [US2] **[GREEN]** Mettre à jour `app/controllers/student/questions_controller.rb#set_question` — vérifier via `SubjectAccessPolicy.accessible_parts` que la partie de la question demandée est dans les parties accessibles (blocage URL direct) ; sinon redirect avec alerte ; après modif vérifier `bundle exec rspec spec/features/student_tutor_*`
- [X] T011 [US2] **[GREEN]** Mettre à jour `app/views/student/subjects/show.html.erb` — masquer ou griser le lien vers les parties spécifiques si `tc_only?`, afficher message informatif (ex: "Partie spécifique non disponible pour votre spécialité") — faire passer T008

**Checkpoint**: `bundle exec rspec spec/features/student_specialty_filter_spec.rb` vert complet

---

## Phase 4: User Story 3 — Seeds multi-spécialités (Priority: P2)

**Goal**: Seeds development cohérents avec classes AC + EE, élèves avec clé tuteur, sujet EE disponible

**Independent Test**: `bin/rails db:seed`, connexion élève EE → voit sujet AC avec badge TC, accède partie commune, tuteur disponible

- [X] T012 [US3] Mettre à jour `db/seeds/development.rb` — ajouter : classe AC (`terminale-ac-2025`) avec 2 élèves (anya.ac sans clé, tuteur.ac avec clé OpenRouter `sk-or-test-ac`), classe EE (`terminale-ee-2025`) avec 2 élèves (anya.ee sans clé, tuteur.ee avec clé OpenRouter `sk-or-test-ee`) ; assigner le sujet AC existant aux deux classes via `ClassroomSubject`
- [X] T013 [US3] Mettre à jour `db/seeds/development.rb` — ajouter un sujet EE minimal (réutiliser l'exam_session existant, spécialité EE, TC + 2-3 questions SPE EE avec correction) pour les tests cross-spé ; assigner aux deux classes ; idempotent (`find_or_create_by!`)

**Checkpoint**: `bin/rails db:seed` sans erreur, scénarios quickstart.md validés manuellement

---

## Phase 5: Polish

**Purpose**: Vérification finale, cohérence CI

- [X] T014 Vérifier que `bundle exec rspec spec/` passe sans régression — corriger toute régression introduite par les modifications de controllers/views
- [X] T015 [P] Vérifier que les specs feature existantes `spec/features/student_tutor_*` ne régressent pas (subjects_controller et questions_controller modifiés)

---

## Dependencies & Execution Order

```
Phase 1 (T001–T004) → Phase 2 (T005–T007) → Phase 3 (T008–T011) → Phase 4 (T012–T013) → Phase 5 (T014–T015)
```

- T003 et T004 peuvent tourner en parallèle après T001
- T006 et T007 peuvent tourner en parallèle (controller + vue différents)
- T009, T010, T011 peuvent tourner en parallèle (fichiers distincts)
- T012 et T013 peuvent tourner en séquence (même fichier seeds)
- T014 et T015 peuvent tourner en parallèle

## Implementation Strategy

### MVP (US1 + US2 — filtrage complet)

1. Phase 1 : service + factories
2. Phase 2 : liste filtrée (badge)
3. Phase 3 : blocage accès parties spécifiques
4. **Valider** : connexion élève EE → badge visible, partie spécifique bloquée

### Livraison complète

1. MVP validé → Phase 4 (seeds) → Phase 5 (CI green)
2. PR avec les 3 user stories

## Notes

- TDD strict : toute spec doit être en échec AVANT le code de production (constitution IV)
- Un concern par commit (feedback `feedback_commit_scope.md`)
- Le service `SubjectAccessPolicy` est le seul endroit où la logique de compatibilité réside — controllers et vues l'utilisent sans logique inline
- Attention à la normalisation enum : `subject.specialty` retourne un string Rails ("SIN"), `classroom.specialty` est un string DB brut — comparer en downcase

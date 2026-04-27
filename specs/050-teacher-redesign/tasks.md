# Tasks: Teacher Pages Redesign (050)

**Input**: Design documents from `/specs/050-teacher-redesign/`
**Branch**: `050-teacher-redesign`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut tourner en parallèle (fichiers distincts, pas de dépendances incomplètes)
- **[Story]**: User story concernée (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Préparer la structure partagée avant tout redesign.

- [ ] T001 Créer le répertoire `app/views/teacher/shared/` et le partial `app/views/teacher/shared/_field.html.erb` avec support des types `:text`, `:textarea`, `:file`, `:select`, `:checkbox` et gestion des erreurs inline

**Checkpoint**: Le partial `_field` existe et rend correctement un champ texte simple avec label + erreurs.

---

## Phase 2: Fondation (Prerequis bloquant)

**Purpose**: Vérifier que les tests actuels passent avant de toucher quoi que ce soit.

- [ ] T002 Lancer `bundle exec rspec` depuis la racine du repo principal (`/home/fz/Documents/Dev/claudeCLI/DekatjeBakLa`) et confirmer 0 failure (baseline verte) — le worktree partage le même Gemfile et la même base de données de test

**⚠️ CRITIQUE**: Ne pas commencer les phases suivantes si T002 révèle des failures préexistantes non liées à cette feature.

**Checkpoint**: Baseline RSpec verte confirmée.

---

## Phase 3: User Story 2 — Formulaires (Priority: P2) 🎯 Priorité logique

> US2 dépend de T001 (partial `_field`). Toutes les vues de formulaire peuvent être migrées en parallèle entre elles une fois T001 terminé.

**Goal**: Tous les formulaires enseignant utilisent le partial `_field` — plus aucune classe Tailwind de style input dupliquée.

**Independent Test**: Ouvrir chaque formulaire (classe, élève, sujet, question), vérifier le rendu visuel identique et soumettre — comportement fonctionnel inchangé.

### Implémentation US2

- [ ] T003 [P] [US2] Migrer `app/views/teacher/classrooms/new.html.erb` vers `_field` pour les champs name, school_year, specialty
- [ ] T004 [P] [US2] Migrer `app/views/teacher/classrooms/edit.html.erb` vers `_field` pour le champ tutor_free_mode_enabled (type :checkbox)
- [ ] T005 [P] [US2] Migrer `app/views/teacher/students/new.html.erb` vers `_field` pour les champs first_name, last_name
- [ ] T006 [P] [US2] Migrer `app/views/teacher/classrooms/student_imports/new.html.erb` vers `_field` pour le champ students_list (type :textarea)
- [ ] T007 [P] [US2] Migrer `app/views/teacher/subjects/new.html.erb` vers `_field` pour les champs title, year, exam_type, specialty, region et les file inputs (type :file)
- [ ] T008 [P] [US2] Migrer `app/views/teacher/questions/_question_form.html.erb` vers `_field` pour les champs label, points, correction_text, explanation_text

**Checkpoint**: Tous les formulaires enseignant n'ont plus de classes Tailwind inline pour les inputs/textareas. `bundle exec rspec` → 0 failure.

---

## Phase 4: User Story 3 — Pages de détail (Priority: P3)

> Les vues de détail sont indépendantes entre elles — parallélisables.

**Goal**: Les sections groupées des pages de détail et les cartes de questions utilisent CardComponent.

**Independent Test**: Charger `subjects/show` et `classrooms/show` — vérifier que les sections apparaissent dans des cartes avec le style cohérent du design system. (`parts/show` est couvert par US1, pas US3.)

### Implémentation US3

- [ ] T009 [P] [US3] Wrapper en CardComponent les sections de `app/views/teacher/subjects/show.html.erb` : section métadonnées (header), section PDFs (body), section session (body séparé)
- [ ] T010 [P] [US3] Wrapper en CardComponent les sections de `app/views/teacher/classrooms/show.html.erb` : section infos classe (header), section credentials (body — utiliser CardComponent default + `bg-amber-50 dark:bg-amber-900/20` sur le div interne si credentials présents), section liste élèves (body)
- [ ] T011 [P] [US3] Migrer `app/views/teacher/questions/_question.html.erb` vers CardComponent — `border-l-4 border-emerald-500` pour validées, `border-l-4 border-slate-300` pour brouillon

**Checkpoint**: Pages de détail cohérentes avec le design system. `bundle exec rspec` → 0 failure.

---

## Phase 5: User Story 1 — Navigation (Priority: P1)

> **Pourquoi US1 (P1) est implémentée après US2/US3** : Le BreadcrumbComponent sur `subjects/show` doit être positionné dans une page déjà refactorisée avec CardComponent (T009). Implémenter le breadcrumb avant le refactoring créerait une double intervention sur le même fichier. L'ordre des phases optimise l'exécution sans dégrader la priorité fonctionnelle. Les 4 pages de breadcrumb sont parallélisables entre elles.

**Goal**: BreadcrumbComponent présent et correct sur toutes les pages enseignant de profondeur ≥ 2.

**Independent Test**: Naviguer de `subjects/index` → `subjects/show` → `parts/show` et vérifier le fil d'Ariane à chaque étape.

### Implémentation US1

- [ ] T012 [P] [US1] Ajouter BreadcrumbComponent dans `app/views/teacher/subjects/show.html.erb` : items `[{label: "Mes sujets", href: teacher_subjects_path}, {label: subject.title}]`
- [ ] T013 [P] [US1] Ajouter BreadcrumbComponent dans `app/views/teacher/subjects/new.html.erb` : items `[{label: "Mes sujets", href: teacher_subjects_path}, {label: "Nouveau sujet"}]`
- [ ] T014 [P] [US1] Ajouter BreadcrumbComponent dans `app/views/teacher/parts/show.html.erb` : items `[{label: "Mes sujets", href: teacher_subjects_path}, {label: part.subject.title, href: teacher_subject_path(part.subject)}, {label: "Partie #{part.number}"}]`
- [ ] T015 [P] [US1] Ajouter BreadcrumbComponent dans `app/views/teacher/subjects/assignments/edit.html.erb` : items `[{label: "Mes sujets", href: teacher_subjects_path}, {label: subject.title, href: teacher_subject_path(subject)}, {label: "Assignation"}]`

**Checkpoint**: Fil d'Ariane correct sur les 4 pages. Aucun fil d'Ariane sur les pages racines (classrooms/index, subjects/index). `bundle exec rspec` → 0 failure.

---

## Phase 6: Polish & Validation finale

- [ ] T016 Lancer `bundle exec rspec` complet depuis la racine du repo — confirmer 0 failure sur la suite entière (SC-003, gate finale)
- [ ] T017 Vérifier dark mode ET responsive sur toutes les pages modifiées : basculer le thème (SC-004) ET réduire la fenêtre à < 640px pour valider l'affichage mobile (FR-006)
- [ ] T018 [P] Vérifier l'absence de duplication de classes Tailwind input entre les vues teacher (SC-002) — grep `"w-full rounded-lg border border-slate-200"` dans `app/views/teacher/`
- [ ] T019 Committer les specs (spec.md, plan.md, research.md, data-model.md, tasks.md) dans un commit `docs(050): add spec, plan and tasks for teacher redesign`

---

## Dépendances & Ordre d'exécution

### Dépendances entre phases

- **Phase 1 (T001)**: Aucune dépendance — commencer immédiatement
- **Phase 2 (T002)**: Dépend de Phase 1 — confirme la baseline
- **Phase 3 (T003–T008)**: Dépend de T001 (partial `_field` existant) et T002 (baseline verte)
- **Phase 4 (T009–T011)**: Dépend de T002 — indépendante de Phase 3
- **Phase 5 (T012–T015)**: Dépend de T009 pour subjects/show, T002 pour les autres
- **Phase 6 (T016–T019)**: Dépend de toutes les phases précédentes

### Parallélisme

- T003–T008 : entièrement parallèles (fichiers distincts)
- T009–T011 : entièrement parallèles (fichiers distincts)
- T012–T015 : entièrement parallèles (fichiers distincts)
- T016 et T018 : parallèles entre eux

---

## Exemple d'exécution parallèle — Phase 3 (formulaires)

```
Agent 1 : T003 — classrooms/new.html.erb
Agent 2 : T005 — students/new.html.erb
Agent 3 : T007 — subjects/new.html.erb
Agent 4 : T008 — questions/_question_form.html.erb
(T004, T006 peuvent tourner sur Agent 1 ou 2 une fois leurs tâches finies)
```

---

## Stratégie d'implémentation

### MVP minimal (Phase 1 + 3 uniquement)

1. T001 — créer le partial `_field`
2. T002 — confirmer baseline
3. T003–T008 — migrer tous les formulaires
4. **STOP** : formulaires cohérents, SC-002 atteint

### Livraison complète (toutes phases)

1. Setup + Fondation → partial prêt, baseline verte
2. Phase 3 → formulaires cohérents (MVP)
3. Phase 4 → pages de détail refactorisées
4. Phase 5 → navigation avec breadcrumb
5. Phase 6 → validation finale + commit docs

---

## Notes

- Ne modifier ni controller, ni route, ni modèle, ni service (FR-004)
- Conserver tous les attributs `data-*`, `id:`, `method:` des formulaires existants
- Le partial `_field` utilise `render` avec locals explicites — pas de `local_assigns` implicite
- Chaque tâche [P] peut être confiée à un sous-agent distinct

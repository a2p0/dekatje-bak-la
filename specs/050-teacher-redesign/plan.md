# Implementation Plan: Teacher Pages Redesign

**Branch**: `050-teacher-redesign` | **Date**: 2026-04-26 | **Spec**: [spec.md](./spec.md)

## Summary

Appliquer le design system (feature 025) aux 18 vues ERB enseignant restantes.
Trois axes : centralisation des styles de formulaire (partial `_field`), ajout du BreadcrumbComponent sur les pages de profondeur ≥ 2, wrapping des sections de détail en CardComponent. Aucun comportement fonctionnel ne change.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1.3
**Primary Dependencies**: ViewComponent, Tailwind CSS 4, Plus Jakarta Sans, Hotwire/Turbo
**Storage**: N/A (aucune migration)
**Testing**: RSpec + FactoryBot + Capybara
**Target Platform**: Web (Chrome + Firefox, mobile-first)
**Project Type**: Web application fullstack Rails
**Performance Goals**: N/A (CSS/HTML uniquement)
**Constraints**: Zéro régression fonctionnelle — tous les tests RSpec existants doivent passer
**Scale/Scope**: 18 vues ERB, 1 nouveau partial, 5 pages avec breadcrumb

## Constitution Check

| Principe | Status | Notes |
|---|---|---|
| I. Fullstack Rails — Hotwire Only | ✅ | Aucun SPA introduit |
| II. RGPD & Protection des mineurs | ✅ | Aucune donnée collectée/modifiée |
| III. Security | ✅ | Aucune clé, aucun secret exposé |
| IV. Testing | ✅ | Tests existants suffisants pour régression ; no new feature behavior |
| V. Performance & Simplicity | ✅ | CSS/HTML uniquement, pas de JS ajouté |
| VI. Development Workflow | ✅ | Feature branch + PR + CI |

## Project Structure

### Documentation (cette feature)

```text
specs/050-teacher-redesign/
├── plan.md              ← ce fichier
├── spec.md
├── research.md
├── data-model.md
└── tasks.md             ← généré par /speckit-tasks
```

### Source Code (fichiers modifiés)

```text
app/views/teacher/
├── shared/
│   └── _field.html.erb          ← NOUVEAU — partial formulaire centralisé
├── classrooms/
│   ├── index.html.erb            ← ajustements mineurs si nécessaire
│   ├── show.html.erb             ← CardComponent sur sections, breadcrumb N/A (profondeur 1)
│   ├── new.html.erb              ← _field partial
│   ├── edit.html.erb             ← _field partial
│   └── student_imports/
│       └── new.html.erb          ← _field partial
├── subjects/
│   ├── show.html.erb             ← CardComponent sections + BreadcrumbComponent
│   ├── new.html.erb              ← _field partial + BreadcrumbComponent
│   └── assignments/
│       └── edit.html.erb         ← BreadcrumbComponent
├── parts/
│   └── show.html.erb             ← BreadcrumbComponent
├── questions/
│   ├── _question.html.erb        ← CardComponent
│   └── _question_form.html.erb   ← _field partial
└── students/
    └── new.html.erb              ← _field partial
```

## Phase 1 — Partial `_field` (fondation)

Créer `app/views/teacher/shared/_field.html.erb`.

Le partial accepte les locals suivants :
- `f` (form builder)
- `field` (Symbol)
- `label_text` (String)
- `type` (Symbol, défaut `:text`) — valeurs : `:text`, `:textarea`, `:file`, `:select`, `:checkbox`
- `options` (Hash, défaut `{}`)
- `hint` (String, optionnel)

Style cible (à centraliser) :
```
label   : block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1
input   : w-full rounded-lg border border-slate-200 dark:border-slate-700
          bg-white dark:bg-slate-900 text-sm px-3 py-2
          focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent
textarea: idem input + rows: 4 par défaut
file    : w-full text-sm file:mr-4 file:py-2 file:px-4
          file:rounded-lg file:border-0 file:text-sm file:font-semibold
          file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100
          dark:text-slate-300
checkbox: accent-indigo-500 h-4 w-4 rounded
erreurs : mt-1 text-sm text-rose-600 dark:text-rose-400
hint    : mt-1 text-xs text-slate-500 dark:text-slate-400
```

## Phase 2 — Formulaires (utiliser `_field`)

Remplacer les classes inline répétées par `render "teacher/shared/field", f: f, field: :xxx, label_text: "...", type: :text` dans :

1. `classrooms/new.html.erb` — champs : name, school_year, specialty
2. `classrooms/edit.html.erb` — champ : tutor_free_mode_enabled (type :checkbox)
3. `students/new.html.erb` — champs : first_name, last_name
4. `classrooms/student_imports/new.html.erb` — champ : students_list (type :textarea)
5. `subjects/new.html.erb` — champs : title, year, exam_type, specialty, region + file inputs
6. `questions/_question_form.html.erb` — champs : label, points, correction_text, explanation_text

**Règle** : ne pas modifier la logique `form_with`, les attributs `data-*`, ni les `method:` des formulaires.

## Phase 3 — Pages de détail (CardComponent)

Wrapper en `CardComponent` les sections non encore componentisées :

### `subjects/show.html.erb`
- Section métadonnées (titre, badges) → header CardComponent
- Section PDFs (liens subject_pdf, correction_pdf) → card body
- Section session (exam_session) → card body séparé

### `classrooms/show.html.erb`
- Section infos classe (nom, code d'accès, année) → card header
- Section credentials générés (tableau amber) → card body avec variant amber si credentials présents
- Section liste élèves (tableau) → card body séparé

### `questions/_question.html.erb`
- Question validée → `CardComponent` avec `border-l-4 border-emerald-500`
- Question brouillon → `CardComponent` avec `border-l-4 border-slate-300`

## Phase 4 — BreadcrumbComponent

Ajouter `render BreadcrumbComponent.new(items: [...])` en haut de contenu (sous le h1) sur :

| Vue | Items |
|---|---|
| `subjects/show` | `[{label: "Mes sujets", href: teacher_subjects_path}, {label: subject.title}]` |
| `subjects/new` | `[{label: "Mes sujets", href: teacher_subjects_path}, {label: "Nouveau sujet"}]` |
| `parts/show` | `[{label: "Mes sujets", href: teacher_subjects_path}, {label: part.subject.title, href: teacher_subject_path(part.subject)}, {label: "Partie #{part.number}"}]` |
| `subjects/assignments/edit` | `[{label: "Mes sujets", href: teacher_subjects_path}, {label: subject.title, href: teacher_subject_path(subject)}, {label: "Assignation"}]` |

## Critères de validation

- [ ] `bundle exec rspec` → 0 failure
- [ ] Aucune classe Tailwind de style input dupliquée entre deux vues teacher
- [ ] Fil d'Ariane visible et correct sur les 4 pages concernées
- [ ] Dark mode fonctionnel sur toutes les pages modifiées
- [ ] Aucune modification de controller, de route, de modèle ou de service

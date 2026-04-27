# Implementation Plan: Filtrage des sujets par spécialité de classe

**Branch**: `051-specialty-subject-filter` | **Date**: 2026-04-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/051-specialty-subject-filter/spec.md`

## Summary

Filtrer l'accès des élèves aux parties d'un sujet selon la compatibilité entre la spécialité de leur classe et celle du sujet. Les sujets non compatibles restent visibles dans la liste mais sont marqués "partie commune uniquement" ; les parties spécifiques non compatibles sont bloquées en lecture et en accès URL direct. Aucune migration nécessaire — tous les champs existent. L'approche technique s'appuie sur un service `SubjectAccessPolicy` qui encapsule la logique de compatibilité, utilisé par les controllers et les vues.

## Technical Context

**Language/Version**: Ruby 3.3+ / Rails 8.1.3
**Primary Dependencies**: Rails (ActiveRecord, controllers, views), RSpec + FactoryBot + Capybara
**Storage**: PostgreSQL — champs existants : `classrooms.specialty` (string), `subjects.specialty` (integer enum), `parts.section_type` (integer enum), `parts.specialty` (integer enum)
**Testing**: RSpec (unit services + models), Capybara (feature specs)
**Target Platform**: Web (Hotwire/Turbo, fullstack Rails)
**Project Type**: Web application fullstack Rails
**Performance Goals**: Standard — filtrage en mémoire sur des collections de petite taille (< 20 parties par sujet)
**Constraints**: Pas de migration. Pas de nouveau modèle. Logique de compatibilité encapsulée dans un service (pas dans les controllers ni les vues).
**Scale/Scope**: MVP mono-matière STI2D, 4 spécialités (SIN, ITEC, EE, AC) + tronc_commun

## Constitution Check

| Principe | Statut | Notes |
|----------|--------|-------|
| I. Fullstack Rails — Hotwire Only | ✅ PASS | Pas de SPA, filtrage côté serveur |
| II. RGPD & Protection mineurs | ✅ PASS | Pas de nouvelle donnée élève collectée |
| III. Security | ✅ PASS | Blocage URL direct dans `set_question` / `set_part` |
| IV. Testing (TDD NON-NEGOTIABLE) | ✅ PASS | Specs service + feature Capybara prévues |
| V. Performance & Simplicity | ✅ PASS | Service simple, pas de requête N+1 supplémentaire |
| VI. Development Workflow | ✅ PASS | Branche dédiée, PR, speckit complet |

Aucune violation. Pas de section Complexity Tracking nécessaire.

## Project Structure

### Documentation (this feature)

```text
specs/051-specialty-subject-filter/
├── plan.md              ← ce fichier
├── research.md          ← Phase 0 (inline, aucun inconnu)
├── data-model.md        ← Phase 1
├── quickstart.md        ← Phase 1
└── tasks.md             ← /speckit.tasks (prochaine étape)
```

### Source Code

```text
app/
├── services/
│   └── subject_access_policy.rb          ← NOUVEAU — logique compatibilité spécialité
├── controllers/student/
│   ├── subjects_controller.rb            ← MODIFIER — badge TC dans index, blocage show
│   └── questions_controller.rb           ← MODIFIER — blocage accès question via part spécifique
├── views/student/subjects/
│   ├── index.html.erb                    ← MODIFIER — badge "partie commune uniquement"
│   └── show.html.erb                     ← MODIFIER — message blocage partie spécifique
└── helpers/student/
    └── subjects_helper.rb                ← MODIFIER ou NOUVEAU — helper badge/label

spec/
├── services/
│   └── subject_access_policy_spec.rb     ← NOUVEAU
├── features/
│   └── student_specialty_filter_spec.rb  ← NOUVEAU (Capybara)
└── factories/
    └── classrooms.rb                     ← MODIFIER — ajouter traits :ac, :ee, :sin, :itec
    └── subjects.rb                       ← MODIFIER — ajouter traits par spécialité

db/seeds/development.rb                   ← MODIFIER — classes AC + EE, élèves avec clé tuteur
```

## Phase 0: Research

Aucun inconnu technique — tous les éléments sont présents dans la codebase :

**Décision 1 : Service `SubjectAccessPolicy`**
- Decision: Créer `app/services/subject_access_policy.rb` avec méthode `accessible_parts(subject, classroom)` et `tc_only?(subject, classroom)`
- Rationale: La logique de compatibilité doit être testable isolément et réutilisable par plusieurs controllers (subjects, questions). L'inline dans les controllers violerait le principe "thin controllers" de la constitution.
- Alternatives considérées: méthode sur `Subject` (couplage modèle/classe), méthode sur `StudentSession` (déjà complexe), concern controller (moins testable).

**Décision 2 : Compatibilité = match de spécialité**
- Decision: Un sujet est "compatible" si `subject.specialty == classroom.specialty` (ex: sujet AC + classe AC). Un sujet `tronc_commun` est toujours TC-only pour toutes les classes.
- Rationale: Règle métier tranchée dans la spec — pas de bypass ClassroomSubject.
- Cas edge: `classroom.specialty` est un string (ex: "SIN"), `subject.specialty` est un enum integer. La comparaison doit normaliser (ex: `subject.specialty == classroom.specialty.downcase` ou mapping).

**Décision 3 : Blocage URL direct**
- Decision: Dans `Student::QuestionsController#set_question`, vérifier via `SubjectAccessPolicy` que la partie de la question est accessible. Rediriger avec alerte sinon.
- Rationale: La sécurité doit être au niveau controller, pas seulement UI.

**Décision 4 : Pas de modification de `StudentSession#part_filter`**
- Decision: Le filtrage par spécialité est indépendant du `part_filter` existant (full/common_only/specific_only). Les deux mécanismes coexistent : `part_filter` gère le choix de scope utilisateur, `SubjectAccessPolicy` gère la compatibilité de spécialité.
- Rationale: Modifier `StudentSession` et son JSONB serait invasif et hors scope.

## Phase 1: Design & Contracts

### Service SubjectAccessPolicy

```ruby
# app/services/subject_access_policy.rb
class SubjectAccessPolicy
  # Returns true if the student's classroom specialty matches the subject specialty.
  # tronc_commun subjects are never fully compatible (TC-only for all).
  def self.full_access?(subject, classroom)
    return false if subject.tronc_commun?
    subject.specialty.to_s == classroom.specialty.to_s.downcase
  end

  # Returns true if the student can only access common parts.
  def self.tc_only?(subject, classroom)
    !full_access?(subject, classroom)
  end

  # Filters parts to only those accessible given the classroom specialty.
  # If tc_only: returns only common parts. Otherwise: all parts.
  def self.accessible_parts(subject_parts, subject, classroom)
    return subject_parts if full_access?(subject, classroom)
    subject_parts.select { |p| p.common? }
  end
end
```

### Modification controllers

**`Student::SubjectsController#index`** : passer `@subjects` enrichis d'un flag `tc_only` pour la vue.
**`Student::SubjectsController#show`** : si `SubjectAccessPolicy.tc_only?` et la partie demandée est spécifique → redirect avec message.
**`Student::QuestionsController#set_question`** : vérifier que la partie de la question est accessible via `SubjectAccessPolicy.accessible_parts`.

### Modification vues

**`index.html.erb`** : badge "partie commune uniquement" conditionnel sur le flag `tc_only`.
**`show.html.erb`** : message informatif si blocage partie spécifique (ex: "Ce sujet ne propose pas de partie spécifique pour votre spécialité (AC).").

### Pas de contrats API externes

Feature purement interne Rails — pas de JSON API, pas de contrat externe.

## Complexity Tracking

Aucune violation de constitution — section vide.

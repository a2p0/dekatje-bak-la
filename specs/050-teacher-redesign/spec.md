# Feature Specification: Teacher Pages Redesign

**Feature Branch**: `050-teacher-redesign`  
**Speckit Feature**: `050-teacher-redesign`  
**Created**: 2026-04-26  
**Status**: Draft  
**Input**: Appliquer le design system aux pages enseignant

## Contexte

Le design system a été livré dans la feature 025 (Tailwind CSS 4, Plus Jakarta Sans, 10 ViewComponents).
Les pages élève sont entièrement redessinées. Les pages enseignant utilisent déjà partiellement les composants
(ButtonComponent, BadgeComponent, CardComponent, ProgressBarComponent) mais restent incohérentes :
inputs/textareas/checkboxes en classes Tailwind inline répétées, pas de BreadcrumbComponent,
hiérarchie visuelle hétérogène.

Ce redesign vise à amener les pages enseignant au même niveau de cohérence visuelle que les pages élève,
sans modifier aucun comportement fonctionnel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Navigation cohérente sur toutes les pages enseignant (Priority: P1)

L'enseignant navigue entre ses classes, ses sujets, et les parties/questions d'un sujet.
À chaque niveau de profondeur, il comprend immédiatement où il se trouve grâce à un fil d'Ariane
clair et une hiérarchie visuelle lisible.

**Why this priority**: La navigation est transversale à toutes les pages. Sans elle, les autres
améliorations visuelles manquent de cohérence structurelle.

**Independent Test**: Naviguer de l'index des classes jusqu'à la validation d'une question spécifique
en observant que le fil d'Ariane reflète correctement le chemin parcouru à chaque étape.

**Acceptance Scenarios**:

1. **Given** l'enseignant est sur la page de détail d'un sujet, **When** il regarde l'en-tête, **Then** il voit un fil d'Ariane "Mes sujets › [Titre du sujet]"
2. **Given** l'enseignant est sur la page de validation d'une partie, **When** il regarde l'en-tête, **Then** il voit "Mes sujets › [Titre du sujet] › [Partie N]"
3. **Given** l'enseignant est sur l'index des classes ou des sujets, **When** il charge la page, **Then** aucun fil d'Ariane n'est affiché (pages racines)

---

### User Story 2 — Formulaires lisibles et cohérents (Priority: P2)

L'enseignant crée une classe, ajoute un élève, ou édite une question. Les champs de formulaire
ont un style uniforme : label, input/textarea, message d'erreur — identique sur toutes les pages.

**Why this priority**: Les formulaires sont les principaux points d'interaction. Leur incohérence
visuelle actuelle (classes longues inline répétées) crée une impression de non-fini.

**Independent Test**: Remplir et soumettre le formulaire de création de classe, puis celui d'ajout d'élève
— les deux doivent avoir le même rendu visuel pour les champs équivalents.

**Acceptance Scenarios**:

1. **Given** l'enseignant ouvre un formulaire quelconque (classe, élève, sujet, question), **When** il voit les champs, **Then** chaque champ a un label visible, un contour cohérent, et un état focus identique à travers tous les formulaires
2. **Given** le formulaire contient des erreurs de validation, **When** il est soumis, **Then** les messages d'erreur s'affichent dans le même style rose sur toutes les pages
3. **Given** l'enseignant soumet un formulaire valide, **When** la page se recharge, **Then** le comportement fonctionnel est strictement identique à l'état actuel

---

### User Story 3 — Pages de liste visuellement claires (Priority: P3)

L'enseignant consulte sa liste de classes ou de sujets. Les cartes/lignes de tableau sont aérées,
les statuts lisibles, et les actions accessibles sans surcharge visuelle.

**Why this priority**: Les listes sont les points d'entrée principaux. Une fois la navigation et
les formulaires cohérents, les listes complètent la cohérence d'ensemble.

**Independent Test**: Consulter l'index des classes avec au moins 3 classes, puis l'index des sujets
avec au moins 3 sujets de statuts variés — vérifier que badges, boutons et cartes sont uniformes.

**Acceptance Scenarios**:

1. **Given** l'enseignant a plusieurs classes, **When** il consulte l'index, **Then** chaque classe est présentée dans une CardComponent cohérente avec BadgeComponent pour la spécialité
2. **Given** l'enseignant a des sujets à divers statuts (draft, published, archived), **When** il consulte la liste, **Then** chaque statut affiche un BadgeComponent de couleur distincte et cohérente
3. **Given** l'enseignant est sur une page de liste, **When** il passe la souris sur une action, **Then** le style hover est le même que sur les pages élève (slate-50 / dark:slate-800)

---

### Edge Cases

- Qu'affiche le fil d'Ariane si le titre du sujet est très long (> 60 caractères) ? → tronqué avec ellipsis
- Comment se comportent les formulaires en dark mode sur mobile (viewport < 640px) ?
- Si un sujet n'a pas encore de parties, la page de détail affiche-t-elle un état vide cohérent ?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT utiliser BreadcrumbComponent sur toutes les pages enseignant de profondeur ≥ 2 (détail sujet, détail partie, formulaires imbriqués)
- **FR-002**: Le système DOIT centraliser le style des inputs, textareas et checkboxes dans un partial ou helper partagé (supprimer les classes Tailwind inline répétées)
- **FR-003**: Le système DOIT appliquer CardComponent sur les sections groupées des pages de détail (subjects/show, classrooms/show) qui ne l'utilisent pas encore
- **FR-004**: Aucun comportement fonctionnel (actions, routes, Turbo Streams, validations) NE DOIT être modifié
- **FR-005**: Le redesign DOIT être cohérent en light mode ET dark mode
- **FR-006**: Le redesign DOIT être responsive (mobile-first, breakpoints sm/md/lg existants)
- **FR-007**: Les classes Tailwind inline longues et répétées dans les formulaires DOIVENT être extraites dans un partial `_field` ou via un form builder helper, pas dupliquées

### Key Entities

- **Pages enseignant** : 18 vues ERB dans `app/views/teacher/` — seules les vues sont modifiées, pas les controllers ni les modèles
- **ViewComponents disponibles** : ButtonComponent, CardComponent, BadgeComponent, ProgressBarComponent, BreadcrumbComponent — déjà existants, à utiliser systématiquement
- **Partial formulaire** : nouveau partial ou helper centralisant le style input/textarea/label/erreur

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Toutes les pages enseignant de profondeur ≥ 2 affichent un fil d'Ariane correct (vérifiable page par page, 100% des pages concernées)
- **SC-002**: Aucune chaîne de classes Tailwind de style input/textarea n'est dupliquée entre deux vues enseignant — une seule source de vérité
- **SC-003**: Zéro régression fonctionnelle — tous les tests RSpec existants passent après le redesign
- **SC-004**: Le dark mode est fonctionnel sur toutes les pages modifiées (vérifiable en basculant le thème sur chaque page)
- **SC-005**: Toutes les pages enseignant utilisent les mêmes composants que leurs équivalents élève pour les éléments communs (boutons, badges, cartes)

## Assumptions

- Aucune nouvelle fonctionnalité n'est introduite — c'est un redesign pur (apparence uniquement)
- Les ViewComponents existants couvrent tous les besoins ; aucun nouveau composant complexe n'est créé sauf un partial de formulaire simple
- Les tests Capybara existants suffisent à détecter les régressions fonctionnelles — pas de nouveaux tests feature requis pour ce redesign
- Le layout `teacher.html.erb` est déjà correct (NavBar, FlashComponent) — pas de modification du layout
- La feature 025 (design system) est entièrement mergée sur main et disponible dans ce worktree

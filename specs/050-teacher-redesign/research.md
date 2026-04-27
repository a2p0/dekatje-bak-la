# Research: Teacher Pages Redesign (050)

## Décisions techniques

### Centralisation des styles de formulaire

**Decision**: Partial ERB `app/views/teacher/shared/_field.html.erb` avec helper form builder optionnel.

**Rationale**: Un partial ERB est la solution la plus simple et la plus lisible dans un contexte Rails fullstack. Pas besoin d'un form builder custom pour un MVP — le partial reçoit `f` (form builder), `field` (nom du champ), `label` (texte), `type` (:text, :textarea, :checkbox, :file, :select) et `options` (hash). Ce pattern existe déjà dans l'écosystème Rails (form partials) et est immédiatement compréhensible.

**Alternatives considérées**:
- Custom FormBuilder subclass : plus puissant mais plus complexe, over-engineering pour ce scope
- ViewComponent `FieldComponent` : adapté si les champs ont de la logique, mais ici c'est purement du style

### BreadcrumbComponent — pages concernées

**Decision**: Ajouter le fil d'Ariane sur 4 pages de profondeur ≥ 2 :
1. `subjects/show` → "Mes sujets › [Titre sujet]"
2. `subjects/new` → "Mes sujets › Nouveau sujet"
3. `parts/show` → "Mes sujets › [Titre sujet] › Partie [N]"
4. `subjects/assignments/edit` → "Mes sujets › [Titre sujet] › Assignation"

Pages racines (pas de breadcrumb) : `classrooms/index` (dashboard), `subjects/index`.

**Rationale**: Les pages de détail et formulaires imbriqués sont les seuls cas où la navigation contextuelle apporte de la valeur. Le dashboard (`classrooms/index`) est le point d'entrée — pas de parent.

### CardComponent — sections à wrapper

**Decision**: Wrapper en CardComponent les sections suivantes non encore componentisées :
- `subjects/show` : section PDFs, section session, header métadonnées
- `classrooms/show` : section infos classe, section credentials générés, section élèves

**Rationale**: Ces sections sont actuellement des `div` avec classes inline `bg-white dark:bg-slate-800 rounded-xl border`. CardComponent centralise exactement ce pattern.

### Pas de nouveau composant ViewComponent

**Decision**: Aucun nouveau ViewComponent créé. Uniquement un partial ERB pour les champs de formulaire.

**Rationale**: Les 10 composants existants couvrent tous les besoins. Créer un composant pour les formulaires n'apporte pas de valeur supplémentaire vs un partial simple à ce stade.

### Ordre d'implémentation

**Decision**: Traiter les vues par groupes fonctionnels dans cet ordre :
1. Partial `_field` (fondation, utilisé par tous les formulaires)
2. Formulaires (classrooms/new, classrooms/edit, students/new, subjects/new, student_imports/new, questions/_question_form)
3. Pages de détail (subjects/show, classrooms/show, parts/show)
4. BreadcrumbComponent sur toutes les pages concernées

**Rationale**: Le partial doit exister avant d'être utilisé dans les formulaires. Les pages de détail et breadcrumbs peuvent être faits en parallèle une fois les formulaires stabilisés.

# Data Model: Filtrage des sujets par spécialité de classe

Aucune migration nécessaire. Tous les champs existent déjà.

## Entités concernées (existantes)

### Classroom
- `specialty` (string) — spécialité de la classe : "SIN", "ITEC", "EE", "AC"
- Relation : `has_many :students`

### Subject
- `specialty` (integer enum) — `{ tronc_commun: 0, SIN: 1, ITEC: 2, EE: 3, AC: 4 }`
- Règle : `tronc_commun` → TC-only pour toutes les classes

### Part
- `section_type` (integer enum) — `{ common: 0, specific: 1 }`
- `specialty` (integer enum) — `{ SIN: 0, ITEC: 1, EE: 2, AC: 3 }` (nil si common)
- Règle : les parties `specific` sont filtrées par `SubjectAccessPolicy`

### Student
- `specialty` (integer enum) — `{ SIN: 0, ITEC: 1, EE: 2, AC: 3 }` — hérité de la classe pour l'affichage, mais la règle d'accès utilise `student.classroom.specialty`

## Logique de compatibilité (sans migration)

```
full_access?(subject, classroom):
  subject.specialty == classroom.specialty  (et subject n'est pas tronc_commun)

tc_only?(subject, classroom):
  NOT full_access?
```

## Mapping enum — point d'attention

`Classroom#specialty` est un **string** ("SIN", "AC"…).
`Subject#specialty` est un **integer enum** (Rails enum, accès via `.SIN?`, `.AC?`…, `.specialty` retourne "SIN", "AC"… en string).

La comparaison dans `SubjectAccessPolicy` normalise les deux côtés en string downcase :
```ruby
subject.specialty.to_s == classroom.specialty.to_s.downcase
```

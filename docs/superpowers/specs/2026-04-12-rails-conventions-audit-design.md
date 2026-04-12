# Rails Conventions Audit Mode — Design Spec

## Contexte

Le skill `rails-conventions` est en place avec 6 fichiers references. Il guide Claude Code quand il écrit du code, mais ne permet pas de scanner le code existant contre les conventions. L'audit mode comble ce manque.

## Décisions prises

| Question | Réponse |
|---|---|
| Portée | Flexible — scan complet sans argument, domaine ciblé avec argument |
| Format sortie | Rapport structuré — résumé chiffré + détail par domaine |
| Action après audit | Rapport uniquement — pas de correction automatique |
| Architecture | Section ajoutée au SKILL.md existant (approche 1) |

## Invocation

- `/rails-conventions audit` — scan complet (6 domaines)
- `/rails-conventions audit models` — domaine ciblé
- Domaines valides : `models`, `controllers`, `services`, `views`, `jobs`, `tests`

## Checklist par domaine

### Models (`app/models/*.rb`)

| Check | Severity | Convention |
|---|---|---|
| `has_many` sans `dependent:` | VIOLATION | references/models.md — Associations |
| Callbacks autres que `before_validation` / `after_create_commit` | WARNING | references/models.md — Callbacks |
| N+1 potentiel : association utilisée dans une vue sans `includes()` dans le controller | WARNING | references/models.md — Scopes & Queries |

### Controllers (`app/controllers/**/*.rb`)

| Check | Severity | Convention |
|---|---|---|
| Action non-RESTful (hors 7 actions standard) | WARNING | references/controllers.md — RESTful Design |
| `where()` / requête directe dans le controller | WARNING | references/controllers.md → references/models.md — Scopes |
| Strong params inline (pas dans méthode privée) | VIOLATION | references/controllers.md — Strong Params |

### Services (`app/services/*.rb`)

| Check | Severity | Convention |
|---|---|---|
| Absence de `self.call` comme méthode publique | WARNING | references/services.md — Standard Pattern |
| Retour hash `{ success: ... }` au lieu de raise | WARNING | references/services.md — Rules |
| Nommage non verbe+nom | WARNING | references/services.md — Rules |

### Views (`app/views/**/*.erb`)

| Check | Severity | Convention |
|---|---|---|
| JS inline (`<script>` tags) | VIOLATION | references/views-hotwire.md → better-stimulus |
| `form_for` ou `form_tag` au lieu de `form_with` | VIOLATION | references/views-hotwire.md — Forms |
| Logique métier dans les vues (`.where(`, `.count`, `.find(`) | WARNING | references/views-hotwire.md — Anti-patterns |

### Jobs (`app/jobs/*.rb`)

| Check | Severity | Convention |
|---|---|---|
| Pas de guard d'idempotence (pas de `return if` en début de perform) | WARNING | references/jobs.md — Idempotence |
| Objets Ruby passés en argument au lieu d'IDs | VIOLATION | references/jobs.md — Arguments |

### Tests (`spec/**/*_spec.rb`)

| Check | Severity | Convention |
|---|---|---|
| Fixtures au lieu de factories | VIOLATION | references/tests.md — Factories |
| Absence de feature specs pour les controllers avec vues | WARNING | references/tests.md — Feature Specs |

## Format du rapport

```
## Rails Conventions Audit

### Summary
| Domain      | Violations | Warnings | OK |
|-------------|-----------|----------|-----|
| Models      | 1         | 2        | 5   |
| Controllers | 0         | 1        | 4   |
| Services    | 0         | 3        | 2   |
| Views       | 0         | 0        | 3   |
| Jobs        | 0         | 1        | 1   |
| Tests       | 0         | 1        | 1   |

### Models — 1 violation, 2 warnings

**VIOLATION** `app/models/subject.rb:15` — `has_many :parts` missing `dependent:`
> Convention: Always declare `dependent:` on `has_many` (ref: references/models.md)

**WARNING** `app/models/student.rb:28` — `after_save :update_insights`
> Convention: Limit callbacks to `before_validation` and `after_create_commit`

### Controllers — 0 violations, 1 warning
...
```

## Severity

- **VIOLATION** — code qui contredit directement une convention documentée
- **WARNING** — code qui pourrait poser problème mais peut être intentionnel

## Ce qui change

- `~/.claude/skills/rails-conventions/SKILL.md` — ajout d'une section `## Audit Mode` (~50 lignes)

## Ce qui ne change PAS

- Les 6 fichiers `references/*.md` — inchangés
- Le `.mcp.json` — inchangé
- Le comportement d'activation automatique du skill — inchangé

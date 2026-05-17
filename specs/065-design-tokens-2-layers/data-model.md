# Data Model: B1 Design Tokens 2 Layers

**Date** : 2026-05-17
**Spec** : [spec.md](./spec.md) — FR-001 à FR-013

> Cette feature n'utilise pas de modèle ActiveRecord. Le « data model » ici décrit la structure des **tokens CSS** et leurs relations. Aucune migration de base de données.

---

## Vue d'ensemble

3 entités, 0 cycle de vie (les tokens sont statiques) :

```
Primitive (couleur absolue)
   ↑ référencée par
Sémantique (rôle d'usage, varie selon audience × mode)
   ↑ aliasée par
Alias rétrocompatible (--color-rad-*, pointe vers une primitive ou sémantique)
```

---

## 1. Primitive

**Définition** : couleur absolue nommée par essence visuelle (martiniquaise). Source de vérité ultime. Jamais consommée directement par les vues, les composants ou les classes Tailwind.

**Naming convention** : `--rad-prim-<essence>` — `rad` (Radical), `prim` (primitive), `<essence>` (nom évocateur, pas un usage).

**Attributs** :
| Champ | Type | Description |
|---|---|---|
| `name` | identifier (CSS var name) | Nom de la primitive, ex: `--rad-prim-balisier-red` |
| `value_light` | hex color | Valeur en mode clair |
| `value_dark` | hex color \| null | Valeur en mode sombre (null = même que light, ex: `--rad-prim-cream`) |

**Liste exhaustive des primitives** (~ 13 couleurs + utilitaires) :

| Primitive | Light hex | Dark hex | Origine |
|---|---|---|---|
| `--rad-prim-cream` | `#fbf7ee` | `#fbf7ee` (identique) | Background light & accent text light/dark |
| `--rad-prim-paper` | `#ffffff` | `#143b40` | Surface light (white pure), surface dark (deep teal) |
| `--rad-prim-raise` | `#fdfaf3` | `#1a4a50` | Surface élevée |
| `--rad-prim-warm` | `#e8e0cc` | `#1a4a50` | Beige chaud (tutor drawer header) — équivalent `raise` en dark |
| `--rad-prim-ink` | `#0e1b1f` | `#f5ecdc` | Texte profond / inverse en dark |
| `--rad-prim-muted-light` | `#6b665a` | — | Muted text light |
| `--rad-prim-muted-dark` | — | `#a8c2c5` | Muted text dark |
| `--rad-prim-rule-light` | `#e6dcc1` | — | Border / rule light |
| `--rad-prim-rule-dark` | — | `#22585e` | Border / rule dark |
| `--rad-prim-balisier-red` | `#d4452e` | `#e85a44` | Accent rouge (élève primary, alert) |
| `--rad-prim-sun-yellow` | `#e8b53f` | `#f0c25e` | Accent jaune (warning, highlight) |
| `--rad-prim-sea-teal` | `#127566` | `#5fc5b8` | Accent teal (teacher primary, info, secondary élève) |
| `--rad-prim-grass-green` | `#2e8b3a` | `#7bc77a` | Accent vert (success, correction validée) |

**Validation rules** :
- Chaque primitive DOIT avoir une valeur light ; les variantes dark sont obligatoires uniquement pour les tons utilisés en dark mode (toutes sauf `cream` ici).
- Une primitive ne référence JAMAIS une autre primitive ni un sémantique. C'est terminal.
- Le nom NE DOIT PAS contenir d'usage (« primary », « surface », « bg ») — c'est le rôle des sémantiques.

**Relations** : aucune (entité terminale).

---

## 2. Sémantique

**Définition** : rôle d'usage abstrait, indépendant de la palette. Pointe vers une primitive **différente selon l'audience × le mode**. C'est ce que les vues et composants consomment.

**Naming convention** : `--color-<role>` — préfixe `--color-` (cohérent avec Tailwind `@theme` qui génère des utilitaires `bg-<role>`, `text-<role>`, `border-<role>`), `<role>` est un mot ou un compound (`surface`, `on-surface-muted`, `accent-primary`).

**Attributs** :
| Champ | Type | Description |
|---|---|---|
| `name` | identifier (CSS var name) | Nom du sémantique, ex: `--color-accent-primary` |
| `default_primitive` | reference to Primitive | Valeur par défaut, utilisée dans `@theme` (= student-light) |
| `student_light`, `student_dark` | reference to Primitive | Mapping pour `body[data-audience="student"]` |
| `teacher_light`, `teacher_dark` | reference to Primitive | Mapping pour `body[data-audience="teacher"]` |
| `public_light`, `public_dark` | reference to Primitive | Mapping pour `body[data-audience="public"]` |

**Liste exhaustive des 19 tokens sémantiques garantis (FR-003)** avec leur mapping par audience/mode :

### Surfaces (3)

| Sémantique | student-light | student-dark | teacher-light | teacher-dark | public-light | public-dark |
|---|---|---|---|---|---|---|
| `--color-surface` | `paper` (white) | `paper` (#143b40) | `paper` | `paper` | `paper` | `paper` |
| `--color-surface-raised` | `raise` | `raise` | `raise` | `raise` | `raise` | `raise` |
| `--color-surface-sunken` | `cream` | `paper` (#143b40) | `cream` | `paper` | `cream` | `paper` |

*Surface = canvas neutre, identique entre audiences. Sunken = bg-page derrière cards.*

### Textes (2)

| Sémantique | student-light | student-dark | teacher-light | teacher-dark | public-light | public-dark |
|---|---|---|---|---|---|---|
| `--color-on-surface` | `ink` (#0e1b1f) | `ink` (#f5ecdc) | idem | idem | idem | idem |
| `--color-on-surface-muted` | `muted-light` | `muted-dark` | idem | idem | idem | idem |

*Textes identiques entre audiences (la sobriété teacher se joue ailleurs).*

### Rules / borders (2)

| Sémantique | student-light | student-dark | teacher-light | teacher-dark | public-light | public-dark |
|---|---|---|---|---|---|---|
| `--color-rule` | `rule-light` (#e6dcc1) | `rule-dark` (#22585e) | idem | idem | idem | idem |
| `--color-rule-strong` | `muted-light` (`#6b665a`) | `muted-dark` (`#a8c2c5`) | idem | idem | idem | idem |

*Rule = bordure douce, rule-strong = bordure marquée (cards, inputs focus).*

### Brand accents (4 : 2 × on)

| Sémantique | student-light | student-dark | teacher-light | teacher-dark | public-light | public-dark |
|---|---|---|---|---|---|---|
| `--color-accent-primary` | `balisier-red` (#d4452e) | `balisier-red` (#e85a44) | **`sea-teal`** (#127566) | **`sea-teal`** (#5fc5b8) | `balisier-red` | `balisier-red` |
| `--color-on-accent-primary` | `cream` | `cream` | `cream` | `ink` (#f5ecdc) | `cream` | `cream` |
| `--color-accent-secondary` | `sea-teal` (#127566) | `sea-teal` (#5fc5b8) | `balisier-red` (#d4452e) | `balisier-red` (#e85a44) | `sea-teal` | `sea-teal` |
| `--color-on-accent-secondary` | `cream` | `ink` | `cream` | `cream` | `cream` | `ink` |

*Seuls les accents brand divergent entre audiences. C'est LE point central du système.*

### États (8 : 4 × on)

| Sémantique | student-light | student-dark | teacher-light | teacher-dark | public-light | public-dark |
|---|---|---|---|---|---|---|
| `--color-success` | `grass-green` (#2e8b3a) | `grass-green` (#7bc77a) | idem | idem | idem | idem |
| `--color-on-success` | `cream` | `ink` | idem | idem | idem | idem |
| `--color-warning` | `sun-yellow` (#e8b53f) | `sun-yellow` (#f0c25e) | idem | idem | idem | idem |
| `--color-on-warning` | `ink` | `ink` | idem | idem | idem | idem |
| `--color-danger` | `balisier-red` (#d4452e) | `balisier-red` (#e85a44) | idem | idem | idem | idem |
| `--color-on-danger` | `cream` | `cream` | idem | idem | idem | idem |
| `--color-info` | `sea-teal` (#127566) | `sea-teal` (#5fc5b8) | idem | idem | idem | idem |
| `--color-on-info` | `cream` | `ink` | idem | idem | idem | idem |

*États sémantiques identiques entre audiences. Succès reste vert, danger reste rouge, etc. — sémantique universelle.*

**Validation rules** :
- Chaque sémantique DOIT avoir 6 valeurs définies (3 audiences × 2 modes).
- La valeur par défaut dans `@theme { --color-X: …; }` doit être **identique** à `student-light` (rétrocompat avec l'existant : sans `data-audience`, on rend comme aujourd'hui = student).
- Un sémantique pointe TOUJOURS vers une primitive, JAMAIS vers un autre sémantique ni vers un alias.
- Le nom NE DOIT PAS contenir une couleur (« --color-red », « --color-yellow ») — c'est le rôle des primitives. Exception : aucune ici.

**Relations** :
- N → 1 vers Primitive (6 références par sémantique).

---

## 3. Alias rétrocompatible

**Définition** : ancien token `--color-rad-*` (12 entrées historiques) conservé pour ne pas casser les vues/composants existants qui le consomment. Devient une référence vers la nouvelle couche.

**Naming convention** : préservé tel quel (`--color-rad-bg`, `--color-rad-paper`, `--color-rad-red`, etc.).

**Attributs** :
| Champ | Type | Description |
|---|---|---|
| `name` | identifier | Ancien nom, préservé |
| `target` | reference to Primitive OR Semantic | Ce vers quoi pointe l'alias |
| `target_kind` | enum {primitive, semantic} | Type de cible |

**Mapping exhaustif des 12 aliases** :

| Alias historique | Cible recommandée | Type | Note |
|---|---|---|---|
| `--color-rad-bg` | `--color-surface-sunken` | semantic | bg-page = sunken |
| `--color-rad-paper` | `--color-surface` | semantic | paper = surface principale |
| `--color-rad-raise` | `--color-surface-raised` | semantic | raised |
| `--color-rad-text` | `--color-on-surface` | semantic | texte sur surface |
| `--color-rad-muted` | `--color-on-surface-muted` | semantic | muted text |
| `--color-rad-rule` | `--color-rule` | semantic | border |
| `--color-rad-red` | `--rad-prim-balisier-red` | primitive | accent rouge brut (utilisé librement par les vues élève) |
| `--color-rad-yellow` | `--rad-prim-sun-yellow` | primitive | jaune brut |
| `--color-rad-teal` | `--rad-prim-sea-teal` | primitive | teal brut |
| `--color-rad-green` | `--rad-prim-grass-green` | primitive | vert brut (cf. correction screen) |
| `--color-rad-ink` | `--rad-prim-ink` | primitive | ink |
| `--color-rad-cream` | `--rad-prim-cream` | primitive | cream |
| `--color-rad-warm` | `--rad-prim-warm` | primitive | beige chaud tutor drawer |

**Choix** :
- Les aliases qui ont un **rôle clair** (bg, paper, raise, text, muted, rule) pointent vers une sémantique → bénéficient automatiquement du mapping par audience.
- Les aliases qui sont des **couleurs brutes** (red, yellow, teal, green, ink, cream, warm) pointent vers une primitive → comportement strictement identique à aujourd'hui (pas d'override par audience), car les vues qui les consomment ne s'attendent pas à un comportement adaptatif.

**Conséquence importante** : sur le layout teacher, `--color-rad-red` reste rouge (pas adaptatif). Si une vue teacher consomme `bg-rad-red`, elle reste rouge sur teacher. C'est **voulu** pour B1 (rétrocompat 100 %). La transition « bg-rad-red → bg-accent-primary » côté élève sera traitée en B4 (et côté teacher en B5).

**Validation rules** :
- Aucun alias n'est ajouté ou supprimé dans B1 (les 12 historiques restent, à l'identique de nom).
- Aucune nouvelle classe Tailwind `bg-rad-*` n'est créée dans B1 (le bridge maintient celles existantes).
- Si un futur retrait d'alias est envisagé (post-B5), il sera traité en feature dédiée avec migration de tous les consommateurs.

**Relations** :
- 1 → 1 vers Primitive ou Semantic.

---

## Hiérarchie de cascade CSS (résumé)

Ordre de résolution pour `bg-accent-primary` sur une page teacher en mode dark :

1. `@theme { --color-accent-primary: var(--rad-prim-balisier-red); }` → fallback
2. `body[data-audience="teacher"] { --color-accent-primary: var(--rad-prim-sea-teal); }` → spécificité 0,1,1
3. `html.dark body[data-audience="teacher"] { --color-accent-primary: var(--rad-prim-sea-teal); }` → spécificité 0,2,2 → **GAGNE**
4. Valeur finale du computed style : `#5fc5b8` (sea-teal dark)

Pour `bg-rad-red` sur une page élève light :

1. `@theme { --color-rad-red: var(--rad-prim-balisier-red); }` → application
2. Valeur finale : `#d4452e` — strictement identique à aujourd'hui.

---

## Glossaire

- **Audience** : identité visuelle pilotée par `data-audience` sur `<body>` (`student`, `teacher`, `public`).
- **Mode** : variante claire/sombre pilotée par classe `.dark` sur `<html>` (mécanisme existant).
- **Primitive** : couleur absolue. Source de vérité.
- **Sémantique** : rôle d'usage abstrait. Consommé par les vues.
- **Alias** : ancien token conservé pour rétrocompat.
- **Bridge** : ensemble des aliases qui assurent la continuité d'usage des `--color-rad-*` actuels.

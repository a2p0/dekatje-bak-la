# Design Tokens — Radical palette

**Date :** 2026-04-30
**Scope :** PR tokens uniquement — aucune vue ERB, aucun ViewComponent modifié
**Branche cible :** feature branch → main via PR

---

## Contexte

Le design "Radical" (approuvé via claude.ai/design, bundle exporté) remplace le design system 025 (indigo→violet gradient + Plus Jakarta Sans) par une identité martiniquaise : crème/balisier rouge/soleil jaune/mer teal, typographie Fraunces (display) + Inter (corps) + JetBrains Mono (technique).

Cette PR est la première d'une série de 5 :
1. **Tokens** (cette PR) — fonts, palette, utilitaires CSS
2. subjects/show — 6 états redesignés
3. questions/show — écran lecture + FAB Tibo
4. _correction — écran révision + DataHintsComponent
5. _drawer — chat tutorat

---

## Fonts

### Stratégie : auto-hébergement WOFF2 variable (option A)

Même pattern que Plus Jakarta Sans existante. Pas de CDN, pas de npm.

Fichiers à télécharger via google-webfonts-helper et déposer dans `app/assets/fonts/` :

| Fichier | Subsets |
|---|---|
| `fraunces-variable-latin.woff2` | latin |
| `fraunces-variable-latin-ext.woff2` | latin-ext |
| `inter-variable-latin.woff2` | latin |
| `inter-variable-latin-ext.woff2` | latin-ext |
| `jetbrains-mono-variable-latin.woff2` | latin |

Un fichier CSS `@font-face` par famille dans `app/assets/fonts/` :
- `fraunces.css`
- `inter.css`
- `jetbrains-mono.css`

Chaque fichier suit le pattern de `plus-jakarta-sans.css` :
- `font-display: swap`
- `font-weight: 100 900` (variable font range)
- `unicode-range` approprié par subset

### Plus Jakarta Sans — conservée

PJSans reste importée et active. Elle est réaffectée au token `--font-teacher` pour l'espace enseignant (non redesigné dans cette série). Elle sera supprimée dans une PR ultérieure quand l'espace enseignant sera redesigné.

### Tokens Tailwind

Ajoutés dans le bloc `@theme` de `app/assets/tailwind/application.css` :

```css
--font-sans:    'Inter', system-ui, sans-serif;
--font-serif:   'Fraunces', serif;
--font-mono:    'JetBrains Mono', monospace;
--font-teacher: 'Plus Jakarta Sans', system-ui, sans-serif;
```

> `--font-sans`, `--font-serif`, `--font-mono` sont des tokens reconnus par Tailwind 4 et génèrent automatiquement les classes `font-sans`, `font-serif`, `font-mono`. `--font-teacher` est un token custom qui générera la classe `font-teacher`.

`--font-sans` passe de Plus Jakarta Sans à Inter. Les vues enseignant devront explicitement utiliser `font-teacher` si besoin — mais en pratique elles ne spécifient pas de font custom, elles héritent du body. Le body restera `font-sans` (Inter). Cela est acceptable : Inter et PJSans sont visuellement très proches pour le corps de texte.

---

## Palette de couleurs

### Tokens supprimés

```css
--color-primary-gradient-from   /* #6366f1 indigo */
--color-primary-gradient-to     /* #8b5cf6 violet */
--shadow-glow-indigo
--shadow-glow-indigo-sm
--shadow-glow-emerald
```

Ces tokens ne sont pas utilisés dans les vues élève redesignées. Les vues enseignant utilisent les classes Tailwind directement (`from-indigo-500`, `to-violet-500`, etc.) — elles ne dépendent pas de ces tokens custom et ne régressent pas.

### Tokens ajoutés — Radical palette

Dans `@theme` :

```css
/* Radical — Light (valeurs par défaut) */
--color-rad-bg:     #fbf7ee;
--color-rad-paper:  #ffffff;
--color-rad-raise:  #fdfaf3;
--color-rad-text:   #0e1b1f;
--color-rad-muted:  #6b665a;
--color-rad-rule:   #e6dcc1;
--color-rad-red:    #d4452e;
--color-rad-yellow: #e8b53f;
--color-rad-teal:   #127566;
--color-rad-green:  #2e8b3a;
--color-rad-ink:    #0e1b1f;
--color-rad-cream:  #fbf7ee;
```

### Dark mode — surcharge `.dark`

Le dark mode actuel utilise `@custom-variant dark (&:where(.dark, .dark *))` — même mécanisme.

Ajout d'un bloc CSS (hors `@theme`, dans la feuille principale) :

```css
.dark {
  --color-rad-bg:     #0f2f33;
  --color-rad-paper:  #143b40;
  --color-rad-raise:  #1a4a50;
  --color-rad-text:   #f5ecdc;
  --color-rad-muted:  #a8c2c5;
  --color-rad-rule:   #22585e;
  --color-rad-red:    #e85a44;
  --color-rad-yellow: #f0c25e;
  --color-rad-teal:   #5fc5b8;
  --color-rad-green:  #7bc77a;
  --color-rad-ink:    #f5ecdc;
  /* rad-cream reste #fbf7ee en dark aussi */
}
```

### Ce qui ne change pas

Les couleurs Tailwind utilitaires (`slate-*`, `indigo-*`, `emerald-*`, `amber-*`) restent disponibles. Les vues enseignant les utilisent directement et ne régressent pas.

---

## Utilitaires CSS

### `.pattern-madras`

Classe utilitaire ajoutée dans `application.css` (hors `@theme`).
Utilisée sur les hero cards (état 3 subjects/show, carte correction révision) avec `opacity: 0.15–0.18` :

```css
.pattern-madras {
  background-image:
    repeating-linear-gradient(0deg,   rgba(0,0,0,0.05) 0 1px, transparent 1px 22px),
    repeating-linear-gradient(90deg,  rgba(0,0,0,0.05) 0 1px, transparent 1px 22px),
    repeating-linear-gradient(0deg,   rgba(0,0,0,0.04) 0 1px, transparent 1px 7px),
    repeating-linear-gradient(90deg,  rgba(0,0,0,0.04) 0 1px, transparent 1px 7px);
}
```

### `.scroll-hide`

Déjà présent dans le prototype HTML. Vérifier s'il existe dans l'app — si non, ajouter :

```css
.scroll-hide::-webkit-scrollbar { display: none; }
.scroll-hide { -ms-overflow-style: none; scrollbar-width: none; }
```

---

## Périmètre strict

### Fichiers modifiés

- `app/assets/tailwind/application.css` — tokens `@theme` + dark overrides + `.pattern-madras` + `.scroll-hide`

### Fichiers ajoutés

- `app/assets/fonts/fraunces.css`
- `app/assets/fonts/inter.css`
- `app/assets/fonts/jetbrains-mono.css`
- `app/assets/fonts/fraunces-variable-latin.woff2`
- `app/assets/fonts/fraunces-variable-latin-ext.woff2`
- `app/assets/fonts/inter-variable-latin.woff2`
- `app/assets/fonts/inter-variable-latin-ext.woff2`
- `app/assets/fonts/jetbrains-mono-variable-latin.woff2`

### Fichiers NON modifiés

- Aucune vue ERB
- Aucun ViewComponent
- Aucun controller
- Aucune migration

---

## Tests / validation

Pas de RSpec pour ce changement (purement CSS/assets).

Validation manuelle :
1. `bin/dev` — vérifier que Tailwind compile sans erreur
2. Ouvrir un écran élève en light mode → les fonts et couleurs ne doivent pas changer (les vues élève utilisent encore les classes slate/indigo actuelles — les nouveaux tokens `rad-*` ne sont pas encore utilisés)
3. Ouvrir un écran enseignant → aucune régression
4. Toggle dark mode → aucune régression
5. Vérifier dans DevTools que Fraunces, Inter, JetBrains Mono sont bien chargées (Network tab)

> Note : les tokens `rad-*` ne seront visibles dans l'UI qu'à partir de la PR 2 (subjects/show). Cette PR pose uniquement l'infrastructure.

---

## Décisions reportées

- Suppression de Plus Jakarta Sans → PR redesign espace enseignant (hors scope série actuelle)
- Composant `<Stripes>` (bande 4 couleurs) → PR 2 subjects/show (décider ViewComponent vs partial vs classe CSS)

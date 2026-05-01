# Design Tokens — Radical palette — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poser l'infrastructure du design system "Radical" (fonts + palette + utilitaires CSS) sans modifier aucune vue ERB ni ViewComponent.

**Architecture:** Trois nouvelles fonts auto-hébergées en WOFF2 variable (Fraunces, Inter, JetBrains Mono) déposées dans `app/assets/fonts/` avec leurs fichiers `@font-face`. Les tokens Tailwind 4 sont ajoutés dans `@theme` de `application.css`. La palette `rad-*` est définie en light et surchargée en dark via `.dark {}`. Plus Jakarta Sans est conservée sous le token `--font-teacher`.

**Tech Stack:** Rails 8 + Propshaft + tailwindcss-rails (gem standalone, pas de Node). WOFF2 variable fonts téléchargées manuellement via google-webfonts-helper.

**Spec de référence:** `docs/superpowers/specs/2026-04-30-design-tokens-radical-design.md`

---

## File Map

| Action | Fichier | Responsabilité |
|---|---|---|
| Créer | `app/assets/fonts/fraunces.css` | `@font-face` Fraunces variable |
| Créer | `app/assets/fonts/inter.css` | `@font-face` Inter variable |
| Créer | `app/assets/fonts/jetbrains-mono.css` | `@font-face` JetBrains Mono variable |
| Créer | `app/assets/fonts/fraunces-variable-latin.woff2` | Fichier font binaire |
| Créer | `app/assets/fonts/fraunces-variable-latin-ext.woff2` | Fichier font binaire |
| Créer | `app/assets/fonts/inter-variable-latin.woff2` | Fichier font binaire |
| Créer | `app/assets/fonts/inter-variable-latin-ext.woff2` | Fichier font binaire |
| Créer | `app/assets/fonts/jetbrains-mono-variable-latin.woff2` | Fichier font binaire |
| Modifier | `app/assets/tailwind/application.css` | Tokens `@theme`, dark overrides, utilitaires |

---

## Task 1 : Créer une branche feature

**Files:**
- (aucun fichier modifié)

- [ ] **Step 1 : Créer la branche**

```bash
git checkout -b 053-design-tokens-radical
```

Expected : prompt bascule sur `053-design-tokens-radical`.

---

## Task 2 : Télécharger les WOFF2 variable fonts

**Files:**
- Créer : `app/assets/fonts/fraunces-variable-latin.woff2`
- Créer : `app/assets/fonts/fraunces-variable-latin-ext.woff2`
- Créer : `app/assets/fonts/inter-variable-latin.woff2`
- Créer : `app/assets/fonts/inter-variable-latin-ext.woff2`
- Créer : `app/assets/fonts/jetbrains-mono-variable-latin.woff2`

> Les fichiers WOFF2 sont binaires — ils doivent être téléchargés manuellement, pas générés. Utiliser google-webfonts-helper (https://gwfh.mranftl.com) ou les URLs directes Google Fonts.

- [ ] **Step 1 : Télécharger Fraunces (latin + latin-ext)**

```bash
# Fraunces variable — latin
curl -L "https://fonts.gstatic.com/s/fraunces/v31/6NUh8FyLNQOQZAnv9bYEvDiIdE9Ea92uemAk_WBq8U_9v0c2Fo0Nuo_Z.woff2" \
  -o app/assets/fonts/fraunces-variable-latin.woff2

# Fraunces variable — latin-ext
curl -L "https://fonts.gstatic.com/s/fraunces/v31/6NUh8FyLNQOQZAnv9bYEvDiIdE9Ea92uemAk_WBq8U_9v0c2Fo0Nuo_a8U_9.woff2" \
  -o app/assets/fonts/fraunces-variable-latin-ext.woff2
```

> Si ces URLs Google Fonts ne fonctionnent plus (elles changent parfois), utiliser google-webfonts-helper :
> 1. Aller sur https://gwfh.mranftl.com/fonts/fraunces
> 2. Sélectionner subsets : latin + latin-ext
> 3. Sélectionner "modern browsers" (woff2 uniquement)
> 4. Télécharger le zip, extraire les fichiers variable dans `app/assets/fonts/`

- [ ] **Step 2 : Télécharger Inter (latin + latin-ext)**

```bash
# Inter variable — latin
curl -L "https://fonts.gstatic.com/s/inter/v18/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyfAZ9hiJ-Ek-_EeA.woff2" \
  -o app/assets/fonts/inter-variable-latin.woff2

# Inter variable — latin-ext
curl -L "https://fonts.gstatic.com/s/inter/v18/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyfAZ9hiJ-Ek-_EeAe.woff2" \
  -o app/assets/fonts/inter-variable-latin-ext.woff2
```

> Même fallback : https://gwfh.mranftl.com/fonts/inter — subsets latin + latin-ext, modern browsers.

- [ ] **Step 3 : Télécharger JetBrains Mono (latin uniquement)**

```bash
# JetBrains Mono variable — latin
curl -L "https://fonts.gstatic.com/s/jetbrainsmono/v20/tDbY2o-flEEny0FZhsfKu5WU4zr3E_BX0PnT8RD8yKxTOlOTk6OThhvA.woff2" \
  -o app/assets/fonts/jetbrains-mono-variable-latin.woff2
```

> Fallback : https://gwfh.mranftl.com/fonts/jetbrains-mono — subset latin uniquement (le code technique n'a pas besoin de latin-ext).

- [ ] **Step 4 : Vérifier que les fichiers sont bien des WOFF2**

```bash
file app/assets/fonts/fraunces-variable-latin.woff2
file app/assets/fonts/inter-variable-latin.woff2
file app/assets/fonts/jetbrains-mono-variable-latin.woff2
```

Expected : chaque ligne affiche `Web Open Font Format (Version 2)` ou `data`. Si un fichier affiche `HTML document` ou `ASCII text`, l'URL a redirigé vers une page d'erreur — retélécharger via google-webfonts-helper.

---

## Task 3 : Créer les fichiers @font-face CSS

**Files:**
- Créer : `app/assets/fonts/fraunces.css`
- Créer : `app/assets/fonts/inter.css`
- Créer : `app/assets/fonts/jetbrains-mono.css`

- [ ] **Step 1 : Créer `app/assets/fonts/fraunces.css`**

```css
/* Fraunces — self-hosted variable font, latin + latin-ext subsets */

/* latin-ext */
@font-face {
  font-family: 'Fraunces';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("fraunces-variable-latin-ext.woff2") format("woff2");
  unicode-range: U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}

/* latin */
@font-face {
  font-family: 'Fraunces';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("fraunces-variable-latin.woff2") format("woff2");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}

/* latin-ext italic */
@font-face {
  font-family: 'Fraunces';
  font-style: italic;
  font-weight: 100 900;
  font-display: swap;
  src: url("fraunces-variable-latin-ext.woff2") format("woff2");
  unicode-range: U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}

/* latin italic */
@font-face {
  font-family: 'Fraunces';
  font-style: italic;
  font-weight: 100 900;
  font-display: swap;
  src: url("fraunces-variable-latin.woff2") format("woff2");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
```

> Fraunces a une variable optique + italic — les 4 blocs `@font-face` couvrent normal/italic × latin/latin-ext pour que `font-style: italic` fonctionne bien (titres, numéros de question en italique dans le design).

- [ ] **Step 2 : Créer `app/assets/fonts/inter.css`**

```css
/* Inter — self-hosted variable font, latin + latin-ext subsets */

/* latin-ext */
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("inter-variable-latin-ext.woff2") format("woff2");
  unicode-range: U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}

/* latin */
@font-face {
  font-family: 'Inter';
  font-style: normal;
  font-weight: 100 900;
  font-display: swap;
  src: url("inter-variable-latin.woff2") format("woff2");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
```

- [ ] **Step 3 : Créer `app/assets/fonts/jetbrains-mono.css`**

```css
/* JetBrains Mono — self-hosted variable font, latin subset */

/* latin */
@font-face {
  font-family: 'JetBrains Mono';
  font-style: normal;
  font-weight: 100 800;
  font-display: swap;
  src: url("jetbrains-mono-variable-latin.woff2") format("woff2");
  unicode-range: U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
```

---

## Task 4 : Mettre à jour application.css

**Files:**
- Modifier : `app/assets/tailwind/application.css`

État actuel du fichier :
```css
@import "tailwindcss";
@import "../fonts/plus-jakarta-sans.css";

@custom-variant dark (&:where(.dark, .dark *));

@theme {
  --font-sans: 'Plus Jakarta Sans', system-ui, sans-serif;
  --color-primary-gradient-from: #6366f1;
  --color-primary-gradient-to: #8b5cf6;
  --shadow-glow-indigo: 0 0 16px rgba(99, 102, 241, 0.3);
  --shadow-glow-indigo-sm: 0 0 8px rgba(99, 102, 241, 0.1);
  --shadow-glow-emerald: 0 0 12px rgba(16, 185, 129, 0.2);
  --radius-card: 1rem;
  --radius-button: 0.75rem;
  --radius-input: 0.75rem;
  --radius-pill: 9999px;
  --z-bottom-bar: 30;
  --z-backdrop: 40;
  --z-sidebar: 50;
  --z-chat-drawer: 50;
  --z-modal: 60;
  --transition-fast: 150ms ease;
  --transition-normal: 300ms ease;
}

@media (prefers-reduced-motion: reduce) { ... }
```

- [ ] **Step 1 : Remplacer le contenu de `app/assets/tailwind/application.css`**

```css
@import "tailwindcss";

/* Self-hosted fonts */
@import "../fonts/plus-jakarta-sans.css";
@import "../fonts/fraunces.css";
@import "../fonts/inter.css";
@import "../fonts/jetbrains-mono.css";

/* Dark mode via class strategy (toggle .dark on <html>) */
@custom-variant dark (&:where(.dark, .dark *));

/* Design tokens */
@theme {
  /* Fonts */
  --font-sans:    'Inter', system-ui, sans-serif;
  --font-serif:   'Fraunces', serif;
  --font-mono:    'JetBrains Mono', monospace;
  --font-teacher: 'Plus Jakarta Sans', system-ui, sans-serif;

  /* Radical palette — light (default) */
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

  /* Border radius */
  --radius-card:   1rem;
  --radius-button: 0.75rem;
  --radius-input:  0.75rem;
  --radius-pill:   9999px;

  /* Z-index scale */
  --z-bottom-bar:  30;
  --z-backdrop:    40;
  --z-sidebar:     50;
  --z-chat-drawer: 50;
  --z-modal:       60;

  /* Transitions */
  --transition-fast:   150ms ease;
  --transition-normal: 300ms ease;
}

/* Radical palette — dark overrides */
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
  /* rad-cream reste #fbf7ee en dark */
}

/* Madras-inspired subtle grid pattern (used on hero cards) */
.pattern-madras {
  background-image:
    repeating-linear-gradient(0deg,   rgba(0,0,0,0.05) 0 1px, transparent 1px 22px),
    repeating-linear-gradient(90deg,  rgba(0,0,0,0.05) 0 1px, transparent 1px 22px),
    repeating-linear-gradient(0deg,   rgba(0,0,0,0.04) 0 1px, transparent 1px 7px),
    repeating-linear-gradient(90deg,  rgba(0,0,0,0.04) 0 1px, transparent 1px 7px);
}

/* Hide scrollbars while keeping scroll functionality */
.scroll-hide::-webkit-scrollbar { display: none; }
.scroll-hide { -ms-overflow-style: none; scrollbar-width: none; }

/* Reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}
```

> Tokens supprimés volontairement : `--color-primary-gradient-from/to`, `--shadow-glow-indigo`, `--shadow-glow-indigo-sm`, `--shadow-glow-emerald`. Ces tokens n'étaient pas utilisés dans les vues via `var()` — les vues utilisent directement `from-indigo-500`, `shadow-[0_0_16px_...]` etc. Leur suppression ne casse rien.

---

## Task 5 : Vérifier la compilation Tailwind

**Files:**
- (lecture seule)

- [ ] **Step 1 : Lancer la compilation**

```bash
bundle exec rails tailwindcss:build 2>&1 | tail -20
```

Expected : se termine sans erreur, dernière ligne ressemble à `Done in Xs.` ou similaire. Aucune ligne `ERROR` ou `Cannot resolve`.

- [ ] **Step 2 : Vérifier que les tokens sont présents dans le CSS compilé**

```bash
grep -c "rad-bg\|rad-red\|fraunces\|JetBrains" app/assets/builds/tailwind.css
```

Expected : un nombre > 0 (au moins quelques occurrences des nouveaux tokens dans le build).

---

## Task 6 : Vérifier que les fonts se chargent en dev

**Files:**
- (lecture seule)

- [ ] **Step 1 : Lancer le serveur de dev**

```bash
bin/dev
```

- [ ] **Step 2 : Vérifier manuellement dans le navigateur**

1. Ouvrir `http://localhost:3000` (ou l'URL de dev habituelle)
2. Ouvrir DevTools → onglet Network → filtrer sur "Font" ou "woff2"
3. Recharger la page
4. Vérifier que des requêtes vers `fraunces-variable-latin.woff2`, `inter-variable-latin.woff2`, `jetbrains-mono-variable-latin.woff2` apparaissent avec status 200

> Les fonts ne seront pas visibles dans l'UI à ce stade (les vues n'utilisent pas encore `font-serif` / `font-mono`). Ce qu'on vérifie ici c'est que les fichiers sont servis correctement par Propshaft.

- [ ] **Step 3 : Vérifier aucune régression visuelle**

1. Naviguer vers un écran enseignant (ex: `/teacher/subjects`)
2. Vérifier que le texte s'affiche correctement (Inter remplace PJSans — visuellement quasi-identique)
3. Toggler dark mode → vérifier que les couleurs slate/indigo des vues enseignant ne changent pas
4. Naviguer vers un écran élève (ex: une question) → même vérification

---

## Task 7 : Commit et push

**Files:**
- (git)

- [ ] **Step 1 : Stager tous les nouveaux fichiers**

```bash
git add app/assets/fonts/fraunces.css \
        app/assets/fonts/inter.css \
        app/assets/fonts/jetbrains-mono.css \
        app/assets/fonts/fraunces-variable-latin.woff2 \
        app/assets/fonts/fraunces-variable-latin-ext.woff2 \
        app/assets/fonts/inter-variable-latin.woff2 \
        app/assets/fonts/inter-variable-latin-ext.woff2 \
        app/assets/fonts/jetbrains-mono-variable-latin.woff2 \
        app/assets/tailwind/application.css
```

- [ ] **Step 2 : Vérifier le diff avant de commiter**

```bash
git diff --staged --stat
```

Expected : 9 fichiers — 8 créations (fonts) + 1 modification (application.css). Aucun fichier ERB ou Ruby.

- [ ] **Step 3 : Commiter**

```bash
git commit -m "$(cat <<'EOF'
feat(design): add Radical design tokens — fonts, palette, CSS utilities

Fraunces + Inter + JetBrains Mono auto-hébergées en WOFF2 variable.
Palette balisier/crème/teal avec dark mode teal profond (#0f2f33).
Ajout .pattern-madras et .scroll-hide. Suppression tokens gradient indigo.
Plus Jakarta Sans conservée sous --font-teacher pour l'espace enseignant.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4 : Pousser la branche**

```bash
git push -u origin 053-design-tokens-radical
```

---

## Task 8 : Ouvrir la PR

- [ ] **Step 1 : Créer la PR**

```bash
gh pr create \
  --title "feat(design): Radical design tokens — fonts, palette, CSS utilities" \
  --body "$(cat <<'EOF'
## Summary

- Fraunces, Inter, JetBrains Mono auto-hébergées en WOFF2 variable dans `app/assets/fonts/`
- Palette Radical (`rad-*`) ajoutée dans `@theme` : balisier rouge, soleil jaune, mer teal, crème
- Dark mode teal profond (`#0f2f33`) via surcharge `.dark {}` — remplace le quasi-noir 025
- `.pattern-madras` et `.scroll-hide` ajoutés comme utilitaires CSS
- Tokens gradient indigo (`--color-primary-gradient-from/to`, `--shadow-glow-*`) supprimés
- Plus Jakarta Sans conservée sous `--font-teacher` (espace enseignant non redesigné)

## Pas de changement visible

Les tokens `rad-*` ne sont pas encore utilisés dans les vues — aucune régression visuelle attendue. L'impact visuel arrivera dans la PR 2 (subjects/show).

## Test plan

- [ ] `bundle exec rails tailwindcss:build` sans erreur
- [ ] Fonts servies avec status 200 (DevTools Network)
- [ ] Aucune régression visuelle sur écrans enseignant (light + dark)
- [ ] Aucune régression visuelle sur écrans élève (light + dark)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected : URL de PR affichée dans le terminal.

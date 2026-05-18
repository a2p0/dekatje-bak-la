# Notes opérationnelles — B1 Design Tokens 2 Layers

**Branch** : `065-design-tokens-2-layers`
**Date démarrage** : 2026-05-17

## T001 — ImageMagick check ✅

```
$ magick compare --version
Version: ImageMagick 7.1.1-47 Q16-HDRI x86_64 22763 https://imagemagick.org
```

ImageMagick 7.1.1-47 installé sur la machine dev (Fedora). Commande à utiliser pour les diffs : `magick compare -metric AE -fuzz 2% <baseline> <after> /tmp/diff.png`.

## T002 — Baseline screenshots ⏳ EN ATTENTE

Procédure à exécuter **manuellement par l'utilisateur** (login requis avec comptes seed) :

1. Démarrer l'app : `bin/dev` (lance Postgres/Redis via podman compose si pas déjà up, puis Rails server + Tailwind watcher + Sidekiq).
2. Ouvrir Chrome (version stable, viewport **1440×900**, DevTools fermé, mode light forcé via `localStorage.setItem('theme', 'light')` ou simplement ne pas avoir bouton "thème sombre" actif).
3. Capturer les 3 écrans suivants en PNG full-page (DevTools → Cmd+Shift+P → "Capture full size screenshot") :
   - **`login-eleve.png`** : visiter `/{classroom_access_code}` (par défaut seed = `/terminale-sin-2025` ou similaire, vérifier dans `db/seeds/development.rb`). Capturer la page de login élève.
   - **`teacher-classrooms.png`** : se logger comme teacher seed (email/password dans seeds), visiter `/teacher/classrooms`. Capturer.
   - **`student-drawer-tibo.png`** : se logger comme élève seed, visiter une question avec tutorat activé, **ouvrir le drawer Tibo** (clic bouton Tibo), attendre le full render, capturer.
4. Sauvegarder dans `tmp/b1-baseline-screenshots/` à la racine du repo. Le dossier `tmp/` est déjà gitignored (`.gitignore:15` → `/tmp/*`).

**Validation cohérence T017** : utiliser **exactement le même viewport, même browser, mêmes pages** pour les screenshots after-B1.

## T003 — Baseline CSS size ✅

Commande utilisée :
```
$ bin/rails tailwindcss:build
≈ tailwindcss v4.2.1
Done in 140ms

$ wc -c app/assets/builds/tailwind.css
83774 app/assets/builds/tailwind.css

$ gzip -c app/assets/builds/tailwind.css | wc -c
13615
```

**Métriques baseline (avant B1)** :
- CSS brut : **83 774 bytes** (~ 82 KB)
- CSS gzippé : **13 615 bytes** (~ 13.3 KB)

**Seuils SC-007 (après B1)** :
- Brut max : 83 774 × 1.10 = **92 151 bytes** (~ 90 KB) — marge de 8 377 bytes
- Gzippé max : 13 615 × 1.05 = **14 296 bytes** (~ 14 KB) — marge de 681 bytes (très serré côté gzip, ratio compression élevé du CSS Tailwind purgé)

À reporter après T029.

---

## Journal d'exécution

| Date | Task | Status | Note |
|---|---|---|---|
| 2026-05-17 | T001 | ✅ | ImageMagick 7.1.1-47 OK |
| 2026-05-17 | T002 | ✅ | 3 PNG dans tmp/b1-baseline-screenshots/ (login-eleve, teacher-classrooms, student-drawer-tibo) |
| 2026-05-17 | T003 | ✅ | Baseline brute 83 774 b / gzip 13 615 b |

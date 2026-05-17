# Research: B1 Design Tokens 2 Layers — Technical Decisions

**Date**: 2026-05-17
**Spec**: spec.md (065-design-tokens-2-layers)
**Stack vérifiée** : Rails 8.1.3, `tailwindcss-rails`, `propshaft`, Capybara + Selenium, importmap (pas de Vite/webpack). Le fichier `app/assets/tailwind/application.css` utilise déjà la syntaxe Tailwind v4 (`@import "tailwindcss"`, `@theme { … }`, `@custom-variant`).

---

## Q1 — Tailwind v4 : sélecteurs d'attribut et override des tokens `@theme`

**Decision** : OUI, on peut overrider un token `--color-*` défini dans `@theme` depuis un sélecteur extérieur (ex : `[data-audience="teacher"] { --color-accent-primary: … }`) et l'utilitaire généré (`bg-accent-primary`) prendra bien la valeur cascadée. **L'override DOIT se faire à la racine du fichier CSS (hors de `@theme`), pas à l'intérieur du bloc `@theme`.**

**Rationale** :
1. La doc Tailwind v4 (`tailwindcss.com/docs/theme`) impose explicitement que *« Theme variables are required to be defined top-level and not nested under other selectors or media queries »*. Donc on ne peut **pas** écrire `[data-audience="teacher"] { @theme { … } }`.
2. Mais ce que `@theme { --color-x: red; }` produit, c'est l'équivalent de :
   - une déclaration `:root { --color-x: red; }`
   - une famille d'utilitaires (`bg-x`, `text-x`, `border-x`, …) dont la valeur compilée est `color: var(--color-x)` (et non `color: red` en dur).
3. Conséquence directe : toute redéfinition ultérieure de `--color-x` dans un sélecteur plus spécifique (`.dark`, `[data-audience="teacher"]`, `html.dark body[data-audience="teacher"]`, …) est honorée par la cascade CSS standard, et l'utilitaire `bg-x` prend la nouvelle valeur.
4. **Preuve empirique dans le projet** : `app/assets/tailwind/application.css` lignes 53-68 utilise déjà exactement ce pattern pour le dark mode (`--color-rad-bg` défini dans `@theme`, overridé dans `.dark { … }`). Les utilitaires `bg-rad-bg` fonctionnent en clair ET en sombre. Donc le mécanisme est validé en production sur ce repo. On étend simplement le pattern à un second axe (audience).

**Alternatives considered** :
- Définir les tokens scopés dans `@layer base` au lieu de `@theme` : possible, mais on perdrait la génération automatique d'utilitaires (`bg-accent-primary`). Rejeté — la spec FR-004 demande la classe utilitaire.
- Définir un token par audience (`--color-accent-primary-teacher`, `--color-accent-primary-student`) avec switching côté composant : alourdit l'API consommateur et duplique les classes. Rejeté.
- `@theme inline` + `@variant` : non pertinent (variantes générées, pas valeur cascadée).

**Sources** :
- https://tailwindcss.com/docs/theme — § « Theme variables are required to be defined top-level »
- https://tailwindcss.com/docs/functions-and-directives — `@theme` directive
- https://tailwindcss.com/docs/dark-mode — `@custom-variant dark (&:where(.dark, .dark *))` (déjà utilisé ligne 10 du CSS projet)
- Preuve interne : `app/assets/tailwind/application.css` (override `.dark` fonctionnel en prod).

---

## Q2 — Combiner `[data-audience]` sur `<body>` + `.dark` sur `<html>`

**Decision** : utiliser le **combinateur descendant** classique. Quatre sélecteurs (un par combinaison audience × mode) suffisent et restent lisibles :

```css
/* light */
body[data-audience="student"]  { /* tokens student-light */ }
body[data-audience="teacher"]  { /* tokens teacher-light */ }
body[data-audience="public"]   { /* tokens public-light */ }

/* dark — .dark sur <html>, attribut sur <body> descendant immédiat */
html.dark body[data-audience="student"] { /* tokens student-dark */ }
html.dark body[data-audience="teacher"] { /* tokens teacher-dark */ }
html.dark body[data-audience="public"]  { /* tokens public-dark */ }
```

**Rationale** :
1. Compatibilité totale : combinateur descendant et sélecteurs d'attribut sont CSS 2.1, supportés partout (Chrome, Firefox, Safari iOS/macOS, Edge, navigateurs mobiles). 100 % du marché.
2. Lisibilité : un lecteur du fichier voit immédiatement « voici les 6 jeux de tokens, 3 audiences × 2 modes ». Pas de magie.
3. Spécificité contrôlée : `html.dark body[data-audience="x"]` (spécificité 0,2,2) bat `body[data-audience="x"]` (0,1,1), donc le mode dark gagne sans `!important`.
4. Cohérent avec le `@custom-variant dark (&:where(.dark, .dark *))` déjà en place (qui utilise `:where()` pour spécificité 0 sur les utilitaires `dark:*`). Le bloc `.dark` actuel (ligne 54) NE PASSE PAS par `:where()` ; il a donc spécificité normale et est lui-même battu par `html.dark body[…]`. À surveiller : si on garde le bloc legacy `.dark { --color-rad-bg: … }`, ses overrides legacy seront masqués par les nouveaux `html.dark body[data-audience="…"]`. **Conséquence pour le plan** : soit migrer le bloc legacy `.dark` vers `html.dark body[data-audience="public"]` (chemin propre), soit garder le legacy et s'assurer que les valeurs sont identiques (sinon : bug invisible). Recommandation : migrer.

**Alternatives considered** :
- `:has()` (ex : `html:has(body[data-audience="teacher"]) { … }`) : surchargé pour rien, et compatible Safari ≥ 15.4 / Firefox ≥ 121 — large mais inutile ici. Rejeté.
- `@scope { … }` : trop récent (Safari 17.4+, Firefox 128+). Rejeté pour MVP.
- Tout mettre sur `<html>` (audience + dark) : casserait FR-011/FR-012 qui exigent l'attribut sur `<body>`.
- Custom variants Tailwind v4 (`@custom-variant teacher (&:where([data-audience="teacher"], [data-audience="teacher"] *));`) : possible et élégant, mais le besoin B1 est de redéfinir des **valeurs de variables**, pas de générer des utilitaires `teacher:bg-rouge`. Hors scope.

**Sources** :
- MDN — [CSS descendant combinator](https://developer.mozilla.org/en-US/docs/Web/CSS/Descendant_combinator)
- Caniuse — combinateur descendant + sélecteurs d'attribut : 100 % support depuis ~2010.
- Pattern interne déjà utilisé (`app/assets/tailwind/application.css:54`).

---

## Q3 — Outil CLI de diff visuel sur Linux Fedora

**Decision** : **ImageMagick `compare` (paquet `ImageMagick` sur Fedora)** comme outil principal, métrique **AE (Absolute Error count)** avec fuzz tolerance, complété par **`odiff`** (binaire Rust statique, `cargo install odiff-bin` ou release GitHub) si on veut du ΔE perceptuel rigoureux.

Commandes recommandées (à inscrire dans le plan, pas à exécuter ici) :

```bash
# ImageMagick — comptage de pixels différents avec tolérance fuzz 2 %
magick compare -metric AE -fuzz 2% before.png after.png diff.png 2>&1
# sortie : un entier = nombre de pixels altérés
# % altéré = AE / (width × height) × 100
# seuil SC-001 : ≤ 1 %

# odiff — ΔE par pixel + sortie JSON exploitable
odiff before.png after.png diff.png --threshold=0.02 --output-diff-mask
# exit 0 si diff < threshold, 21 sinon, JSON via --reporter json
```

**Rationale** :
1. **ImageMagick** : paquet `ImageMagick` (dnf install ImageMagick) déjà packagé Fedora, zéro dépendance Node/Python, sortie machine-parsable, `-fuzz 2%` absorbe le bruit anti-aliasing acceptable pour SC-001.
2. **Limite ImageMagick** : `-metric AE` compte les pixels « différents » au-delà du fuzz, mais ne calcule pas un ΔE CIEDE2000 par pixel. Pour le critère « ΔE ≤ 2 par pixel », `-fuzz 2%` est une approximation conservative (delta sRGB), pas un ΔE CIE strict. C'est cohérent avec « tolérance industrie standard » de la spec, qui mentionne Percy/BackstopJS — ces outils utilisent eux-mêmes des seuils sRGB approximatifs.
3. **odiff** : binaire Rust, ultra-rapide, calcule un YIQ delta proche de la perception. Plus précis qu'ImageMagick si on veut serrer la vis. Pas dans les repos Fedora standards → soit release GitHub (binaire statique), soit cargo. Marqué « optionnel » dans le plan.
4. Sortie JSON exploitable depuis RSpec (`JSON.parse(`)`) si on veut un spec automatisé. Pour B1, validation manuelle suffit (cf. spec : « validation manuelle par l'utilisateur »).

**Alternatives considered** :
- `pixelmatch` (npm) : impose Node, ajoute une chaîne d'install pour 1 usage. Rejeté.
- `dssim` : excellent (SSIM perceptuel), mais paquet Rust à installer, sortie scalaire SSIM peu intuitive pour le seuil « % de pixels altérés ». Rejeté pour cet usage précis.
- Playwright snapshots : nécessite Playwright (Node + browsers), overkill et duplique Capybara. Rejeté.
- BackstopJS, Percy, Chromatic : hors scope (spec « Out of Scope »).

**Sources** :
- https://imagemagick.org/script/compare.php — métrique AE et fuzz
- https://github.com/dmtrKovalenko/odiff — README et CLI flags
- Fedora package : `dnf provides compare` → `ImageMagick`.

---

## Q4 — Lire une CSS custom property depuis Capybara/Selenium

**Decision** : utiliser `page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--color-accent-primary').trim()")` dans un feature spec RSpec. Comparer la valeur renvoyée (string) au hex attendu, en passant par une normalisation (lowercase, strip).

**Rationale** :
1. `getPropertyValue('--var-name')` renvoie la **string littérale stockée** dans le custom property (ex : `"#127566"` ou `" var(--rad-prim-teal)"`), **PAS la valeur résolue à travers `var()`**. Donc :
   - Si on écrit `--color-accent-primary: #127566`, `getPropertyValue` renvoie `"#127566"`.
   - Si on écrit `--color-accent-primary: var(--rad-prim-teal)`, `getPropertyValue` renvoie `"var(--rad-prim-teal)"` — pas la couleur résolue.
   - **Workaround robuste** : tester sur une propriété CSS *standard* (`color`, `background-color`) appliquée à un élément qui consomme le token. `getComputedStyle(el).color` renvoie alors la valeur **résolue** (`"rgb(18, 117, 102)"`). C'est la méthode canonique.
2. **Implication pour le spec** : la vue fixture (cf. SC-003) doit contenir un élément qui consomme le token, ex :
   ```erb
   <div id="probe-accent" class="bg-accent-primary">test</div>
   ```
   Puis dans le spec : `page.evaluate_script("getComputedStyle(document.getElementById('probe-accent')).backgroundColor")` → renvoie `"rgb(18, 117, 102)"` (teal) sous teacher, `"rgb(212, 69, 46)"` (red) sous student.
3. Selenium supporte `execute_script` (alias Capybara `evaluate_script`) pour primitives JS. Aucun forçage de repaint nécessaire : `getComputedStyle` déclenche un layout sync si nécessaire.
4. Conversion hex ↔ rgb : utiliser un helper dans `spec/support/color_helpers.rb` (`hex_to_rgb("#127566") == "rgb(18, 117, 102)"`).

**Alternatives considered** :
- Lire la propriété custom directement (`getPropertyValue('--…')`) puis recomposer la chaîne de `var()` : trop fragile, casse au moindre changement d'alias chain.
- Capybara `find('#probe').style('background-color')` : renvoie une string, équivalent fonctionnel à la solution retenue. Acceptable comme variante syntaxique.
- Visual regression sur capture du probe : overkill pour 19 tokens.

**Sources** :
- MDN — `Window.getComputedStyle()` (renvoie la valeur résolue pour les propriétés standard, la valeur déclarée pour les custom properties).
- CSSWG — [css-variables-1 §3.2](https://www.w3.org/TR/css-variables-1/) : `getPropertyValue` retourne la « specified value » des custom properties, pas leur résolution.
- Capybara doc — `evaluate_script` retourne JSON-serializable values.

---

## Q5 — Mesurer le poids du CSS compilé Rails + Tailwind v4

**Decision** : pipeline en 3 commandes shell, à intégrer au workflow de PR (avant/après B1) :

```bash
# 1. Compiler le CSS Tailwind en mode build (équivalent prod, minifié)
bin/rails tailwindcss:build
# → écrit le CSS dans app/assets/builds/tailwind.css

# 2. Taille brute (octets)
wc -c < app/assets/builds/tailwind.css

# 3. Taille gzippée (octets, niveau 6 par défaut, équivalent serveur HTTP standard)
gzip -c app/assets/builds/tailwind.css | wc -c
```

Pour reporter dans la PR, format suggéré :

```
| Mesure         | Avant B1 | Après B1 | Δ      | Seuil   | Verdict |
|----------------|----------|----------|--------|---------|---------|
| Brut (octets)  | XXX kB   | YYY kB   | +ZZ %  | ≤ +10 % |   OK    |
| Gzip (octets)  | XXX kB   | YYY kB   | +ZZ %  | ≤ +5 %  |   OK    |
```

**Rationale** :
1. **Chemin du CSS compilé** : `tailwindcss-rails` (gem présente dans `Gemfile`) génère par convention `app/assets/builds/tailwind.css` (consommé ensuite par Propshaft). Vérifié indirectement : `Gemfile` ligne 6-7 (`propshaft` + `tailwindcss-rails`), pas de Vite. Le chemin est fixé par la rake task `tailwindcss:build` héritée du gem.
2. **gzip standalone** : `gzip -c | wc -c` donne une mesure stable et reproductible. Niveau 6 par défaut = ce que servent la majorité des serveurs HTTP (nginx default level 1-6, Cloudflare 6). Acceptable approximation du poids réseau réel.
3. **brotli optionnel** : `brotli -c -q 11 app/assets/builds/tailwind.css | wc -c`. À ajouter si l'infra Coolify/Thruster sert en brotli (Thruster gem présente — supporte brotli côté Puma). Recommandation : reporter les deux si brotli est disponible, sinon gzip suffit pour SC-007.
4. **Mode prod-like** : `tailwindcss:build` produit un CSS minifié par défaut en v4. Pas besoin de `RAILS_ENV=production`. Si l'on veut être strict : `RAILS_ENV=production bin/rails assets:precompile` (mais c'est plus lent et passe par Propshaft = chemin différent).

**Alternatives considered** :
- Mesurer le bundle Propshaft post-`assets:precompile` (`public/assets/tailwind-*.css`) : plus représentatif de la réalité serveur, mais inclut un digest filename qui change à chaque build, et le pipeline est plus lent. Pour SC-007 (delta avant/après), `app/assets/builds/tailwind.css` suffit.
- Mesurer via `du -b` : équivalent à `wc -c`. Préférence `wc -c` pour lisibilité.
- Brotli en niveau 4 (default nginx) au lieu de 11 (max) : 11 est l'usage canonique pour mesurer la limite théorique. À documenter dans la PR.

**Sources** :
- `tailwindcss-rails` gem README — rake task `tailwindcss:build` et chemin de sortie.
- Tailwind v4 doc — build minifié par défaut en CLI.
- man gzip / man brotli.

---

## Synthèse pour le plan

Contraintes techniques à inscrire dans `plan.md` → Technical Context :

1. **Tokens scope** : couche primitives (`--rad-prim-*`) et sémantiques (`--color-*`) toutes deux déclarées dans `@theme { … }` au top-level du fichier `application.css`. **Aucune** primitive sémantique scopée dans `@theme`. Les overrides par audience et par mode se font dans des blocs CSS séparés, en utilisant la cascade.
2. **Pattern de scoping retenu** : `body[data-audience="<x>"]` pour le light, `html.dark body[data-audience="<x>"]` pour le dark. Six blocs au total (3 audiences × 2 modes). Le bloc legacy `.dark { … }` actuel est **à migrer** vers `html.dark body[data-audience="public"]` pour éviter conflit de spécificité.
3. **Bridge rétrocompatible** : les 12 tokens `--color-rad-*` actuels deviennent soit des alias vers les primitives (ex : `--color-rad-red: var(--rad-prim-balisier-red);`), soit conservés tels quels et référencés depuis les sémantiques. Choix à trancher dans le plan, mais l'option « tous les `--color-rad-*` → primitives » est plus propre.
4. **Layout `application.html.erb`** : doit recevoir `data-audience="public"` (FR-013) avec un mapping CSS identique au rendu actuel (mêmes valeurs que `--color-rad-*` aujourd'hui).
5. **Tests** :
   - FR-014/FR-015 : un spec qui charge `app/assets/builds/tailwind.css` (après `tailwindcss:build`) et vérifie la présence des chaînes (`--color-surface`, `--color-accent-primary`, `--color-on-surface`, `--color-rule`). Pas besoin de Capybara.
   - SC-003 : un feature spec Capybara/Selenium qui visite `/teacher/design-system/preview` (sous auth teacher) avec un probe `<div id="probe-accent" class="bg-accent-primary">`, fait `evaluate_script("getComputedStyle(document.getElementById('probe-accent')).backgroundColor")` et compare à `rgb(18, 117, 102)`. Helper `hex_to_rgb` dans `spec/support/`.
6. **Validation visuelle SC-001** : `magick compare -metric AE -fuzz 2%` sur 3 captures avant/après (login élève, classroom teacher index, drawer Tibo). Mesure manuelle, reportée dans la PR. Outil `ImageMagick` (paquet Fedora standard, à confirmer présent sur la machine dev de l'utilisateur — si absent : `sudo dnf install ImageMagick`).
7. **Mesure SC-007** : `bin/rails tailwindcss:build` puis `wc -c` + `gzip -c | wc -c` sur `app/assets/builds/tailwind.css`, avant et après B1, reportés dans la PR. Brotli optionnel.
8. **Page démo** : `/teacher/design-system/preview` ajoutée dans `config/routes.rb` sous le namespace `teacher`, contrôleur `Teacher::DesignSystemController#preview`, vue ERB listant les 19 tokens × 4 combinaisons (student/teacher × light/dark). Sert à la fois de docs vivante et de fixture pour le spec SC-003.
9. **Aucun changement** sur le mécanisme dark mode existant (`@custom-variant dark`, script JS dans `<head>`, classe `.dark` sur `<html>`). Tests existants doivent passer sans modification (SC-004).

**Risques résiduels identifiés** :
- Compatibilité sémantique → primitive du bloc legacy `.dark { … }` : il faut s'assurer que les **valeurs hex** dans le nouveau mapping `html.dark body[data-audience="public"]` sont **strictement identiques** à celles actuellement dans `.dark { … }` (lignes 54-68 de l'application.css), sinon la page publique change visuellement (régression SC-001).
- ImageMagick `-fuzz 2%` ≠ ΔE 2 strict CIEDE2000 : approximation acceptable pour le standard industrie cité dans la spec, mais à documenter dans la PR.
- `evaluate_script` en Selenium : la machine dev étant lente pour Selenium (cf. spec « validation manuelle »), le spec SC-003 peut être marqué `:slow` ou tourner uniquement en CI.

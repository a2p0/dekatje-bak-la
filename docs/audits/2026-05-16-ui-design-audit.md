# UI Design Audit — DekatjeBakLa
Date : 2026-05-16
Périmètre : layouts, pages élève, pages enseignant, composants ViewComponent, pages publiques, cohérence transverse.
Méthodologie : lecture statique des fichiers (ERB, RB des composants, CSS Tailwind 4 `@theme`, JS Stimulus liés à l'UI). Pas de mesure runtime (perf, paint, FOUT).

---

## Résumé exécutif

### Scores par dimension (1 = critique, 5 = excellent)

| # | Dimension | Élève | Teacher | Public | Commentaire |
|---|---|---|---|---|---|
| 1 | Design Token Consistency | **3** | **2** | **2** | Élève très bien sur tokens `rad-*`, mais **133+ valeurs en pixels arbitraires** (`text-[10.5px]`, `rounded-[14px]`, `px-[18px]`) qui bypassent les tokens. Teacher n'utilise PAS les tokens (slate/indigo en dur). |
| 2 | Visual Hierarchy | **4** | **3** | **4** | Élève : hiérarchie claire (font-serif italic + scales typo cohérentes). Teacher : hiérarchie correcte mais plate (un seul `font-sans`). |
| 3 | Color System | **3** | **3** | **3** | Palette `rad-*` sémantiquement riche. **Contraste rad-muted (#6b665a) sur rad-warm (#e8e0cc) ~3.9:1 — sous WCAG AA pour texte normal** (header drawer Tibo, banner Tibo). Dark mode élève sans `dark:` (token override only) = élégant. Teacher : duplicata `dark:` partout, plus verbeux. |
| 4 | Component Completeness | **3** | **3** | — | États `:loading`, `:error`, `:empty` quasi-absents des composants. `BadgeComponent` mélange 6 couleurs « tailwind » et 4 « rad » → API hybride. `CardComponent` a 3 variantes mais le footer applique TOUJOURS `border-rad-rule` (bug visuel sur teacher). |
| 5 | Accessibility (WCAG AA) | **3** | **3** | **3** | Boutons de navigation header élève (← et ≡) en `text-2xl` sans wrapping ⇒ cibles tactiles **<24×24px** sur mobile. Avatar Tibo `w-7 h-7` (28px) sous le seuil AAA 44px (AA min reste 24px). Pas de `focus-visible` explicite sur la majorité des liens et chips élève. Compensé par : skip-link, focus-trap controllers, aria-live regions. |
| 6 | Responsive Behavior | **4** | **3** | **4** | Feature 064 desktop bien intégrée (sidebar/drawer popover, viewer DT 1/2, drawer Tibo 60/40). Iframe PDF teacher en hauteur fixe `height="700"` non-responsive. Pas de stratégie zoom 200%. |
| 7 | Spacing & Layout System | **2** | **4** | **4** | Élève : explosion de paddings ad-hoc (`px-[18px] py-[14px]`, `pl-2 pr-4`, `py-3.5`) sans grille 4/8px stricte. Teacher cohérent (px-4 py-3, etc.). |
| 8 | Brand & Visual Consistency | **3** | **2** | **3** | Identité « Radical » (stripes martiniquaises 4 couleurs + font-serif Fraunces italic + rad-red CTA) très forte côté élève. Teacher : look Tailwind générique indigo, **aucune trace de l'identité Radical**, **font-teacher (Plus Jakarta Sans) défini mais jamais utilisé**. |
| 9 | Performance-Conscious Design | **4** | **4** | **4** | Fonts self-hosted avec `font-display: swap` (constitution V), `loading="lazy"` sur iframe DT, transitions GPU-friendly (transform/opacity). Mais `application.css` est vide (manifest sans contenu) ⇒ on charge `:app` pour rien. |
| 10 | Design-to-Code Fidelity | **3** | **2** | **3** | Élève : très fidèle à l'identité Radical, mais déviations CSS arbitraires nombreuses. Teacher : aucun token `rad-*` ni `font-teacher` consommé, le système 025 décrit dans CLAUDE.md n'est PAS appliqué côté prof. |

### Findings critiques (bloquants utilisateur)

1. **Contraste WCAG AA insuffisant** sur le drawer Tibo et le tutor banner. `rad-muted` (#6b665a) sur `rad-warm` (#e8e0cc) ≈ **4.1:1** (calcul approximatif, à valider avec un outil dédié type WebAIM contrast checker), sous le seuil 4.5:1 requis pour du texte ≤24px. Concerne le sous-titre « Sur la Q1.2 · ne donne pas la réponse » (`app/views/student/conversations/_drawer.html.erb:61`), le placeholder de l'input (`:118`), et tous les sous-titres `text-rad-muted` du `_tutor_banner.html.erb`.
2. **Cibles tactiles trop petites** sur les headers mobiles élève. Les chevrons « ‹ » et « ≡ » sont rendus comme `<a class="text-2xl leading-none">` sans `min-w/h-11`, donnant une zone cliquable ~16-18px. Touche tous les écrans : `student/subjects/index.html.erb:12,16`, `student/settings/show.html.erb:12`, `student/subjects/_subject_header.html.erb:2,9`. WCAG SC 2.5.5 exige 24×24px (AA) ou 44×44px (AAA).
3. **Pages légales avec placeholders** non remplis en production. `app/views/pages/legal.html.erb:11-16` contient `[NOM_PRENOM]`, `[ADRESSE]`, `[EMAIL_CONTACT]`. Risque légal (mentions obligatoires RGPD/LCEN) et image utilisateur dégradée.
4. **Page d'activation tuteur incohérente** : `app/views/student/tutor/_tutor_activated.html.erb` utilise `bg-emerald-50 dark:bg-emerald-900/20` (palette teacher) alors qu'on est en contexte élève. Doit être rad-green ou rad-teal. Effet : flash visuel hors-marque sur un moment-clé du parcours.

### Findings importants (qualité / cohérence)

5. **Univers visuel Teacher fracturé du reste de l'app**. Le système Radical (tokens `rad-*`, font Fraunces, stripes martiniquaises, pattern madras) est totalement absent de `app/views/layouts/teacher.html.erb` et des 1100+ lignes de vues teacher. Un enseignant qui montre la plateforme à un élève voit deux applications visuellement déconnectées. **Note** : cette séparation peut être délibérée (deux publics, deux univers) — à valider avec l'auteur. Si non délibérée, à promouvoir P1 dans le backlog.
6. **`BadgeComponent` à double API** (`app/components/badge_component.rb:3-12`). 6 couleurs Tailwind (`:indigo, :emerald, …`) coexistent avec 4 couleurs rad (`:rad_teal, :rad_red, …`). C'est un piège : un dev qui utilise `:emerald` pense être dans le système et obtient du vert Tailwind, pas du `rad-green`. Ne propage pas la cohérence Radical aux nouvelles features. Recommandation : déprécier les variantes Tailwind ou les renommer `:legacy_*`.
7. **`CardComponent` footer bug** : `app/components/card_component.html.erb:15` applique `border-rad-rule` sur le footer quelle que soit la variante. En mode `:default` (teacher), le bord du footer n'utilise plus `border-slate-*` ⇒ incohérence visuelle subtile sur toutes les cards teacher avec footer (ex. `teacher/classrooms/index.html.erb:30-33`).
8. **`ButtonComponent` ne connaît pas le système Radical** (`app/components/button_component.rb:7`). Le `primary` est un gradient indigo→violet. Côté élève, **aucun bouton primaire ne traverse ce composant** — les CTA élève sont réécrits en ad-hoc (`bg-rad-red text-rad-cream font-bold rounded-[14px]` répété ~20 fois dans student/). Manque les variantes `:rad_primary`, `:rad_ghost`, `:rad_ink`. Le composant ne sert que côté teacher.
9. **Magic numbers omniprésents côté élève**. 44 `rounded-[XXpx]`, 114 `text-[XXpx]`, 123 `[XXpx]` arbitraires dans les vues. Exemples : `rounded-[14px]` (rappel : token `--radius-button: 0.75rem` = 12px existe), `text-[10.5px]`, `text-[18px]`, `px-[18px] py-[14px]`. Tendance : design issu de Figma collé en CSS sans normalisation. Crée un design system implicite parallèle à `@theme`.
10. **`progress_bar_component` semi-cohérent** (`app/components/progress_bar_component.rb`) : la barre vide est codée `bg-rad-rule` (token rad) mais les couleurs de remplissage proposent indigo/emerald/gradient + 1 seul rad (`rad_teal`). Manque `rad_red`, `rad_yellow`. Côté teacher, on utilise `color: :emerald` ⇒ vert non-tokenisé.
11. **`BottomBarComponent` non utilisé sur la page question** : `app/views/student/questions/show.html.erb:213-261` réécrit une bottom-bar mobile en ad-hoc. Le composant `BottomBarComponent` (`app/components/bottom_bar_component.rb`) existe mais aucune vue ne l'utilise. Soit déprécier le composant, soit le re-câbler.
12. **`NavBarComponent` figé sur l'identité teacher** : `app/components/nav_bar_component.html.erb:6` applique `bg-gradient-to-br from-indigo-500 to-violet-500` au brand. Inutilisable côté élève. Le `student/shared/_desktop_nav.html.erb` réécrit tout from scratch.
13. **`ModalComponent` non-élève** (`app/components/modal_component.html.erb:9`) : `bg-white dark:bg-slate-800/95 border border-slate-200 dark:border-indigo-500/15`. Ne traversera pas le visuel rad. Si on devait afficher une modale dans le parcours élève, rupture immédiate.
14. **`FlashComponent` Tailwind-only** (`app/components/flash_component.rb:3-4`) : emerald + rose, pas de variante rad. Rendu dans `layouts/student.html.erb:40,45` ⇒ chaque notice/alert élève rompt le visuel rad.
15. **Layout application + student dupliqués** : `layouts/application.html.erb` et `layouts/student.html.erb` partagent 70% de code (head, fonts, theme init script, flash) avec deux versions du body. Refactor recommandé via `_head.html.erb` partagé.
16. **Iframe PDF hauteur fixe non-responsive** (`app/views/teacher/parts/show.html.erb:95,99,135,143,149`) : `height="700"` en attribut HTML. Sur écran 13", le PDF est coupé ou la page scrolle deux fois. Préférer `aspect-ratio` ou `min-h-[700px] h-[calc(100vh-200px)]`.
17. **Accessibilité du toggle « Mode par défaut »** (`app/views/student/settings/show.html.erb:42-56`) : pattern Tailwind `peer` avec `<input class="sr-only">` ; pas de `role="radiogroup"`, pas d'`aria-label` sur le fieldset, pas de focus visible sur le label sélectionné. Un utilisateur clavier ne voit pas son choix.
18. **`ThemeToggleComponent` deux soleils/lunes côte-à-côte** sans `aria-pressed` ni `aria-checked`. Le bouton dit juste « Changer de thème » → l'utilisateur de lecteur d'écran ne sait pas l'état courant.
19. **`pattern-madras-diagonal` overlay sur la zone messages du tuteur** (`student/conversations/_drawer.html.erb:74`) : décoratif joli mais réduit le contraste des bulles `rad-paper` sur fond strié. Vérifier avec utilisateurs malvoyants ou ajouter `@media (prefers-contrast: more)` qui désactive le pattern.
20. **Confetti sans label / cleanup** (`app/components/confetti_component.rb`) : `sr-only` mais déclenche une animation visuelle. OK pour `prefers-reduced-motion` (commenté), mais à vérifier dans le controller JS — non audité ici.

### Findings mineurs (cosmétique / dette)

21. `app/assets/stylesheets/application.css` est un manifest **vide** (commentaire uniquement). Le `stylesheet_link_tag :app` dans tous les layouts charge un fichier sans contenu. Supprimer ou consolider.
22. La sélection en double `class="dark"` sur `<html>` dans les layouts (`application.html.erb:2`, `student.html.erb:2`, `teacher.html.erb:2`) est suivie d'un script qui peut la retirer. Risque de FOUC très bref si le script est lent. Préférer `class=""` puis l'init dans le script (déjà presque fait).
23. `app/views/student/conversations/_message.html.erb:14` — avatar Tibo `w-7 h-7` (28px). Cohérence à vérifier avec les autres avatars Tibo : 6 tailles différentes recensées (w-5, w-6, w-7, w-8, w-9, w-10, w-11) dans student/.
24. `app/views/teacher/subjects/show.html.erb:144,175` — `text-red-500` / `text-red-600` au lieu de `:rose` (sémantique destructive) → mélange `red` et `rose` dans le même fichier.
25. `app/components/badge_component.rb:11` — `bg-rad-yellow/15` (15% alpha) sur `text-rad-ink` ⇒ contraste sur fond clair OK, mais sur dark le `text-rad-ink` devient `text-rad-cream` ? Non, `rad-ink` est défini séparément. Vérifier visuellement.
26. `app/views/student/sessions/new.html.erb:57` — bouton login `rounded-[14px]` au lieu de `rounded-button` (token = 12px). Choix esthétique conscient ou oubli ?
27. Pas de favicon SVG dark mode (`<link rel="icon" href="/icon.svg" type="image/svg+xml">`) — un seul SVG pour les deux thèmes.

---

## Audit détaillé par dimension

### 1. Design Token Consistency

**État** : tokens définis proprement dans `app/assets/tailwind/application.css:13-51` :
- 4 familles de polices (`--font-sans/serif/mono/teacher`)
- 11 couleurs `--color-rad-*` (light) + override dark mode (`:54-68`)
- 4 radius (`--radius-card/button/input/pill`)
- 5 z-index (`--z-bottom-bar/backdrop/sidebar/chat-drawer/modal`)
- 2 transitions (`--transition-fast/normal`)

**Écarts** :
- Token `--font-teacher` (Plus Jakarta Sans) défini, **jamais utilisé** (`grep -rn "font-teacher" app/views/ = 0`). Le redesign 025 mentionné dans CLAUDE.md prévoyait son adoption côté teacher.
- 123 valeurs en pixels arbitraires dans les vues vs un système tokenisé. Exemples qui devraient migrer :
  - `rounded-[14px]` → `rounded-button` (12px) ou créer `--radius-card-sm` (14px) si délibéré.
  - `text-[10.5px]` (uppercase eyebrow), répété ~15 fois → créer une classe utilitaire ou un token typo.
  - `px-[18px] py-[14px]` (header card correction) → `px-5 py-3.5` (équivalents `1.125rem × 0.875rem`).
- Pas de token de typographie sémantique (h1/h2/body/caption). Toute la hiérarchie est jouée en classes Tailwind ad-hoc.

**Reco** : ajouter une section `@layer components` avec quelques classes sémantiques (`.text-eyebrow`, `.text-heading-md`, `.text-balance-q`) pour absorber les répétitions de magic numbers. Documenter dans CLAUDE.md la règle « pas de `[XXpx]` sans token correspondant ».

### 2. Visual Hierarchy

**État élève** : très bonne. Trois axes d'emphase utilisés :
- Famille typo : `font-serif italic` (Fraunces) pour les titres et identité (`Salut <span class="text-rad-red">Prénom</span>`).
- Échelle : `text-2xl`, `text-[19px]` (questions), `text-[15-17px]` (corps), `text-[13px]` (meta), `text-[10.5px]` (eyebrow uppercase).
- Couleur : `rad-text` (foncé) pour titres, `rad-muted` pour secondaire, `rad-red` pour CTA et accents.

**État teacher** : hiérarchie correcte mais plate : `text-2xl font-bold` (h1), `text-lg font-semibold` (h2), `text-sm` (body). Pas de variation typographique (aucune `font-serif`), pas d'« eyebrow » uppercase. L'UX devient utilitaire.

**Reco** : utiliser `--font-teacher` (Plus Jakarta Sans) sur `body.teacher` ou via `layouts/teacher.html.erb`. Donner aux titres teacher une identité (peut-être plus sobre, mais reconnaissable).

### 3. Color System

**Palette rad analyse contraste (sur fond paper #ffffff)** :
| Token | Hex | Ratio sur paper | Verdict |
|---|---|---|---|
| rad-text #0e1b1f | très foncé | ~17:1 | AAA |
| rad-muted #6b665a | moyen | ~5.0:1 | AA OK |
| rad-teal #127566 | vert | ~6.0:1 | AA OK |
| rad-red #d4452e | rouge | ~3.7:1 | **fail texte normal**, OK large/icone |

**Sur fond `rad-warm` #e8e0cc (drawer Tibo, banner)** :
| Token | Ratio approx. | Verdict |
|---|---|---|
| rad-text #0e1b1f | ~14:1 | AAA |
| rad-muted #6b665a | **~4.1:1** | **FAIL AA pour texte ≤24px** |
| rad-teal #127566 | ~4.7:1 | AA OK |

Note : ratios calculés à partir des hex (formule WCAG relative luminance), à valider avec un outil dédié type WebAIM contrast checker.

⇒ Critique. Plusieurs lignes UX du tuteur sont en `text-rad-muted` sur `bg-rad-warm` (cf. finding #1).

**Dark mode** : architecturalement élégant côté élève (override des CSS vars rad), MAIS jamais audité visuellement dans cet audit. Recommandation : refaire l'analyse contraste avec les valeurs dark (rad-muted #a8c2c5 sur rad-bg #0f2f33 ≈ 6.8:1 OK).

**Reco** :
- Soit assombrir `rad-muted` à ~#5a5546 (gagne ≥4.5:1 sur warm) ; soit forcer `text-rad-text` sur les zones warm.
- Pour les CTA `rad-red` avec texte `rad-cream`, vérifier ratio : #d4452e/#fbf7ee ≈ 3.9:1 (OK pour boutons gras ≥18px, à la limite pour du texte courant).

### 4. Component Completeness

**Couverture states actuels** :

| Component | hover | focus-visible | active | disabled | loading | error | empty |
|---|---|---|---|---|---|---|---|
| Button | ✓ | ✓ | – | ✓ | – | – | – |
| Card | ✓ (glow) | – | – | – | – | – | – |
| Badge | – | – | – | – | – | – | – |
| Modal | – | ✓ (focus-trap controller) | – | – | – | – | – |
| Flash | ✓ | – | – | – | – | – | – |
| ProgressBar | – | – | – | – | – | – | (renders 0%) |
| NavBar | ✓ | – | – | – | – | – | – |
| BottomBar | ✓ | – | – | – | – | – | – |

Manque transverse : aucune skeleton loader, aucun empty state composant, aucun error state composable. Les vues s'en sortent par des `<p class="text-rad-muted">Aucun ...</p>` répétés ⇒ pas de personnalité, pas d'illustration.

**API hybride BadgeComponent** : voir finding #6.

**Reco** : extraire `EmptyStateComponent`, `SkeletonComponent`, et auditer les `:focus-visible` manquants (cf. dim 5).

### 5. Accessibility (WCAG AA)

**Forces** :
- Skip-link présent (`layouts/student.html.erb:35`, `application.html.erb:36`).
- `aria-live="polite" role="status"` sur les flash regions.
- `aria-modal` + `aria-labelledby` sur ModalComponent et drawer tuteur.
- `data-controller="focus-trap"` sur modale et sidebar (à vérifier que le controller fait son travail).
- `aria-expanded` géré dynamiquement par `sidebar_controller.js:53-55`.
- Champ chat input avec `<label for class="sr-only">`.
- `prefers-reduced-motion` géré globalement (`application.css:101-107`).

**Manques** :
- **Touch targets < 24×24px** : voir finding #2.
- **Focus visible** : seulement 5 occurrences de `focus-visible:` dans tout `app/views/`. La majorité des liens élève (`<a>` rad) n'ont aucun style de focus ⇒ navigation clavier invisible. Idem pour les chips contextuels tuteur (`app/views/student/conversations/_chips.html.erb:13-14`) qui n'ont ni `focus-visible:` ni `focus:ring-*` — un élève qui pilote au clavier ne sait pas quel chip est focalisé.
- **Buttons icon-only sans aria-label** : `app/views/student/subjects/index.html.erb:12,16` (chevron et menu) — `link_to` avec juste un caractère unicode, sans `aria-label`. Lecteur d'écran lit littéralement `‹`.
- **Avatar Tibo** : décoratif mais `<div>` sans `aria-hidden`. `_message.html.erb:14` ne marque pas l'avatar comme décoratif ⇒ NVDA lit « T ».
- **Tableaux teacher** : pas de `<caption>`, pas de `scope="col"` sur les `<th>` (`classrooms/show.html.erb:118-145`, `subjects/index.html.erb:60-104`). Important pour les exports PDF générés à partir des mêmes vues.
- **Toggle radio mode** (settings) : pas de `role="radiogroup"`, pas d'`aria-checked` visible sur le label. Cf. finding #17.
- **Zoom 200%** : layouts en `max-w-*` + iframes en `height="700"` non testés à 200% — risque de débordement horizontal sur la sidebar mobile (`w-[260px]` fixe). À tester manuellement.
- **alt text** : aucune image décorative critique trouvée (icônes en `<svg>` inline) mais l'iframe PDF n'a qu'un `title=""` — c'est OK pour AA mais le contenu de la PDF est inaccessible aux lecteurs d'écran (limitation inhérente aux scans).

**Reco prioritaires** :
1. Ajouter `min-w-[44px] min-h-[44px] flex items-center justify-center` aux boutons header mobile élève.
2. Ajouter `focus-visible:outline focus-visible:outline-2 focus-visible:outline-rad-teal focus-visible:outline-offset-2` en classe globale ou via `@layer base a:focus-visible`.
3. Ajouter `aria-label` aux liens icon-only et `aria-hidden="true"` aux SVG décoratifs / avatar T.

### 6. Responsive Behavior

**Stratégies bien faites** :
- Mobile-first : la plupart des vues élève partent du mobile, désactivent (`lg:hidden`) ou ajoutent (`hidden lg:flex`) sur desktop.
- Sidebar/drawer popover unifié mobile+desktop (Feature 064) — pattern moderne et économe.
- Grille subjects index responsive (`grid-cols-1 md:grid-cols-2`).
- Drawer Tibo split 60/40 sur desktop (`lg:basis-3/5` / `lg:basis-2/5`).
- DT viewer split 1/2 desktop (`lg:w-1/2` + `lg:w-1/2` iframe).

**Faiblesses** :
- Iframe teacher hauteur fixe `height="700"` (attribut HTML, aucune classe Tailwind `h-*` ne le surcharge — vérifié). Cf. finding #16.
- `w-[260px]` sidebar drawer en dur (`student/questions/show.html.erb:47`) — peut déborder à zoom 200% (520px = > viewport mobile).
- Bottom-bar en `lg:hidden` est OK mais l'écart visuel entre mobile et desktop est fort : aucun pattern partagé entre la bottom-bar mobile (`student/questions/show.html.erb:213-261`) et la nav desktop (`_desktop_nav.html.erb`). Maintenance × 2.
- Pas de breakpoint XL / 2XL utilisé ⇒ sur écran 1920px+, le contenu reste centré à ~1024px, l'espace est gaspillé (pourrait offrir un 3e panneau historique conversation par ex.).

### 7. Spacing & Layout System

**Tokens Tailwind** : par défaut 4px base (sm=8, md=16, etc.). OK.

**Application réelle élève** : explosion de paddings/margins ad-hoc :
- `px-[18px] py-[14px]` (correction cards) ≠ `p-4` (16px) ≠ `p-5` (20px) ≠ standard.
- `pl-2 pr-4 py-1.5` (bouton Tibo) — padding asymétrique justifié par l'avatar interne, mais code dupliqué 4× dans le fichier.
- `mb-3`, `mb-4`, `mb-6` mélangés sans règle claire (entre 12, 16, 24).

**Teacher** : assez cohérent (`p-5`, `p-6`, `gap-4`, `mb-6`) — par défaut Tailwind.

**Reco** : adopter une grille spaces stricte (4/8/12/16/24/32/48/64 = scales Tailwind 1/2/3/4/6/8/12/16). Bannir les `[18px]` ; soit `p-4` (16) soit `p-5` (20). Audit utile : `grep -c "p-\[" student/`.

### 8. Brand & Visual Consistency

**Identité Radical (élève)** très réussie :
- Stripes martiniquaises 4 couleurs (red / yellow / teal / ink) — répétées sur 6+ écrans (login, subjects index, settings, drawer Tibo, …) ⇒ ancre mémorielle forte.
- Logo « point-point-point + DekatjeBakLa italic » (sessions/new.html.erb:14-22) — distinctif.
- Avatar Tibo (cercle rouge + T blanc italique) — récurrent, signature visuelle.
- Pattern madras (`.pattern-madras-diagonal`) dans la zone messages tuteur — culturellement ancré (créole martiniquais).
- Border-radius typique (12-20px) plus généreux que Tailwind default (8px).

**Identité Teacher** : visuellement générique « SaaS indigo » ⇒ ne reflète aucunement le projet DekatjeBakLa. Un enseignant n'a aucune sensation d'utiliser le « même produit » que ses élèves. C'est le déficit le plus important à corriger pour la cohérence de marque.

**Iconographie** : mix de glyphs Unicode (`‹ › ≡ ↑ ↗ ✓ ◉ ○ ↓ ↑`) et SVG inline (loading spinner, chevrons, soleil/lune). Pas de set unique. Risque : pas d'alignement vertical, pas de poids cohérent. Migration vers `heroicons` ou équivalent serait souhaitable.

**Reco brand** :
1. Migrer `layouts/teacher.html.erb` vers `font-teacher` (Plus Jakarta Sans) sur le body.
2. Ajouter une bande de stripes martiniquaises en top du layout teacher.
3. Adopter au moins les tokens `rad-rule`, `rad-paper`, `rad-text` côté teacher pour rapprocher visuellement.

### 9. Performance-Conscious Design

**Bonnes pratiques** :
- 4 polices self-hosted avec subsets latin / latin-ext (`app/assets/fonts/*.css`) + `font-display: swap` — constitution V respectée.
- `loading="lazy"` sur iframe DT (`student/questions/_dt_viewer.html.erb:31`).
- Transitions GPU-friendly : `translate-x-full` / `opacity` partout pour drawer/sidebar (pas de `left:`).
- `backdrop-blur-sm` localisé (pas global).
- Theme init en script inline pré-stylesheet ⇒ pas de FOUC.

**À vérifier** :
- Tailwind 4 fait du JIT — taille du `tailwind.css` à mesurer en prod. Le `app/assets/builds/tailwind.css` existe.
- Iframe PDF non-paginée chargée à l'ouverture de la page question → l'iframe se charge en `lazy`, OK, mais si l'utilisateur scrolle vite, tout reste dans le DOM ⇒ ok aussi pour cette UX.
- 4 fichiers WOFF2 chargés à chaque page ⇒ ~150-200kB. Acceptable mais on pourrait `preload` la principale (Inter).

**Reco** :
- Supprimer `app/assets/stylesheets/application.css` vide ou y consolider quelque chose, retirer le `stylesheet_link_tag :app` des layouts (finding #21).
- `<link rel="preload" as="font" href="/.../inter-variable-latin.woff2" crossorigin>` dans le `<head>` si pas déjà le cas.

### 10. Design-to-Code Fidelity

**Élève** : très fidèle au design Radical voulu (PRs 054-057), mais la fidélité est obtenue par CSS arbitraire (px en dur, paddings ad-hoc) plutôt que par tokens. Risque maintenance : un futur restyle global ne pourra pas se faire en touchant juste `@theme`.

**Teacher** : le design system 025 (Plus Jakarta Sans + tokens Tailwind) annoncé dans CLAUDE.md n'a PAS été appliqué aux vues teacher. Le décalage entre la doc et l'implémentation crée une dette cognitive.

**Composants ViewComponent** : pensés pour le teacher (slate/indigo), pas pour l'élève. Résultat : les vues élève ne consomment quasi pas les composants partagés (sauf Badge, Card variant `:rad`, ProgressBar). Le « design system » est en réalité **deux systèmes parallèles** non documentés.

---

## Audit par périmètre

### Pages élève
Voir dimensions 1, 2, 5, 7. Globalement, identité forte, ergonomie soignée, mais magic numbers et a11y à durcir. La page `student/questions/show.html.erb` est très dense (268 lignes) et duplique la logique navigation mobile/desktop ⇒ candidate à refactor en partials. La page `student/sessions/new.html.erb` est exemplaire d'identité Radical.

### Pages enseignant
Pile Tailwind générique. Pas de personnalité. Couvre les besoins workflow (cartes, tables, badges, formulaires centralisés via `_field.html.erb`), mais sans investissement visuel. Recommandation : ne pas tout refaire, mais ajouter (a) `font-teacher` sur `<body>`, (b) stripes martiniquaises 1.5px en top, (c) accent color `rad-teal` au lieu de `indigo` sur les liens, pour rapprocher progressivement.

### Composants ViewComponent
Inventaire :
- 12 composants présents
- 3 utilisés à la fois côté élève et teacher : `Badge`, `Card`, `ProgressBar`
- 1 utilisé seulement côté teacher : `Button`, `NavBar`, `Breadcrumb`, `Modal`, `Flash` (rendu côté élève mais visuellement out-of-brand)
- 1 utilisé seulement côté élève : `DataHints` (mais en pratique l'ERB ne l'utilise pas — il y a un `data_hint_banner` partial concurrent)
- 2 quasi-orphelins : `BottomBarComponent` (non utilisé : la bottom-bar question est ad-hoc), `ConfettiComponent` (1 ligne, peu visible)
- 1 fonctionnel mais peut mieux faire : `ThemeToggleComponent`

Recommandation : faire un sprint « cohérence composants » : ajouter variantes rad systématiquement, déprécier les ad-hoc dans les vues élève.

### Layouts
- `application.html.erb` : layout public (slate). Charge `tailwind` + `app` (vide).
- `student.html.erb` : layout élève (rad). Quasi-clone de application + desktop nav + sidebar/chat-drawer controllers.
- `teacher.html.erb` : layout teacher (slate). NavBarComponent + max-w-6xl mx-auto.
- Mailer : non audité (texte).

Duplication ~70% entre application.html.erb et student.html.erb. Recommandation : extraire `_head.html.erb` partagé.

### Cohérence transverse
**Forces** :
- Tokens CSS centralisés.
- Dark mode unifié via override CSS vars (élégant côté élève).
- Skip-link, flash region, theme toggle présents dans tous les layouts.

**Faiblesses majeures** :
- Bifurcation totale teacher (Tailwind générique) vs élève (Radical) — sans pont visuel.
- Composants ViewComponent calibrés sur le système teacher legacy ⇒ peu réutilisables côté élève.
- 2 styles différents pour les CTA primaires : `ButtonComponent variant: :primary` (gradient indigo) vs `bg-rad-red text-rad-cream font-bold rounded-[14px]` (ad-hoc élève).

---

## Backlog priorisé

| # | Priorité | Effort | Finding | Fichier(s) | Action |
|---|---|---|---|---|---|
| 1 | **P0 (a11y/légal)** | S | Mentions légales placeholder | `app/views/pages/legal.html.erb:11-16, 21, 26-27, …` | Remplir avec données réelles (nom, adresse, hébergeur, email) avant prod publique. |
| 2 | **P0 (a11y)** | S | Touch targets < 24×24 mobile | `student/subjects/index.html.erb:12,16`, `student/settings/show.html.erb:12`, `student/subjects/_subject_header.html.erb:2,9` | Wrapper chaque chevron/menu dans `<a class="inline-flex items-center justify-center min-w-11 min-h-11 …">`. |
| 3 | **P0 (a11y)** | M | Contraste rad-muted sur rad-warm < 4.5 | `student/conversations/_drawer.html.erb:61,118`, `student/tutor/_tutor_banner.html.erb:9,15,17` | Soit assombrir `--color-rad-muted` à #5a5546+, soit utiliser `text-rad-text` sur les zones warm. |
| 4 | **P1** | S | Activation tuteur hors marque | `app/views/student/tutor/_tutor_activated.html.erb` | Reskin en rad (`bg-rad-green/10 text-rad-green border-rad-green/20` + ✓ stylé). |
| 5 | **P1 (a11y)** | M | Focus-visible global manquant | `student/**` (5 occurrences sur 230+ liens) | Ajouter `@layer base { a:focus-visible, button:focus-visible { outline: 2px solid var(--color-rad-teal); outline-offset: 2px; } }` dans `application.css`. |
| 6 | **P1** | M | CardComponent footer fixe `border-rad-rule` | `app/components/card_component.html.erb:15` | Conditionner la classe selon `@variant` (rad → rad-rule, default → slate-200/700, glow → indigo-500/15). |
| 7 | **P1** | M | ButtonComponent inutilisable côté élève | `app/components/button_component.rb`, ~20 sites student/ | Ajouter variantes `:rad_primary` (bg-rad-red text-rad-cream), `:rad_ghost`, `:rad_ink`. Migrer 5 CTA prioritaires (CTA sujets, login, suivant question, settings save, chat send). |
| 8 | **P1** | M | BadgeComponent API hybride | `app/components/badge_component.rb` | Documenter en haut du fichier que `:rad_*` est la norme. Renommer les variantes Tailwind en `:legacy_indigo` pour signaler la dette. |
| 9 | **P1 (a11y)** | S | Liens icon-only sans aria-label | `student/subjects/index.html.erb:12,16`, `student/settings/show.html.erb:12,16`, `student/subjects/_subject_header.html.erb:2,9` | Ajouter `aria: { label: "Retour" }`, etc. |
| 10 | **P2 (brand)** | L | Layout teacher hors-marque | `app/views/layouts/teacher.html.erb`, ~1100 lignes teacher/ | Phase 1 : ajouter `font-teacher` + bande stripes top. Phase 2 (long terme) : migrer accent indigo → rad-teal. Phase 3 : adopter tokens rad-rule/paper/text. |
| 11 | **P2** | M | Magic numbers (`text-[10.5px]`, `rounded-[14px]`, `px-[18px]`) | `student/**` (115+ occurrences) | Créer `@layer components` avec `.text-eyebrow`, `.text-question-balance`, `.rounded-rad-button` (14px). Migrer en plusieurs PRs ciblées par écran. |
| 12 | **P2** | S | application.css vide | `app/assets/stylesheets/application.css` | Supprimer le manifest et le `stylesheet_link_tag :app` dans les 3 layouts. |
| 13 | **P2** | S | Iframe teacher hauteur fixe | `teacher/parts/show.html.erb:95,99,135,143,149` | Remplacer `height="700"` par `class="h-[calc(100vh-200px)] min-h-[500px]"`. |
| 14 | **P2 (a11y)** | M | Mode par défaut radio non accessible | `student/settings/show.html.erb:41-56` | Wrap dans `<fieldset role="radiogroup" aria-label="Mode par défaut à l'ouverture d'un sujet">`, ajouter `focus-visible` sur les labels, vérifier `aria-checked` propagé. |
| 15 | **P3** | S | Avatar Tibo SVG sizes (6 tailles différentes) | `student/**/_*.erb` (cf. dim 4) | Définir 3 tailles canoniques (`avatar-sm` 24px, `avatar-md` 32px, `avatar-lg` 40px) en `@layer components`, remplacer. |
| 16 | **P3** | S | ProgressBarComponent variants incomplètes | `app/components/progress_bar_component.rb` | Ajouter `:rad_red`, `:rad_yellow`, `:rad_green`. Remplacer `:emerald` côté teacher stats par `:rad_teal`. |
| 17 | **P3 (a11y)** | S | ThemeToggle sans aria-pressed | `app/components/theme_toggle_component.rb` | Lire `current_theme` dans le composant, ajouter `aria: { pressed: is_dark }`. |
| 18 | **P3** | M | NavBarComponent brand gradient fixe | `app/components/nav_bar_component.html.erb:6` | Extraire le style brand en slot, permettre `nav.with_brand` d'apporter ses propres classes. |
| 19 | **P3** | L | Layouts dupliqués (application + student) | `app/views/layouts/{application,student}.html.erb` | Extraire `app/views/shared/_head.html.erb` partagé. |
| 20 | **P3** | M | Pattern madras + contraste bulles | `student/conversations/_drawer.html.erb:74` | Wrapper dans `@media (prefers-contrast: more) { .pattern-madras-diagonal { background-image: none; } }`. |
| 21 | **P4** | S | Mix red/rose dans subjects show | `teacher/subjects/show.html.erb:144,175` | Choisir une couleur destructive (rose) et l'appliquer. |
| 22 | **P4** | S | Tableaux teacher sans scope/caption | `teacher/classrooms/show.html.erb:118-145`, `subjects/index.html.erb:60-104` | Ajouter `<caption class="sr-only">` et `scope="col"` sur `<th>`. |

Légende effort : S = <2h, M = 2-8h, L = >8h.

---

## Limites de cet audit

- **Pas de browser runtime** : pas de mesure réelle de FCP/LCP, pas de capture des paint flashes, pas de vérif zoom 200%, pas de test contraste sur écran réel (calcul théorique uniquement).
- **Pas de validation utilisateur** : les recommandations brand (notamment unifier teacher avec rad) supposent une volonté produit. À valider avec l'auteur — il est possible que la séparation visuelle teacher/élève soit intentionnelle (deux univers, deux publics).
- **Pas d'audit en dark mode** : tous les ratios de contraste calculés sont en thème clair. Le dark mode des vues student est techniquement OK (override CSS vars) mais visuellement non vérifié.
- **Stimulus controllers non lus en profondeur** : `tutor_chat_controller.js`, `confetti_controller.js`, `focus_trap_controller.js` non audités pour leur impact visuel (animations, focus management runtime).
- **Pages non testées** : `app/views/pages/privacy.html.erb` (lue partiellement), exports PDF (Prawn), pages d'erreur Rails (404/500), Devise views (si overridées).
- **Composants éval. statique** : le `FocusTrapController` est cité mais le comportement n'a pas été vérifié.
- **Pas de mesure de bundle** : `tailwind.css` non pesé (purge supposée OK car Tailwind 4 JIT par défaut).
- **A11y `prefers-reduced-motion`** : déclaré au niveau global mais l'effet réel sur Confetti / drawer transitions non vérifié.

---

**Résumé pour l'auteur** : le système Radical côté élève est une vraie réussite design (identité, hiérarchie, ergonomie), mais souffre de magic numbers (maintenance) et de faiblesses a11y mobiles (touch targets, focus). Le côté teacher vit dans un autre univers — la priorité produit est de décider : reskin progressif ou cohabitation assumée ? Les 5 P0/P1 a11y/légal devraient être traités avant tout déploiement public.

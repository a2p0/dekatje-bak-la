# Design System Radical unifié — synthèse pré-speckit
Date : 2026-05-17
Sources :
- bundle claude.ai/design `h/YiyL6SBBamTp3pu9UnSZsg` (local : `/tmp/claude-design-h-YiyL/dekatje/`)
- état courant du repo (`app/assets/tailwind/application.css`, `app/components/**`, `app/views/layouts/**`)
- audit `docs/audits/2026-05-16-ui-design-audit.md` (P0-P4 backlog)

---

## 1. Intention du designer (extraits chats)

8 chats (2026-04-29 → 2026-05-11), un seul fil narratif : transformer l'app SaaS-générique en application avec une identité visuelle martiniquaise propre.

**Décisions clés** :

| Chat | Date | Décision |
|---|---|---|
| 1 | 2026-04-29 | 3 directions explorées (Safe/Audacieux/Radical). User valide **Radical** mais demande typo de Audacieux (Fraunces) + dark teal au lieu de quasi-noir. Sources : `chats/chat1.md:196-217`. |
| 1 | 2026-04-29 | Direction Radical v2 finalisée : palette balisier/soleil/mer (red/yellow/teal) + cream paper + ink + Fraunces serif (`chat1.md:245-267`). Tibo en mascotte (cercle rouge, T italic Fraunces). |
| 2 | 2026-04-30 | Couverture étendue : `subjects#show` 6 états + auth/settings/home (13 écrans mobiles totaux). |
| 3 | 2026-05-02 | 5 écrans complémentaires : navigation bottom-bar, onboarding 3 étapes, overlay DT, erreurs. **Drawer Tibo** redessiné : header beige foncé `#e8e0cc` (warm), bande madras 45°, bulles user rouges. Stripes 4 couleurs gardées en top (`chat3.md:393-425`). |
| 4 | 2026-05-03 | **Écrans enseignant** : direction « Radical plus allégé », typo Plus Jakarta Sans (`--font-teacher`). Fusion variations A+C : navbar horizontale crème, cap vertical coloré pour liste sujets, stats pills, mobile prévu. |
| 5 | 2026-05-04 | 8 écrans teacher couverts (classes + sujets). Décision UX : remplacer fausse barre progression élève par indicateur d'activité (vert/gris/rouge). |
| 6 | 2026-05-04 | 6 écrans secondaires teacher : Import CSV, Export PDF, Validation post-IA, Assignation, Publication, Édition question. Split en plusieurs JSX pour éviter overload Babel. |
| 7 | 2026-05-05 | **Vues desktop élève** créées (3 écrans : lecture / correction / tutorat) — split 50/50 question \| DT, navbar top, 1280px. Source : `directions/student-desktop.jsx`. |
| 8 | 2026-05-11 | Question opérationnelle sur disparition d'affichage — pas de décision design. |

**Verdict final (à retenir pour le speckit)** :
1. **Une seule direction** : Radical, déclinée en deux saveurs (élève chaleureux Fraunces+Inter / enseignant sobre Plus Jakarta Sans).
2. **Palette identique** sur les deux audiences ; **typo et chromatique d'accent** marquent la différence (élève = red accent + Fraunces ; teacher = teal accent + Plus Jakarta Sans).
3. **Dark mode** : teal profond `#0f2f33`, pas quasi-noir. Aucune décision dark explicite côté teacher dans les chats — voir §8.
4. **Stripes martiniquaises 4 couleurs (red/yellow/teal/ink) en top** : signature visuelle partagée des deux univers. Le bundle teacher en a un usage explicite (`teacher/screens-dashboard.jsx:13`).
5. **Pattern madras** : décoratif, deux variantes (orthogonal pour cartes hero, diagonal 45° pour drawer tuteur).

---

## 2. Identité visuelle Radical — version unifiée

### 2.1 Palette primitives

Tableau exhaustif extrait de `directions/radical.jsx:6-19`, `directions/subj-shared.jsx:3-16`, `teacher/shared.jsx:2-18`. Les trois fichiers convergent sur les **mêmes valeurs** : la palette est déjà unifiée dans le bundle.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `bg` | `#fbf7ee` (cream) | `#0f2f33` (deep teal) | Fond global |
| `paper` | `#ffffff` | `#143b40` | Surface cartes |
| `raise` | `#fdfaf3` | `#1a4a50` | Surfaces relevées (hover, chat bubbles) |
| `text` | `#0e1b1f` | `#f5ecdc` | Texte principal |
| `muted` | `#6b665a` | `#a8c2c5` | Texte secondaire |
| `rule` | `#e6dcc1` | `#22585e` | Bordures, séparateurs |
| `red` | `#d4452e` | `#e85a44` | CTA principal élève, accent balisier |
| `yellow` | `#e8b53f` | `#f0c25e` | Tags DT, data hints, soleil |
| `teal` | `#127566` | `#5fc5b8` | CTA principal teacher, accent mer |
| `green` | `#2e8b3a` | `#7bc77a` | Réponse correcte, statut publié |
| `ink` | `#0e1b1f` | `#f5ecdc` | Pour fonds inversés (boutons Tibo) |
| `cream` | `#fbf7ee` | `#fbf7ee` (fixe) | Texte sur fond ink/red |
| `warm` | `#e8e0cc` | `#1a4a50` | Header/footer drawer tuteur (« beige plus foncé ») — uniquement utilisé côté élève |

Variantes spécifiques teacher (`teacher/shared.jsx:16-18`) :
| Token | Light | Dark | Usage |
|---|---|---|---|
| `amber` | `#fffbeb` | `#2a2010` | Banners avertissement (mode libre Tibo) |
| `amberBorder` | `#fde68a` | `#5a4a10` | Bordure des banners amber |

État courant repo `app/assets/tailwind/application.css:20-68` :
- 12/13 tokens déjà alignés avec le bundle.
- `--color-rad-warm` déjà présent (commentaire « tutor drawer header/footer »).
- **Manquants côté Rails** : `--color-rad-amber`, `--color-rad-amber-border` (pour adoption teacher).

### 2.2 Adaptation par audience

| Aspect | Student (Radical chaleureux) | Teacher (Radical sobre) |
|---|---|---|
| Police titres / display | **Fraunces** serif, souvent en italic (`'Fraunces', serif`) | **Plus Jakarta Sans** sans-serif (`--font-teacher`) |
| Police corps / UI | Inter | Plus Jakarta Sans (même police pour titre et corps) |
| Police mono | JetBrains Mono (calculs, valeurs data hints) | JetBrains Mono (idem si besoin) |
| Accent CTA primaire | `red` (`#d4452e`) | `teal` (`#127566`) |
| Accent navigation actif | `red @ 18% bg` + texte `red` (`student-desktop.jsx:29-31`) | `teal @ 18% bg` + texte `teal` (`teacher/shared.jsx:108-110`) |
| Stripes top | 4 stripes obligatoires (red/yellow/teal/ink) | 4 stripes (mêmes, hauteur 5px au lieu de 6px) |
| Pattern décoratif | madras (cartes hero) + madras-diagonal (drawer Tibo) | aucun en l'état dans le bundle teacher (sobriété assumée) |
| Border radius cartes | 12-20px (variations Fraunces friendly) | 10-12px (`teacher/shared.jsx:158-160`) |
| Brand logo | « DekatjeBakLa » italic Fraunces (`student-desktop.jsx:23`) | « DekatjeBakLa » bold Plus Jakarta Sans, couleur teal (`teacher/shared.jsx:102`) |
| Bouton Btn primary | rad-red + cream | rad-teal + white + box-shadow teal-44 (`teacher/shared.jsx:152`) |
| Avatar utilisateur | Cercle teal 22 + initiale Fraunces italic (`student-desktop.jsx:43`) | Cercle teal plein + initiales bold (`teacher/shared.jsx:115`) |

### 2.3 Typographie, radius, shadows, spacing

**Typographie — échelle observée dans le bundle (à canonicaliser)** :
| Token sémantique proposé | Student | Teacher |
|---|---|---|
| `eyebrow` (uppercase meta) | 10.5px, weight 700, letter-spacing 0.14-0.16em, color `muted` | 11px, weight 700 |
| `body-sm` | 11-12px Inter | 11-12px Plus Jakarta Sans |
| `body` | 13-13.5px Inter line-height 1.55 | 12-13px |
| `body-lg` | 15-19px Fraunces serif | 14-15px Plus Jakarta Sans |
| `display-sm` | Fraunces 22px (titre question) | 15-16px bold |
| `display-md` | Fraunces 26px-36px (numéro question, réponse) | 18-22px bold (h1) |
| `display-lg` | Fraunces 52px (« 56,73 L » correction desktop) | n/a |

**Border radius observés** :
| Token | Valeur | Usage |
|---|---|---|
| `radius-sm` | 6px | Tags (`DT1`), petits chips |
| `radius-button` | 8-10px | Boutons teacher, chips |
| `radius-card` | 12-14px | Cartes standard |
| `radius-card-lg` | 16-20px | Cartes hero (réponse correction, mise en situation) |
| `radius-pill` | 9999px | Pills, FAB, chips |

État courant repo (`application.css:36-39`) : `--radius-card: 1rem (16px)`, `--radius-button: 0.75rem (12px)`, `--radius-input: 0.75rem`, `--radius-pill: 9999px`. Cohérent mais ne couvre pas le 14px qui revient ~44 fois dans les vues élève. **Décision pré-speckit** : ajouter `--radius-rad: 14px` ou aligner les vues sur `--radius-card`.

**Shadows** observés :
- `0 8px 20px -8px rgba(0,0,0,0.35)` — FAB Tibo (`radical.jsx:55`)
- `0 2px 8px ${pal.teal}44` — Btn primary teacher (`teacher/shared.jsx:152`)
- `0 6px 20px ${pal.teal}20` — card hover teacher (`screens-dashboard.jsx:38`)
- `0 1px 2px rgba(14,27,31,0.04)` — stats pill teacher (`screens-dashboard.jsx:19`)

Aucun token shadow dans `application.css` aujourd'hui : à introduire (`--shadow-rad-fab`, `--shadow-rad-card`, `--shadow-rad-cta`).

**Spacing** : bundle utilise des paddings ad-hoc (14-32px). Recommandation alignée avec l'audit (P2 #11) : adopter strictement l'échelle Tailwind 1/2/3/4/5/6/8/12/16, bannir les `[XXpx]`. Aucun token spacing custom requis si on respecte l'échelle.

---

## 3. Architecture tokens recommandée (2 couches)

### 3.1 Couche primitives (couleurs absolues)

Définies une seule fois, jamais consommées directement par les vues.

```css
@theme {
  /* === PRIMITIVES (palette absolue, ne PAS consommer en vue) === */
  --palette-cream:    #fbf7ee;
  --palette-paper:    #ffffff;
  --palette-raise:    #fdfaf3;
  --palette-ink:      #0e1b1f;
  --palette-stone:    #6b665a;
  --palette-sand:     #e6dcc1;
  --palette-warm:     #e8e0cc;
  --palette-balisier: #d4452e;
  --palette-sun:      #e8b53f;
  --palette-sea:      #127566;
  --palette-leaf:     #2e8b3a;

  /* Dark equivalents */
  --palette-deep-teal:    #0f2f33;
  --palette-deep-surface: #143b40;
  --palette-deep-raise:   #1a4a50;
  --palette-bone:         #f5ecdc;
  --palette-mist:         #a8c2c5;
  --palette-deep-rule:    #22585e;
  --palette-balisier-d:   #e85a44;
  --palette-sun-d:        #f0c25e;
  --palette-sea-d:        #5fc5b8;
  --palette-leaf-d:       #7bc77a;
}
```

### 3.2 Couche sémantique (rôles d'usage)

Consommée par les composants et les vues. Le mapping change selon le thème actif.

```css
@theme {
  /* === SEMANTIQUE (à consommer dans les vues) === */
  --color-surface:           var(--palette-cream);
  --color-surface-elevated:  var(--palette-paper);
  --color-surface-raised:    var(--palette-raise);
  --color-surface-inverse:   var(--palette-ink);
  --color-surface-warm:      var(--palette-warm);  /* tutor drawer */

  --color-on-surface:        var(--palette-ink);
  --color-on-surface-muted:  var(--palette-stone);
  --color-on-inverse:        var(--palette-cream);

  --color-rule:              var(--palette-sand);

  --color-accent-primary:    var(--palette-balisier);  /* sera surchargé par data-audience=teacher */
  --color-accent-secondary:  var(--palette-sea);
  --color-accent-warning:    var(--palette-sun);
  --color-accent-success:    var(--palette-leaf);
  --color-accent-danger:     var(--palette-balisier);
  --color-on-accent:         var(--palette-cream);
}
```

### 3.3 Mapping par thème

**3 thèmes activables** (proposés) :
1. **`radical-student-light`** (défaut) : accent primaire = balisier, font = Fraunces+Inter.
2. **`radical-teacher-light`** : accent primaire = sea, font = Plus Jakarta Sans. Activé via `<body data-audience="teacher">` ou `<html data-theme="teacher">`.
3. **`radical-*-dark`** : mêmes mappings avec primitives dark. Activé via `.dark` ajouté à `<html>` (pattern Tailwind 4 existant).

```css
[data-audience="teacher"] {
  --color-accent-primary:    var(--palette-sea);
  --color-accent-danger:     var(--palette-balisier);  /* le rouge reste pour destruction */
  /* font swap */
  --font-display: var(--font-teacher);
  --font-body:    var(--font-teacher);
}

.dark {
  --color-surface:          var(--palette-deep-teal);
  --color-surface-elevated: var(--palette-deep-surface);
  --color-surface-raised:   var(--palette-deep-raise);
  --color-surface-inverse:  var(--palette-bone);
  --color-surface-warm:     var(--palette-deep-raise);
  --color-on-surface:       var(--palette-bone);
  --color-on-surface-muted: var(--palette-mist);
  --color-on-inverse:       var(--palette-deep-teal);
  --color-rule:             var(--palette-deep-rule);
  --color-accent-primary:   var(--palette-balisier-d);
  --color-accent-secondary: var(--palette-sea-d);
  --color-accent-warning:   var(--palette-sun-d);
  --color-accent-success:   var(--palette-leaf-d);
}
```

### 3.4 Implémentation Tailwind v4

Tailwind 4 supporte les CSS custom properties dans `@theme` (déjà utilisé dans `app/assets/tailwind/application.css:13`).

**Stratégie recommandée** :
- Conserver l'utilitaire `bg-rad-paper`, `text-rad-text` pendant la migration (bridge).
- Ajouter une seconde série d'utilitaires sémantiques `bg-surface`, `text-on-surface`, `bg-accent`, `text-on-accent`.
- Marquer les anciens comme dépréciés (commentaire dans le CSS + section dans `docs/design-system/`).
- Migrer écran par écran.

**Activation du thème teacher** : ajouter `data-audience="teacher"` sur `<body>` de `app/views/layouts/teacher.html.erb`. Aucun JS requis.

**Note Tailwind 4** : valider la syntaxe `@custom-variant` pour `data-audience` (similaire à `dark` déjà en place ligne 10). Doc à consulter sur tailwindcss.com (Context7 recommandé) avant implémentation.

---

## 4. Composants à refondre

### 4.1 Atomes

**Button** (refonte complète, `app/components/button_component.rb`) :

API cible (variantes sémantiques uniquement, plus de couleurs hardcodées) :
- `:primary` → bg `accent-primary`, color `on-accent`. (rouge côté élève, teal côté teacher automatiquement via tokens)
- `:secondary` → outline `on-surface`, fond transparent
- `:ghost` → fond transparent, texte muted
- `:danger` → bg `accent-danger`, color `on-accent`
- `:ink` → bg `surface-inverse`, color `on-inverse` (utilisé pour FAB Tibo)

Tailles : `:sm` (8/12px padding, text-xs), `:md` (10/18px, text-sm), `:lg` (14/24px, text-base) — calquées sur `teacher/shared.jsx:157-160`.

États requis : `:hover`, `:focus-visible` (outline accent-secondary, offset 2px — applique aussi le finding audit P1 #5), `:active`, `:disabled` (opacity 0.6), `:loading` (spinner inline + aria-busy).

**Badge** (refonte, `app/components/badge_component.rb`) :

Supprimer les 6 variantes Tailwind legacy (`:indigo, :emerald, :amber, :blue, :slate, :rose`). Garder uniquement les variantes sémantiques + variantes specialty :
- `:primary` (accent-primary)
- `:secondary` (accent-secondary)
- `:warning` (accent-warning)
- `:success` (accent-success)
- `:neutral` (rule + muted)
- `:specialty_sin`, `:specialty_itec`, `:specialty_ec` (sémantique métier, mapping vers couleurs)

Cf. bundle `teacher/shared.jsx:73-91` qui utilise déjà ce pattern (`Badge color={specialtyColor(c.specialty)}`).

États : aucun (badge non-interactif). Outline border systématique pour lisibilité.

**Card** (`app/components/card_component.rb`) :

Audit P1 #6 : bug du footer `border-rad-rule` quelle que soit la variante. À corriger.

API cible :
- `variant: :default` → surface + rule
- `variant: :elevated` → surface-elevated + shadow
- `variant: :hero` → fond accent (success/warning), pattern madras optionnel, color on-accent (cf. carte « Réponse 56,73 L » `radical.jsx:182-193`)
- `variant: :outlined` → transparent + accent border-left 4px (cf. cap vertical statut `screens-dashboard.jsx:68`)
- `accent: :primary|:secondary|:warning|:success` (couleur cap si outlined)

Slots : `header`, `body`, `footer`. Footer doit hériter de la variant pour la bordure.

**Field** (`teacher/shared.jsx:171-201` — n'existe pas comme composant Rails, à créer) :

Wrapper input/textarea/select/file unifié avec label, hint, error. Pattern complet déjà dessiné dans le bundle (zone dropzone PDF avec icône custom). Recommandé en complément de Button.

**Stripes** (atome neuf) :

Bande de 4 couleurs en top des layouts. Récurrent dans 8+ fichiers du bundle. À extraire en partial `app/views/shared/_stripes.html.erb` ou composant `StripesComponent`.

```erb
<div class="flex h-[5px] flex-shrink-0">
  <div class="flex-1 bg-rad-red"></div>
  <div class="flex-1 bg-rad-yellow"></div>
  <div class="flex-1 bg-rad-teal"></div>
  <div class="flex-1 bg-rad-ink"></div>
</div>
```

### 4.2 Composés

**NavBar** (`app/components/nav_bar_component.html.erb`) :

Audit P3 #18 : brand gradient figé indigo→violet, inutilisable côté élève.

Refonte API :
- Slots `brand`, `links`, `actions` (déjà présents)
- Variante implicite via `data-audience` du layout (pas de prop sur le composant)
- Inclure Stripes en haut par défaut (`with_stripes: true` opt-out possible)
- Brand : weight + color via tokens, plus de gradient
- Liens actifs : bg `accent-primary @ 18%`, color `accent-primary`

Le composant `student/shared/_desktop_nav.html.erb` réécrit aujourd'hui tout from scratch — à fusionner.

**BottomBar** (`app/components/bottom_bar_component.{rb,html.erb}`) :

Audit P3 : composant orphelin (`student/questions/show.html.erb:213-261` réécrit ad-hoc). Bundle prévoit pattern bottom-tab `Sujets / Progression / Réglages` (`directions/student-flows.jsx`). À recâbler avec API tabs.

**Breadcrumb** (`app/components/breadcrumb_component.html.erb` + bundle `teacher/shared.jsx:119-136` + `student-desktop.jsx:50-66`) :

Pattern unifié déjà visible dans bundle : séparateur `›`, dernier item bold non-cliquable, autres items en accent-secondary souligné. Vérifier que le composant Rails couvre.

**Modal** (`app/components/modal_component.html.erb`) :

Audit P3 : couleurs slate/indigo hardcodées. Refonte tokens (surface-elevated + rule + shadow).

**Flash** (`app/components/flash_component.rb`) :

Audit P1 : emerald + rose Tailwind. Migrer vers `accent-success` / `accent-danger` + variante `info` (accent-secondary).

**ProgressBar** (`app/components/progress_bar_component.rb`) :

Audit P3 #16 : variantes incomplètes. Refondre avec couleurs sémantiques uniquement (`:primary, :secondary, :warning, :success`). Le pattern « N segments » utilisé côté élève (`radical.jsx:88-90`, `student-desktop.jsx:179-187`) mérite sa propre variante : `SegmentedProgress` ou option `mode: :segmented`.

### 4.3 Mapping état actuel ↔ cible

| Composant existant | Problème actuel (audit) | Action speckit |
|---|---|---|
| `BadgeComponent` | Double API 6 Tailwind + 4 rad (finding #6) | Refonte API sémantique, drop legacy. Migration 1 PR. |
| `ButtonComponent` | Gradient indigo, jamais utilisé élève (finding #8) | Refonte tokens + variants sémantiques. 5 CTA prioritaires à migrer (login, suivant, chat send, settings, sujet CTA). |
| `CardComponent` | Footer border hardcodé (finding #7) | Bugfix + variants `:elevated / :hero / :outlined`. |
| `NavBarComponent` | Brand gradient figé (finding #12) | Refonte avec slots + Stripes + variants implicites. Supprimer `_desktop_nav.html.erb` doublon. |
| `BottomBarComponent` | Orphelin (finding #11) | Recâbler ou supprimer. Décision speckit. |
| `ModalComponent` | Couleurs slate/indigo (finding #13) | Tokens migration. |
| `FlashComponent` | emerald/rose Tailwind (finding #14) | Tokens migration. |
| `ProgressBarComponent` | Variantes incomplètes (finding #10) | Ajouter `:rad_red, :rad_yellow, :rad_green` puis tokens sémantiques. |
| `ThemeToggleComponent` | Pas d'aria-pressed (audit #17, P3) | aria-pressed + label dynamique. |
| `BreadcrumbComponent` | Inconnu / à vérifier | Comparer avec pattern bundle, aligner. |
| (nouveau) `StripesComponent` | n/a | Créer. |
| (nouveau) `FieldComponent` | n/a (formulaires teacher éparpillés) | Créer (cf. `teacher/shared.jsx:171-201`). |
| (nouveau) `EmptyStateComponent` | absent (audit dim 4) | Créer pour homogénéiser `<p>Aucun ...</p>`. |

---

## 5. Écrans modélisés dans le bundle

### 5.1 Student

**Mobile (`directions/radical.jsx`)** — 3 écrans question :
1. **Lecture** — Stripes + header discret + barre progression segmentée + carte « Mise en situation » jaune-accent + bloc question (numéro rouge 56×56 + tag DT jaune empilés à gauche, énoncé Fraunces 19px à droite) + carte DT en dashed-border + FAB Tibo + sticky CTAs (correction outline / suivant rouge).
2. **Correction** — rappel question italic + grande carte verte hero (« 56,73 L » 36px Fraunces, pattern madras 18% opacity) + carte verte outlined « Détail du calcul » + carte jaune outlined « Où trouver les données ? » + (selon ajustements user) plus de FAB Tibo.
3. **Tutorat Tibo** — header beige foncé `warm` + Stripes 4 couleurs au top + avatar Tibo cercle rouge + indicateur présence teal + bulles user rouge / Tibo paper + chips suggestions avec border-left coloré, fond pattern madras 45°, input en bas dans footer warm.

**Mobile flows (`directions/student-flows.jsx`)** :
- Bottom tab bar (Sujets / Progression / Réglages)
- Onboarding 3 étapes (Code classe → Présentation → Login)
- Overlay DT bottom-sheet
- Erreur Code invalide
- Erreur Sujet non dispo

**Mobile subject (`directions/subj-states-{a,b,c,d}.jsx`)** : 6 états `subjects#show` (Scope, Parties, Présentation spé, Questions sautées, Bravo, Relecture). Une seule direction retenue (pas de variations A/B/C/D au sens du bundle ; les états sont segmentés par fichier pour éviter overload Babel). **Réponse à la question implicite du sommaire** : il n'y a pas 4 directions explorées mais 4 fichiers de découpage technique d'une seule direction.

**Desktop (`directions/student-desktop.jsx`)** — 3 écrans :
1. **Lecture desktop** : navbar top crème + breadcrumb + barre progression + split 50/50 (énoncé à gauche / `StudentDTPanel` à droite avec onglets DT, hint banner, faux PDF viewer avec ligne mise en surbrillance jaune, pagination).
2. **Correction desktop** : même chrome, gauche = correction avec réponse hero 52px Fraunces, détail calcul mono, explication, data hints, concepts.
3. **Tutorat Tibo desktop** : split 60/40 — gauche chat avec header warm, bulles, chips, input pattern madras-diagonal en fond ; droite contexte (question avec numéro 52px + tags + mise en situation + progression + documents).

### 5.2 Teacher

**Desktop (`teacher/screens-{dashboard,classes,subjects}.jsx` + `teacher/shared.jsx`)** :
- `classrooms#index` — Stats pills (Classes/Élèves/Publiés/À valider) + grille cartes classes + liste sujets récents avec **cap vertical coloré** (green/yellow/rule) selon statut.
- `classrooms#show` — Détail classe avec liste élèves + **indicateur d'activité tricolore** (vert « Actif » / gris « Actif il y a Xj » / rouge « Jamais connecté ») + code accès + bandeau credentials.
- `classrooms#new / edit` — Formulaires avec preview du code généré, toggle mode libre Tibo + banner amber d'avertissement.
- `students#new` — Form + preview identifiants + lien import CSV.
- `subjects#index` — Liste avec filtres statut + cap coloré vertical + actions contextuelles.
- `subjects#show` — Breadcrumb + liste parties + sidebar (PDFs, classes assignées, statut).
- `subjects#new` — Upload PDF sujet + correction + explication flow extraction IA.
- `parts#show` — Liste questions accordéon + détail contexte/correction + action « Valider ».
- **Flux secondaires** (`screens-subjects.jsx`) : StudentImport CSV, ClassroomExport, SubjectValidation, SubjectAssignment, SubjectPublication, QuestionEdit.

**Mobile teacher** : variante 390px partiellement maquettée (`ClassroomsIndexMobile`) avec navbar compacte + bottom tab + stats grille 2×2. Pas de couverture exhaustive — voir §8.

---

## 6. UX navigation — résolution des redondances

L'audit signale (et `app/views/layouts/teacher.html.erb:28-41`) : NavBar teacher contient `Mes classes`, `Mes sujets`, `ThemeToggle`, `Mon profil`, `Déconnexion` — soit 3 liens d'actions à droite, redondants visuellement (deux liens « profil/déconnexion » texte muted indistincts).

**Pattern proposé par le bundle** (`teacher/shared.jsx:94-117`) :
- Brand à gauche
- Liens primaires juste après (Mes classes / Mes sujets)
- À droite : **un seul avatar circulaire** avec initiales (le menu profil/déconnexion devient un popover sur clic)
- Aucun bouton de thème dans la barre (déplacé en réglages ou popover avatar)

**Actions contextuelles qui appartiennent à la page (pas à la NavBar)** :
- Boutons « Valider », « Assigner », « Publier », « Modifier » sur les sujets — déjà dans le bundle au niveau page (cf. PageHeader avec action en haut à droite de chaque écran).
- L'audit (#7) note un problème spécifique sur `teacher/subjects/show.html.erb` (boutons morts/redondants). Le pattern bundle place les actions principales dans un `SectionHeader action={<Btn>}` (`teacher/shared.jsx:139-147`), pas dans la NavBar.

**Recommandation `NavBarComponent`** :
- Slots : `brand`, `links`, `user_menu` (renommer `actions`)
- `user_menu` rend par défaut un avatar + popover (Stimulus controller)
- Plus de slot pour ThemeToggle dans la NavBar (déplacé dans Settings + user menu)
- Variante implicite via `<body data-audience>` ; visuellement quasi identique entre élève et teacher

---

## 7. Roadmap de migration suggérée

Phases séquentielles, chacune mergeable indépendamment. Estimations grossières : S = <4h, M = 4-12h, L = >12h.

| Phase | Contenu | Effort |
|---|---|---|
| **B0 — Audit P0** | Fixes a11y/légal pré-prod : mentions légales (#1), touch targets (#2), contraste rad-muted/warm (#3), tuteur activé (#4). 4 PRs ciblées. | M |
| **B1 — Tokens 2 couches** | Ajout primitives + sémantiques dans `application.css`. **Bridge** : conserver `--color-rad-*` en alias. `data-audience` sur layout teacher. Tests visuels : aucun changement attendu en élève. | M |
| **B2 — Atomes refondus** | Button (drop indigo, add primary/secondary/ghost/danger/ink + states), Badge (drop 6 legacy + API sémantique), Card (bugfix footer + variants `:elevated/:hero/:outlined`), Field (création), Stripes (création). Tests RSpec ViewComponent. | L |
| **B3 — Composés refondus** | NavBar (refonte slots + user_menu), BottomBar (recâblage ou suppression), Breadcrumb (alignement bundle), Modal (tokens), Flash (tokens), ProgressBar (variantes complètes + mode segmented), ThemeToggle (a11y). | L |
| **B4 — Adoption student** | Remplacer 5 CTA ad-hoc par ButtonComponent, drawer Tibo en composant si pas déjà fait, migration des magic numbers en classes utilitaires `@layer components` (`.text-eyebrow`, `.text-question-balance`). | L |
| **B5 — Reskin teacher** | `data-audience="teacher"` activé. Ajout `font-teacher` sur body. Stripes top de layout. Migration des `bg-slate-*`/`text-indigo-*` vers tokens sémantiques, écran par écran (dashboard → classes → sujets). Pas de refonte structurelle, juste re-tokenisation. | L |
| **B6 — Magic numbers cleanup** | Migration des 123 `[XXpx]` vers tokens/utilities. PRs par dossier (`student/subjects/`, `student/questions/`, `student/conversations/`, ...). Audit final `grep -c "\[.*px\]" app/views/`. | L |
| **B7 — Polish desktop élève** | Implémenter les 3 écrans desktop du bundle (`student-desktop.jsx`) — split 50/50 lecture+correction, split 60/40 tutorat. Feature 064 a déjà posé les bases (split desktop) — surtout vérifier alignement avec le bundle. | M |

Ordre de dépendance : B0 indépendant. B1 prérequis pour tout le reste. B2 prérequis pour B3 (composés consomment atomes). B4 et B5 parallélisables (audiences distinctes). B6 dépend de B2. B7 dépend de B4.

---

## 8. Questions ouvertes à trancher avec le user

1. **Dark mode teacher** : ✅ **TRANCHÉ 2026-05-17** — dark mode teacher **activé**, palette complète (le bundle l'anticipe). Validation visuelle des ~10 écrans teacher en dark à prévoir lors de B5.

2. **`data-audience` ou layout séparé ?** : ✅ **TRANCHÉ 2026-05-17** — **Option A retenue** : conserver `teacher.html.erb` et `student.html.erb` existants, ajouter `<body data-audience="teacher|student">`. Migration minimale, rétrocompatible. Refacto en layout unique (Option B) reportée post-B5 si besoin.

3. **`BottomBarComponent` orphelin** : drop ou recâbler ? Le bundle propose un usage clair (`student-flows.jsx`) mais l'app actuelle utilise une bottom-bar ad-hoc dans `student/questions/show.html.erb`. Si on garde une bottom-bar globale élève, à quoi sert celle de la page question ?

4. **Niveau de re-tokenisation du teacher** : sobre (juste swap `indigo→teal` et `slate→rad-rule`) ou immersif (ajout Stripes top, Plus Jakarta Sans systématique, padding plus généreux comme bundle) ? L'audit (#10) suggère immersif ; le designer (chat4) parle de « design radical plus allégé » — interprétation ouverte.

5. **`--font-teacher` partagée corps + titres** ? Le bundle teacher utilise Plus Jakarta Sans pour les deux (`teacher/shared.jsx:142, 102`). Mais on pourrait introduire Fraunces pour les `<h1>` teacher (effet « éditorial » discret). Décision ?

6. **Tokens nouveaux** : faut-il ajouter `--color-rad-amber` + `--color-rad-amber-border` (utilisés dans bundle teacher pour banners avertissement « mode libre Tibo ») ?

7. **Pattern madras** : la version diagonale est dans `application.css:80-94`. La version orthogonale (cartes hero) est dans le bundle (`index.html:35-41`) mais absente du CSS Rails. À ajouter ?

8. **Shadows** : aucun token shadow aujourd'hui. À introduire (`--shadow-rad-fab`, `--shadow-rad-card`, `--shadow-rad-cta-teal`) ou rester ad-hoc ?

9. **Stripes hauteur** : 5px (teacher) ou 6px (student) ? Unifier à 5px pour tous ?

10. **NavBar variante par audience** : le bundle teacher prévoit `activeTab` en bg `teal @ 18%`. Côté élève desktop, `red @ 18%`. C'est cohérent avec `accent-primary` mais à confirmer : on garde le rouge pour le « tab actif » sur les pages question élève (`Mes sujets` sélectionné) ?

11. **Sticky CTAs mobile** : pattern `StickyBar` (`subj-shared.jsx:44-53`) avec deux boutons (back outline + suivant rouge primary). À standardiser en composant ?

---

## 9. Annexes

### 9.1 Fichiers du bundle lus

- `dekatje/README.md`
- `dekatje/chats/chat{1,2,3,4,5,6,7,8}.md`
- `dekatje/project/index.html`
- `dekatje/project/app.jsx`
- `dekatje/project/directions/radical.jsx` (200 premières lignes — pattern complet)
- `dekatje/project/directions/subj-shared.jsx`
- `dekatje/project/directions/student-desktop.jsx` (intégral)
- `dekatje/project/teacher/shared.jsx` (intégral)
- `dekatje/project/teacher/screens-dashboard.jsx` (80 premières lignes — pattern complet)
- listing complet `dekatje/project/teacher/` et `dekatje/project/directions/`

### 9.2 Fichiers Rails consultés

- `app/assets/tailwind/application.css` (intégral)
- `app/components/badge_component.rb` (intégral)
- `app/components/button_component.rb` (intégral)
- `app/components/card_component.rb` (intégral)
- `app/components/nav_bar_component.html.erb` (intégral)
- `app/views/layouts/teacher.html.erb` (50 premières lignes)
- `docs/audits/2026-05-16-ui-design-audit.md` (intégral — backlog P0-P4)

### 9.3 Citations clés des chats (intention)

> « **Décide pour moi** : identité, couleurs, typographie. Tone : Premium — calme, élégant, presque éditorial. Mobile d'abord (les élèves bossent au téléphone) » — chat1, user
> *Implication : direction visuelle déléguée au designer ; mobile non négociable ; éditorial = Fraunces.*

> « Identité martiniquaise assumée : palette inspirée mer/soleil/balisier, typo distinctive, motifs madras très subtils en arrière-plan, hiérarchie type magazine éducatif » — chat1, designer
> *Source principale de l'ADN visuel Radical.*

> « Direction radical plus allégé » + « Même palette mais plus sobre / pro » — chat3 puis chat4, user pour les écrans teacher
> *Confirme : un seul système Radical, deux degrés d'expressivité.*

> « Aucune des directions n'utilise le gradient indigo→violet du DS actuel — il vieillit mal et brouille la hiérarchie. » — chat1, designer
> *Confirme la suppression du gradient (à appliquer au ButtonComponent et NavBarComponent).*

> « Bouton Q1.2 ↗ dans le header — lien discret vers la question en cours » — chat3
> *Pattern à conserver dans le drawer Tibo desktop : navigation contextuelle légère.*

> « le tag DT1 doit être centré avec le numéro de la question » — chat1, user
> *Décision UX : numéro + DT empilés en colonne à gauche, énoncé à droite. Pattern question canonique.*

---

**Synthèse rédigée** : 2026-05-17. À utiliser comme input pour `/speckit.specify` d'une feature « radical-unified-design-system » (ou découpée en plusieurs features par phase B0-B7).

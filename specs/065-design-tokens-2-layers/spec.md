# Feature Specification: Architecture tokens 2 couches pour thème Radical unifié (B1)

**Feature Branch**: `065-design-tokens-2-layers`
**Created**: 2026-05-17
**Status**: Draft
**Input**: User description: "Phase B1 du chantier design system. Ajoute couches primitives + sémantiques + `data-audience` dans les 2 layouts."

**Contexte de référence** :
- `docs/design-system/2026-05-17-radical-unified-synthesis.md` — synthèse design system (verdicts + roadmap B0-B7)
- `docs/audits/2026-05-16-ui-design-audit.md` — audit UI Designer 10 dimensions
- `app/assets/tailwind/application.css` — tokens `--color-rad-*` actuels

## Clarifications

### Session 2026-05-17

- Q: Quel traitement pour `application.html.erb` (pages publiques home/legal/privacy) ? → A: Option B — ajouter `data-audience="public"` avec mapping CSS explicite équivalent au rendu actuel (pas de divergence visuelle vs aujourd'hui).
- Q: Quelle tolérance pour SC-001 « aucune régression visuelle » ? → A: Diff visuel automatisé, tolérance ≤ 1 % de pixels altérés ET ΔE ≤ 2 par pixel (standard industrie type Percy/BackstopJS/Playwright). Outil CLI léger type `imagemagick compare`.
- Q: Quel set minimum garanti de tokens sémantiques dans B1 ? → A: 19 tokens minimum (set complet de production) — surfaces × 3 (surface, surface-raised, surface-sunken), textes × 2 (on-surface, on-surface-muted), rules × 2 (rule, rule-strong), accents brand × 2 + on (accent-primary/on, accent-secondary/on), états × 4 + on (success/on, warning/on, danger/on, info/on). Le plan peut en ajouter mais pas en retirer.
- Q: Comment vérifier SC-003 (tokens adaptatifs par audience) ? → A: Les deux livrables — (1) spec RSpec automatisé pour CI (Capybara `evaluate_script` lit la couleur résolue sous chaque `data-audience`) ET (2) page démo `/teacher/design-system/preview` sous auth teacher (Storybook-light, sert de docs vivante pour B2-B7). Coût : 1 route + 1 vue ERB.
- Q: Quel seuil pour la croissance du CSS compilé (SC-007) ? → A: Double seuil — ≤ 10 % d'augmentation brute (avant gzip) ET ≤ 5 % après gzip. Réaliste pour la nature de l'ajout (CSS variables compressent bien). Détecte une vraie régression sans bloquer faussement.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Migration invisible des tokens (Priority: P1)

En tant que **développeur de l'app DekatjeBakLa**, je dois pouvoir refondre l'architecture des tokens de couleur (primitives + sémantiques + mapping par audience) sans qu'**aucun écran existant ne change visuellement**, afin que la livraison soit safe et débloque les phases ultérieures (B2-B7) sans risque de régression visuelle.

**Why this priority** : C'est l'unique raison d'être de B1. Sans cette garantie, on ne peut pas livrer une refacto invisible et donc on ne peut rien empiler dessus. Toute déviation visuelle = bug.

**Independent Test** : Capture d'écran avant/après sur 3 écrans représentatifs (login élève, classroom teacher index, drawer Tibo) — les images doivent être pixel-perfect identiques. Validation manuelle par l'utilisateur.

**Acceptance Scenarios** :

1. **Given** un utilisateur enseignant connecté qui visite `/teacher/classrooms`, **When** la PR B1 est mergée, **Then** la page rend exactement la même chose qu'avant (mêmes couleurs, mêmes spacings, mêmes typographies).
2. **Given** un utilisateur élève connecté qui visite une page question avec drawer Tibo ouvert, **When** la PR B1 est mergée, **Then** le drawer Tibo rend exactement la même chose qu'avant.
3. **Given** la page publique `/` (home), **When** la PR B1 est mergée, **Then** la page rend exactement la même chose qu'avant.
4. **Given** la suite de tests CI complète, **When** la PR B1 est exécutée sur GitHub Actions, **Then** tous les tests passent (modulo flakes connues déjà documentées).

---

### User Story 2 — Tokens sémantiques disponibles pour B2-B7 (Priority: P1)

En tant que **développeur préparant B2-B7**, je dois pouvoir consommer des tokens sémantiques (`var(--color-surface)`, `var(--color-accent-primary)`, etc.) dans mes composants futurs, afin que ces composants s'adaptent automatiquement à l'audience (teacher vs student) sans logique conditionnelle.

**Why this priority** : C'est le bénéfice livré par B1. Sans cette API tokens, les phases B2-B7 devraient bidouiller des conditions `if teacher then X else Y` partout.

**Independent Test** : Créer une page de démo (ou un spec unitaire) qui rend un élément `<div style="background: var(--color-accent-primary)">` à l'intérieur d'un layout teacher → la couleur doit être teal. À l'intérieur d'un layout student → la couleur doit être balisier red. Mêmes mappings vérifiés en dark mode.

**Acceptance Scenarios** :

1. **Given** un layout teacher avec `<body data-audience="teacher">`, **When** un élément consomme `var(--color-accent-primary)` en light mode, **Then** la valeur résolue est la couleur teal de la palette Radical (`#127566` ou équivalent défini en couche primitive).
2. **Given** un layout student avec `<body data-audience="student">`, **When** un élément consomme `var(--color-accent-primary)` en light mode, **Then** la valeur résolue est la couleur balisier red de la palette Radical (`#d4452e` ou équivalent défini en couche primitive).
3. **Given** un layout teacher en mode dark, **When** un élément consomme `var(--color-surface)`, **Then** la valeur résolue est la surface dark teacher définie en couche primitive.
4. **Given** un layout student en mode dark, **When** un élément consomme `var(--color-surface)`, **Then** la valeur résolue est la surface dark student définie en couche primitive.

---

### User Story 3 — Bridge rétrocompatible avec les tokens existants (Priority: P1)

En tant que **développeur**, je dois pouvoir continuer à utiliser les anciens tokens `--color-rad-red`, `--color-rad-teal`, `--color-rad-warm`, etc., **sans aucun changement de comportement**, afin que les vues élève (PRs 054-057) et les composants ViewComponent existants continuent de fonctionner pendant les phases B2-B7.

**Why this priority** : Sans bridge, B1 deviendrait une refonte massive qui casse tout ce qui consomme `--color-rad-*` (toutes les vues élève, plusieurs composants). Le bridge est ce qui rend B1 livrable indépendamment.

**Independent Test** : Lancer la suite de tests existante (notamment les feature specs élève) → tout doit passer sans modifier aucune vue ni composant.

**Acceptance Scenarios** :

1. **Given** une vue existante qui consomme `bg-rad-red`, **When** la PR B1 est mergée, **Then** le rendu est identique à avant.
2. **Given** une vue existante qui consomme `text-rad-muted`, **When** la PR B1 est mergée, **Then** le rendu est identique à avant.
3. **Given** une vue existante qui consomme `border-rad-rule`, **When** la PR B1 est mergée, **Then** le rendu est identique à avant.

---

### Edge Cases

- **Pages avec `data-audience="public"`** (layout `application.html.erb` : home, legal, privacy) : le mapping `public` s'applique, identique au rendu actuel. Pas de divergence visuelle.
- **Pages sans `data-audience` du tout** (cas exceptionnel : page d'erreur Rails standalone, mailer rendu en HTML, etc.) : un fallback `:root` doit garantir que les tokens sémantiques ont une valeur définie (probablement équivalente à `public`). Hors scope : aucune page interne ne tombe dans ce cas si les 3 layouts sont correctement attribués.
- **Mode dark sur layout `application.html.erb` (public)** : la palette dark équivalente au rendu actuel s'applique (les pages publiques supportent déjà dark via la classe `.dark` sur `<html>`).
- **Switch de thème (clair ↔ sombre) via ThemeToggleComponent** : ne doit pas être impacté par B1, le comportement actuel doit être préservé sur les deux audiences.
- **Première visite anonyme (avant login)** : `prefers-color-scheme` doit toujours fonctionner.
- **`@media (prefers-contrast: more)` ou `prefers-reduced-motion`** : hors scope B1, ne doit pas être cassé.

## Requirements *(mandatory)*

### Functional Requirements

#### Couche primitives

- **FR-001** : Le système DOIT exposer une **couche primitives** de couleurs absolues (couleurs Radical : cream, deep-teal, ink, balisier-red, sun-yellow, sea-teal, etc.) nommées par essence visuelle, sans référence à un usage (« primary », « surface »). Ces primitives ne SONT JAMAIS consommées directement par les classes Tailwind ou par les vues — seule la couche sémantique les référence.
- **FR-002** : Les primitives DOIVENT couvrir au minimum les valeurs hex listées dans `docs/design-system/2026-05-17-radical-unified-synthesis.md` (§2.1, §3.1), pour les variantes light et dark.

#### Couche sémantique

- **FR-003** : Le système DOIT exposer une **couche sémantique** de tokens nommés par rôle d'usage. **Set minimum garanti (19 tokens)** : `surface`, `surface-raised`, `surface-sunken`, `on-surface`, `on-surface-muted`, `rule`, `rule-strong`, `accent-primary`, `on-accent-primary`, `accent-secondary`, `on-accent-secondary`, `success`, `on-success`, `warning`, `on-warning`, `danger`, `on-danger`, `info`, `on-info`. Le plan peut ajouter des tokens supplémentaires (ex: shadows, opacités, focus-ring) si justifié par un cas d'usage concret en B2, mais ne peut pas retirer du set minimum.
- **FR-004** : Chaque token sémantique DOIT pouvoir être consommé dans une vue Rails ou un composant via `var(--color-<nom>)` ou via une classe utilitaire Tailwind générée par `@theme`.
- **FR-005** : Chaque token sémantique DOIT avoir une valeur définie en light ET en dark, pour les deux audiences (student et teacher).

#### Mapping par audience

- **FR-006** : Le système DOIT permettre de switcher l'ensemble des tokens sémantiques selon une audience active (« student » ou « teacher »), sans dupliquer les vues ni les composants. Le switch DOIT être déclenché par la présence d'un attribut HTML `data-audience` sur le `<body>` (ou un ancêtre équivalent).
- **FR-007** : Les valeurs des tokens sémantiques pour l'audience student DOIVENT préserver visuellement le rendu actuel (rétrocompatibilité 100 %). Pour teacher, les valeurs DOIVENT correspondre à la variante Radical-sobre décrite dans la synthèse (accent teal au lieu de red, font Plus Jakarta Sans au lieu de Fraunces — la font n'est PAS un token couleur mais doit elle aussi être pilotée par `data-audience`).
- **FR-008** : Le système DOIT supporter le dark mode pour les DEUX audiences (teacher inclus, conformément à la décision utilisateur du 2026-05-17). Le mécanisme de bascule dark/light existant (classe `.dark` sur `<html>` ou attribut équivalent) DOIT continuer de fonctionner pour les deux audiences.

#### Bridge avec les tokens existants

- **FR-009** : Les tokens existants `--color-rad-*` (12 entrées listées dans `app/assets/tailwind/application.css`) DOIVENT être conservés et rester fonctionnels. Ils deviennent des **aliases** pointant vers les nouvelles couches (primitives ou sémantique), de sorte que toute vue ou composant qui les consomme aujourd'hui continue de produire exactement le même rendu visuel.
- **FR-010** : Aucune vue, partial, helper ou composant existant NE DOIT être modifié dans cette feature (en dehors des 2 layouts pour ajouter `data-audience`).

#### Layouts

- **FR-011** : Le layout `app/views/layouts/student.html.erb` DOIT être modifié pour ajouter `data-audience="student"` sur la balise `<body>`.
- **FR-012** : Le layout `app/views/layouts/teacher.html.erb` DOIT être modifié pour ajouter `data-audience="teacher"` sur la balise `<body>`.
- **FR-013** : Le layout `app/views/layouts/application.html.erb` (utilisé par les pages publiques : home, legal, privacy) DOIT être modifié pour ajouter `data-audience="public"` sur la balise `<body>`. Le mapping CSS pour `[data-audience="public"]` DOIT être défini explicitement, avec des valeurs équivalentes au rendu actuel (pas de divergence visuelle). Les pages publiques restent donc **visuellement identiques** à aujourd'hui.

#### Tests

- **FR-014** : Au moins un test automatisé DOIT vérifier que les nouveaux tokens sémantiques (au moins `--color-surface`, `--color-accent-primary`, `--color-on-surface`, `--color-rule`) sont présents dans le CSS compilé après asset compilation.
- **FR-015** : Au moins un test automatisé DOIT vérifier la présence de l'attribut `data-audience` avec la valeur attendue dans les layouts (au moins teacher et student).
- **FR-016** : La suite de tests feature spec existante (Capybara) DOIT continuer à passer sans modification (modulo flakes Selenium déjà documentées et indépendantes de B1).

### Key Entities

- **Token primitive** : une couleur absolue nommée par essence visuelle (ex: `--rad-prim-cream`, `--rad-prim-balisier-red`), définie en variante light ET dark si applicable. Non consommée par les vues, jamais. Source de vérité.
- **Token sémantique** : un rôle d'usage (ex: `--color-surface`, `--color-accent-primary`) qui pointe vers une primitive via `var(...)`. Consommé par les vues et composants. Son mapping vers la primitive change selon l'audience et le mode (light/dark).
- **Audience** : un attribut HTML `data-audience` portant la valeur `student`, `teacher`, ou éventuellement `public`. Activé via le layout. Active une variante de mapping sémantique → primitive.
- **Mode (light/dark)** : déclenché par la classe `.dark` (mécanisme existant). Croisé avec l'audience, produit 4 combinaisons : student-light, student-dark, teacher-light, teacher-dark.
- **Token-alias rétrocompatible** : un ancien token `--color-rad-*` qui devient une référence vers la nouvelle couche, sans changer son comportement vu de l'extérieur.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001** : **Aucune régression visuelle** sur l'ensemble des écrans existants — validation via diff visuel automatisé entre captures d'écran avant/après sur 3 écrans représentatifs minimum (login élève, classroom teacher index, drawer Tibo). Tolérance acceptée : ≤ 1 % de pixels altérés ET différence colorimétrique ≤ ΔE 2 par pixel (standard industrie pour absorber le bruit sub-pixel/anti-aliasing). Outil CLI léger (ex: `imagemagick compare -metric AE` ou équivalent). Au-delà de ces seuils sur n'importe lequel des 3 écrans : régression à investiguer.
- **SC-002** : **100 % des tests CI continuent de passer** sur la PR B1 (modulo flakes Selenium connues, à documenter explicitement dans la PR).
- **SC-003** : **Tokens sémantiques fonctionnels et adaptatifs** : un nouveau composant créé après B1 qui consomme `var(--color-accent-primary)` rend en teal sous layout teacher et en balisier red sous layout student, sans ligne de code conditionnelle. Vérifiable via DEUX livrables complémentaires : (a) spec RSpec automatisé exécuté en CI qui rend une vue fixture avec chaque `data-audience` et vérifie via Capybara `evaluate_script` que la couleur résolue correspond à la primitive attendue ; (b) page démo persistante `/teacher/design-system/preview` (route sous auth teacher) listant les 19 tokens sémantiques en variantes light/dark × audience, servant de docs vivante pour les phases B2-B7.
- **SC-004** : **Bridge rétrocompatible** : aucune vue, aucun composant, aucun helper n'a été modifié dans la PR en dehors des 3 layouts et des artefacts liés à la page démo SC-003. Vérifiable via `git diff` — seuls les fichiers suivants doivent apparaître :
  - `app/assets/tailwind/application.css` (tokens primitives + sémantiques + mappings + bridge aliases)
  - `app/views/layouts/student.html.erb`, `teacher.html.erb`, `application.html.erb` (ajout `data-audience`)
  - `app/views/teacher/design_system/preview.html.erb` + `app/controllers/teacher/design_system_controller.rb` + entrée routes (page démo)
  - `spec/` (specs nouveaux pour FR-014, FR-015, SC-003)
- **SC-005** : **Indépendance pour les phases futures** : après B1, les phases B0, B2, B3, B4, B5, B6, B7 peuvent toutes commencer en parallèle sans dépendance entre elles (sauf B3 qui dépend de B2, et B6 qui dépend de B2). Vérifiable par lecture du plan et par l'auteur.
- **SC-006** : **Dark mode teacher fonctionnel** : la bascule clair/sombre sur une page teacher (via `ThemeToggleComponent` ou `prefers-color-scheme`) applique les bons tokens teacher-dark. Vérifiable manuellement sur une page teacher en dark mode.
- **SC-007** : **CSS compilé propre** : aucun warning ou erreur Tailwind lors de la compilation des assets (`bin/rails tailwindcss:build` ou équivalent). Le poids du CSS compilé n'augmente pas de plus de **10 % en brut** ET pas de plus de **5 % après gzip**, par rapport à avant B1. Mesures à reporter dans la PR (avant/après, brut + gzipped).

## Assumptions

- L'utilisateur a déjà tranché les 2 questions critiques de la synthèse (Q1 : dark mode teacher activé ; Q2 : 2 layouts conservés + `data-audience` ajouté). Ces décisions sont actées et ne sont pas re-questionnées dans cette spec.
- Les vues élève existantes consomment majoritairement les tokens `--color-rad-*` via classes Tailwind (`bg-rad-red`, `text-rad-muted`, etc.) — le bridge devra donc préserver ces classes utilitaires générées par `@theme`.
- Le mécanisme de bascule dark/light actuel (script inline dans `<head>` lisant `localStorage` et `prefers-color-scheme`, puis togglant `.dark` sur `<html>`) reste fonctionnel sans modification. La présence simultanée de `.dark` sur `<html>` et `data-audience` sur `<body>` est compatible.
- Les pages publiques (home, legal, privacy) ne sont **pas** un public prioritaire de cette feature ; elles doivent juste rester non régressées. Leur reskin éventuel est hors scope (potentiellement post-B5 ou jamais).
- La machine de développement étant trop lente pour Selenium, la validation visuelle pixel-perfect sera faite par l'utilisateur en local ou via screenshots manuels. La CI valide la non-régression fonctionnelle (specs verts).
- Tailwind CSS v4 supporte les sélecteurs d'attribut dans `@theme` (à confirmer dans le plan). Si non, un workaround via `@layer base` sera utilisé.
- Aucune migration de schéma de base de données, aucun changement de modèle, aucun nouveau service Rails. C'est uniquement du CSS et 2 lignes ERB.
- La feature est **non-fonctionnelle visible** pour l'utilisateur final : c'est une refacto interne. Aucune annonce produit, aucun changelog utilisateur nécessaire.

## Dependencies

- **Dépend de** : aucune feature antérieure spécifiquement ; le repo doit être à `main` propre (PR #97, #98, #101 mergées — état au 2026-05-17).
- **Débloque** : B0 (audit P0 — fixes a11y/légal, peut consommer les nouveaux tokens si déjà disponibles), B2 (refonte composants atomiques — utilise massivement les tokens sémantiques), B3, B4, B5, B6, B7.

## Out of Scope

Cette feature n'inclut explicitement PAS :
- Refonte de ViewComponent (Button, Badge, Card, NavBar, BottomBar, Modal, Flash, ProgressBar, etc.) → **B2/B3**.
- Création de nouveaux composants (StripesComponent, FieldComponent) → **B2**.
- Adoption des nouveaux tokens dans les vues élève (suppression des CTA ad-hoc, etc.) → **B4**.
- Reskin de l'espace teacher (`data-audience="teacher"` ne change rien tant que les vues teacher utilisent encore `bg-slate-*`/`text-indigo-*` en dur — c'est **B5**).
- Migration des 123 magic numbers `[XXpx]` → **B6**.
- Fixes audit P0 (mentions légales, touch targets, contraste, tutor_activated.erb) → **B0**.
- Refacto en layout unique (Option B de la synthèse §3.3) → reportée post-B5 ou jamais.
- Tests visuels automatisés (Percy, Chromatic, etc.) → hors scope, validation manuelle suffit.

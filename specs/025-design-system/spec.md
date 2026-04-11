# 025 — Design System & Pages Élève

## Contexte

MVP feature-complete (73 feature specs green). L'app fonctionne mais n'a pas de design system cohérent — styles inline Tailwind, pas de tokens, composants ViewComponent sous-utilisés. Ce spec définit le design system complet et le redesign des pages élève + home page.

## Périmètre

- Design system (tokens, composants, dark mode)
- Redesign de toutes les pages élève
- Home page publique
- Même niveau de polish partout
- Accessibilité WCAG AA

**Hors périmètre** :
- Pages enseignant (spec 027 dédiée avec brainstorming séparé)
- Loading states / spinners (feature séparée)
- `aria-describedby` pour erreurs de formulaire : aucune UI d'erreur de validation visible aujourd'hui (Devise utilise les templates par défaut, settings élève redirige avec un flash global, login affiche un flash). Un helper Rails réutilisable sera créé au moment où un formulaire affichera des erreurs par champ.

## Audit préalable — constats clés

### Forces existantes
- Tailwind CSS 4 installé avec dark mode fonctionnel (toggle + localStorage + préférence système)
- 7 ViewComponents (Button, Badge, Card, NavBar, Flash, ProgressBar, ThemeToggle, Modal)
- Palette cohérente : slate/indigo/emerald/amber
- 8 Stimulus controllers propres
- Responsive mobile : hamburger, sidebar drawer, breakpoints

### Problèmes identifiés
- Pas de layout étudiant dédié — NavBar dupliqué dans chaque vue
- ViewComponents sous-utilisés — beaucoup de Tailwind brut pour les boutons
- Pas de design tokens / CSS variables centralisés
- BadgeComponent identique light/dark — illisible en mode clair
- Modal incomplet (pas de focus trap, Escape, close)
- Pas de loading states / spinners (hors scope 025 — feature séparée)
- Pas de police custom
- `text-[13px]` non standard utilisé fréquemment
- 8 échecs WCAG AA (voir section Accessibilité)

---

## Décisions design validées

### Direction visuelle

| Décision | Choix | Détail |
|---|---|---|
| Direction | Moderne & Vibrant | Gradients indigo→violet, glassmorphism, énergie jeune |
| Police | Plus Jakarta Sans | Google Fonts, weights 400/500/600/700 |
| Palette | Existante enrichie | slate (neutres), indigo (primaire), emerald (succès), amber (warning) + gradients indigo→violet |
| Arrondis | Généreux | `rounded-xl` (16px) cartes/conteneurs, `rounded-full` badges/pills, `rounded-lg` (12px) boutons/inputs |
| Espacement | Aéré | gap-4 à gap-6 entre éléments, padding généreux |
| Dark mode | Vibrant | Fond slate-900, bordures teintées indigo, glow subtil sur éléments interactifs, logo en gradient |
| Light mode | Clean & lumineux | Fond slate-50/white, ombres légères, gradients sur les CTA |

---

## Home page publique

### Above the fold — mix A+C centré
- **Nav** : logo gradient à gauche, theme toggle seul à droite
- **Titre hero centré** : "Prépare ton BAC" avec "BAC" en gradient indigo→violet
- **Tagline** : "Entraîne-toi sur des sujets réels avec un tuteur IA qui te guide pas à pas."
- **Carte unifiée centrée** avec les deux accès :
  - **Élève** (proéminent) : label "ÉLÈVE" en indigo, champ code classe + bouton "Go !" en gradient
  - **Enseignant** (en dessous, sobre) : séparateur, label "ENSEIGNANT", bouton outline "Connexion enseignant →"
- **Glow radial** subtil en arrière-plan
- **Scroll hint** : "↓ Découvrir l'app"

### Below the fold — features puis workflow
1. **Section features** : 3 features clés en grille (icônes + titres + descriptions)
2. **Section workflow** : étapes "1. L'enseignant crée → 2. L'élève s'entraîne → 3. Le tuteur guide"

---

## Pages élève

### Login (`sessions/new`)
- Même ambiance que la home : fond dark gradient, carte centrée avec formulaire, logo en haut
- Continuité visuelle après saisie du code d'accès

### Subjects index (grille de sujets)
- **Header personnalisé** : "Salut [prénom] 👋" (prénom en gradient indigo→violet) pour l'accueil chaleureux
- **Cartes sujets** avec style vibrant : bordures glow indigo en dark, gradient subtil sur hover, arrondis xl
- **Progress bar par sujet** sur chaque carte (existante, restylée, variante gradient)
- Pas de progress bar globale (redondant avec peu de sujets)

### Subject show (présentation + parties)
- Application directe du design system (arrondis xl, glow dark, gradient boutons)
- Badges corrigés (light/dark distinct)
- Breadcrumb compact en haut
- Cartes parties avec hover glow
- **Page "Bravo" (completion)** : festive — grand titre en gradient, confettis/animation subtile, résumé progression, bouton retour

### Page question élève — layout

#### Mobile
- **Bottom bar fixe** : navigation prev + Tutorat + navigation next. Le bouton "next" est contextuel :
  - Question suivante (si disponible dans la partie courante)
  - "Partie suivante →" (si dernière question d'une partie intermédiaire dans sa section)
  - "Fin partie →" (si dernière question de la dernière partie d'une section — PATCH `complete_part`)
- **Correction** : blocs empilés (mobile-first). Correction → Explication → Data hints → Concepts → Documents.
- **Chat tutorat** : plein écran avec header contextuel rappelant la question (numéro + points + énoncé tronqué).

#### Desktop
- **Sidebar gauche** (existante, toujours visible) : documents, contexte (présentations), navigation parts/questions
- **Bouton Tutorat agrandi** dans la barre de progression (gradient + icône + glow)
- **Navigation prev/next** en bas du contenu, avec même logique contextuelle que mobile :
  - "Question suivante →" (dans la partie)
  - "Partie suivante →" (intermédiaire — lien vers première question de la partie suivante de la même section)
  - "Fin de la partie commune" / "Fin de la partie spécifique" (terminal — PATCH `complete_part`)
- **Chat tutorat** : drawer latéral droit 400px (existant, inchangé)

#### Header de la carte question
- Numéro de question à gauche (ex : "Question 1.2")
- **Badges DT/DR** à droite : tags `dt_references` (bleu) + `dr_references` (ambre), référençant les documents nécessaires à la question. Ex : Q2.1 `[DT2]`, Q.C1 `[DTS4] [DRS4]`. Les points (ex "2 pts") ne sont **pas** affichés — ils dupliquent ce qui est visible dans la liste des parties et ne sont pas actionables pour l'élève.

#### Commun mobile/desktop
- **Breadcrumb compact** : `Sujet › Partie 2 › Q2.3` — cliquable, retour facile
- **Présentations dans la sidebar** : section "CONTEXTE" dédiée (entre "DOCUMENTS" et les parties), avec liens vers "Présentation commune" et "Présentation spécifique". Accessibles à tout moment via clic.
  - Note : la spec initiale prévoyait les présentations inline avec les parties (commune avant Partie 1, spécifique avant Partie A). L'implémentation les a extraites dans une section séparée pour améliorer la lisibilité quand les parties elles-mêmes sont groupées par headers "PARTIE COMMUNE" / "PARTIE SPÉCIFIQUE".
- **Sidebar parts groupées par section** : headers "PARTIE COMMUNE" et "PARTIE SPÉCIFIQUE" uniquement quand les deux types coexistent (mono-type reste flat).

### Comportement "Fin de partie" (contrôleur `complete_part`)

Quand l'élève clique "Fin de la partie commune" ou "Fin de la partie spécifique" (dernière partie d'une section) :
1. Marque la partie comme complétée (`mark_part_completed!`)
2. Route selon l'état :
   - **Toutes les parties sont terminées** → redirige vers `subject#show` qui affiche soit la review des questions non répondues soit la page Bravo
   - **L'autre section a une question non répondue + présentation existe** → redirige vers la page de présentation de l'autre section (actuellement : `specific_presentation` uniquement — le common presentation est la mise en situation de `subject#show`)
   - **L'autre section a une question non répondue sans présentation** → redirige directement vers la première question non répondue
   - **L'autre section vide** (scope restreint) → fallback vers `subject#show` (review / completion / mise en situation selon contexte)

### Settings (mode, spécialité, API)
- Application directe du design system sur la structure existante (3 sections cartes)
- Cartes sections avec bordures glow en dark, arrondis xl
- Radio buttons mode : état sélectionné en gradient indigo
- Boutons avec style vibrant
- Breadcrumb compact

---

## Accessibilité — corrections WCAG AA requises

1. Ajouter `lang="fr"` sur `<html>` (3.1.1, Level A)
2. Ajouter skip navigation link sur tous les layouts (2.4.1, Level A)
3. Implémenter focus trap dans sidebar, chat drawer, modal (2.4.3)
4. Ajouter label accessible sur l'input chat (4.1.2, Level A)
5. Ajouter `aria-live` pour flash messages (`aria-live="polite"` sur les 3 layouts) et chat streaming (`aria-live="polite"` sur `streaming` target, `role="alert"` sur `error` target) (4.1.3, Level A). Note : le container `messages` du chat n'a volontairement pas `aria-live` — sinon chaque token streamé ré-annoncerait tout l'historique.
6. Ajouter `aria-expanded` sur les toggles (sidebar, chat, data-hints) — l'attribut est synchronisé par Stimulus via `updateToggles(isOpen)` (4.1.2, Level A)
7. Corriger contrastes : `text-slate-400` → `text-slate-600` sur fond clair (1.4.3, Level AA) — slate-600 (#475569) = ~7:1 sur white, marge confortable
8. ~~Ajouter `aria-describedby` pour les erreurs de formulaire (3.3.1, Level A)~~ — **Retiré du scope 025** : aucun formulaire du périmètre n'affiche d'erreurs par champ aujourd'hui (voir "Hors périmètre" en haut).
9. Ajouter `prefers-reduced-motion` : reset CSS global des transitions/glow + guard JS sur canvas-confetti (WCAG 2.3.3, best practice AA)

---

## Composants à créer / corriger

### À corriger
- **BadgeComponent** : styles light/dark distincts (actuellement identiques → illisible en light)
- **ModalComponent** : ajouter focus trap, Escape key, close button, aria-labelledby
- **ButtonComponent** : `:primary` devient le variant gradient vibrant (indigo→violet + glow). `:gradient` est conservé comme alias pour rétrocompatibilité. Règle : `:primary` est l'identité CTA de tout le projet ; les pages enseignant (spec 027) hériteront automatiquement du vibrant.

### À créer
- **BreadcrumbComponent** : `Sujet › Partie › Question`, cliquable. Responsive : version mobile "← Parent" / version desktop full chemin. `<nav aria-label="Fil d'Ariane">` + `aria-current="page"` sur le dernier item.
- **BottomBarComponent** : barre fixe mobile (prev/next + tutorat). Note : dans la page question élève, la bottom bar est implémentée inline plutôt que via le composant, car le comportement contextuel (next question / Partie suivante / Fin partie) nécessite du contexte spécifique. Le composant reste disponible pour les autres usages mobiles.
- **ConfettiComponent** : animation pour la page Bravo (Stimulus controller avec guard `prefers-reduced-motion`)
- **Student layout** (`layouts/student.html.erb`) : layout dédié avec NavBar intégré (supprime la duplication). Exclusion : `Student::SessionsController` garde `application` layout (non authentifié).
- **Focus trap controller** (`focus_trap_controller.js`) : Stimulus réutilisable, trap Tab/Shift+Tab, dispatch `focus-trap:close` sur Escape.

### À enrichir
- **NavBarComponent** : support slot breadcrumb, brand en gradient text, theme toggle toujours visible
- **CardComponent** : variante `:glow` (bordure indigo + box-shadow en dark)
- **ProgressBarComponent** : variante de couleur `:gradient` (indigo→violet)

### Design tokens Tailwind CSS 4 (`@theme`)
- `--font-sans` : Plus Jakarta Sans (remplace le token `--font-family-sans` de la spec initiale, pour coller à la convention Tailwind v4 qui génère automatiquement la utility `font-sans`)
- Gradients : `--color-primary-gradient-from`, `--color-primary-gradient-to`
- Glow shadows : `--shadow-glow-indigo`, `--shadow-glow-indigo-sm`, `--shadow-glow-emerald`
- Arrondis : `--radius-card` (16px), `--radius-button` (12px), `--radius-input` (12px), `--radius-pill` (9999px)
- Z-index (drawers doivent être au-dessus de leurs backdrops) : `--z-bottom-bar: 30` < `--z-backdrop: 40` < `--z-sidebar: 50` / `--z-chat-drawer: 50` < `--z-modal: 60`
- Transitions : `--transition-fast` (150ms), `--transition-normal` (300ms)
- Self-hosted font : `app/assets/fonts/plus-jakarta-sans.css` avec woff2 latin + latin-ext (subsets français), `font-display: swap`

---

## Bug fixes workflow inclus dans la PR 025

Plusieurs bugs pré-existants ou introduits par le design ont été corrigés sur cette même branche car ils bloquaient le testing utilisateur du nouveau design. Ces fixes ne relèvent pas stricto sensu du design system mais font partie du même delta :

1. **`TypeError` sur `subjects/index.html.erb:22`** (pré-existant, non lié au design) — `progression.count { v["answered"] }` échouait sur les progressions contenant des valeurs non-Hash (`parts_completed`, `completed_at`, ajoutées par le workflow 021). Fix : utiliser `session_record.answered_count` qui guarde avec `is_a?(Hash)`.
2. **Z-index scale backdrop > drawer** (régression introduite par 025) — les drawers étaient sous leur propre backdrop, bloquant tous les clics mobile. Fix : réordonner le scale (`--z-sidebar: 50 > --z-backdrop: 40`).
3. **`params[:part_id]` ignoré dans `subject#show` step 5** (pré-existant) — cliquer une partie dans la sidebar renvoyait à la mise en situation. Fix : bypass step 5 quand `params[:part_id]` est présent.
4. **`params[:start]` ignoré quand `first_visit=true`** (pré-existant) — le bouton "Commencer" après mise en situation ne navigait pas. Fix : variable `explicit_navigation` qui bypass step 5 quand `part_id` ou `start` sont présents.
5. **Part lookup via `@subject.parts.kept`** — `Part` n'inclut pas `Discard::Model` et les common parts appartiennent à `exam_session` pas à `subject`. Fix : utiliser `Part.find_by(id:)` directement.
6. **Navigation de fin de partie** (nouvelle feature demandée en cours) — "Partie suivante" (intermédiaire) vs "Fin de la partie commune/spécifique" (terminal) avec routage intelligent vers l'autre section. Documenté dans la section "Comportement Fin de partie" ci-dessus.

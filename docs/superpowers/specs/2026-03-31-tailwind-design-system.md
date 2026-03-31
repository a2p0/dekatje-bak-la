# Design System — Tailwind CSS + ViewComponent

## Résumé

Migration du design existant (100% inline styles, dark theme) vers Tailwind CSS 4 + ViewComponent. Palette Indigo/Emerald, style card-based structuré avec boutons pill marqués. Dark mode par défaut, light mode disponible. Migration incrémentale page par page.

## Périmètre

Design complet : page d'accueil publique + espace élève + espace enseignant.

## Stack technique

- **Tailwind CSS 4** via `tailwindcss-rails` gem (Propshaft compatible)
- **ViewComponent** gem — composants Ruby dans `app/components/`
- **Stimulus controller `theme`** — gestion dark/light mode

## Palette de couleurs

| Rôle | Couleur Tailwind | Hex référence | Usage |
|---|---|---|---|
| Primary | `indigo` | #6366f1 | Actions principales, liens, accents, question courante |
| Success | `emerald` | #10b981 | Correction, validation, "commencer", navigation suivante |
| Warning | `amber` | #f59e0b | Data hints, badges DR, alertes |
| Danger | `rose` | #f43f5e | Suppression, erreurs |
| Base | `slate` | — | Backgrounds, texte, bordures |
| Info | `blue` | #3b82f6 | Badges DT, liens documents |

### Mapping dark/light

| Élément | Dark | Light |
|---|---|---|
| Page background | `slate-950` (#0f172a) | `slate-50` (#f8fafc) |
| Card background | `slate-800` (#1e293b) | `white` |
| Card border | `slate-700` (#334155) | `slate-200` (#e2e8f0) |
| Card shadow | aucune | `shadow-sm` |
| Titre principal | `slate-200` (#e2e8f0) | `slate-800` (#1e293b) |
| Texte secondaire | `slate-400` (#94a3b8) | `slate-400` (#94a3b8) |
| Texte muted | `slate-500` (#64748b) | `slate-500` (#64748b) |
| Séparateurs | `slate-800` (#1e293b) | `slate-200` (#e2e8f0) |
| Badge fond | `{color}/10` (ex: `indigo-500/10`) | `{color}-50` (ex: `indigo-50`) |
| Badge texte | `{color}-300` (ex: `indigo-300`) | `{color}-600` (ex: `indigo-600`) |
| Boutons pill | fond `{color}-500`, texte `white` | idem (identique dans les deux modes) |

## Dark/Light mode

- Stratégie Tailwind : `darkMode: 'class'` — la classe `dark` sur `<html>` contrôle le mode
- **Stimulus controller `theme`** :
  - Au connect : lit `localStorage('theme')`, fallback sur `window.matchMedia('(prefers-color-scheme: dark)')`
  - Toggle : bascule la classe `dark`, persiste en `localStorage`
  - Écoute `matchMedia.change` pour suivre les changements OS quand aucun override n'est défini
- **ThemeToggleComponent** : bouton icône soleil/lune dans la navbar

## Composants ViewComponent

Tous dans `app/components/`, previews dans `test/components/previews/`.

### ButtonComponent

- **Variantes** : `primary` (indigo filled), `success` (emerald filled), `ghost` (bordure + transparent)
- **Tailles** : `sm`, `md`, `lg`
- **Options** : `pill: true` (border-radius full), `href` (rend un `<a>`)
- Exemples : "Continuer →" = `primary pill`, "Voir la correction" = `success pill`, "⚙ Réglages" = `ghost`

### BadgeComponent

- **Couleurs** : `indigo` (spécialité), `emerald` (année), `amber` (région/DR), `blue` (DT), `slate` (draft), `rose` (danger)
- **Paramètres** : `color`, `label`
- Taille fixe, texte petit (text-xs), padding compact

### CardComponent

- **Slots** : `header`, `body`, `footer` (optionnel, avec séparateur `border-t`)
- Dark : `bg-slate-800 border border-slate-700 rounded-lg`
- Light : `bg-white border border-slate-200 rounded-lg shadow-sm`

### ProgressBarComponent

- **Paramètres** : `current`, `total`, `color` (default `indigo`)
- Affiche la barre remplie + texte optionnel "7/18 — 39%"

### NavBarComponent

- **Slots** : `brand`, `links`, `actions`
- Desktop : liens visibles, actions à droite
- Mobile : hamburger menu
- Inclut le ThemeToggleComponent dans `actions`

### ThemeToggleComponent

- Bouton icône soleil (light) / lune (dark)
- Piloté par Stimulus controller `theme`

### ModalComponent

- **Slots** : `body`
- **Paramètres** : `title`, `confirm_text`, `cancel_text`
- Backdrop overlay, centré, fermeture Escape/click-outside

## Pages — Design détaillé

### Page d'accueil publique

Écran de connexion minimal, une seule fold, centré verticalement :

- Logo/titre "DekatjeBakLa" + sous-titre "Entraînement aux examens BAC"
- Section élève : champ "Code de la classe" + bouton "Accéder" (emerald pill) → redirige vers `/{access_code}`
- Divider horizontal
- Section enseignant : lien discret "Espace enseignant →" vers `/teacher/sign_in`
- Footer léger : "DekatjeBakLa — Martinique"
- Theme toggle dans un coin

### Espace élève — Login

- Centré verticalement
- Titre : nom de la classe
- Champs : username + mot de passe
- Bouton "Se connecter" (indigo pill)
- Lien retour home

### Espace élève — Dashboard sujets

- NavBar : "DekatjeBakLa" | theme toggle | "Réglages" | "Déconnexion"
- Titre "Mes sujets" + compteur
- Grille responsive CardComponent (2 col desktop, 1 col mobile) :
  - Header : badges (spécialité, année, région)
  - Body : titre sujet, sous-titre, ProgressBarComponent
  - Footer : bouton pill "Continuer →" (indigo) ou "Commencer →" (emerald)
- État vide : message centré

### Espace élève — Écran question (desktop)

- **Sidebar fixe** (260px, visible `lg:`) :
  - Mise en situation (titre sujet + résumé)
  - Objectif de la partie courante
  - Liste questions de la partie (✓ answered, ◉ current, ○ pending)
  - Autres parties avec progression
  - Documents DT (badge bleu) / DR (badge amber) avec liens
- **Main** :
  - Top bar : partie + numéro question + ProgressBarComponent + bouton "Tutorat" (indigo pill)
  - CardComponent question : numéro, énoncé, contexte (blockquote avec barre latérale)
  - Refs documents : chips cliquables "DT1 ↗", "Mise en situation ↗"
  - Bouton "Voir la correction" (emerald pill, centré)
  - Correction révélée : bordure gauche emerald + fond teinté, texte correction
  - Data hints : CardComponent avec badges amber source + texte location
  - Concepts clés : badges pill indigo
  - Navigation bas : "← Q précédente" + "Question suivante →" (emerald pill)

### Espace élève — Écran question (mobile < lg)

- Hamburger + progress bar en top
- Banner contextuelle compacte : partie + sujet + bouton "▾ Contexte" (ouvre le drawer sidebar)
- Même contenu question compacté
- **Bottom bar fixe** : nav prev + "Tutorat" (indigo pill) + "Suiv. →" (emerald pill)

### Espace élève — Settings

- NavBar + lien retour "← Mes sujets"
- Container centré (max-w-xl)
- Bloc "Mode par défaut" : radio buttons stylisés en cards sélectionnables (bordure indigo quand sélectionné)
- Bloc "Configuration IA" : CardComponent avec selects (fournisseur, modèle), input clé API (password + toggle), bouton "Tester" (ghost), bouton "Enregistrer" (indigo pill)

### Espace élève — Chat tutorat

- **Desktop** : drawer 400px depuis la droite, overlay backdrop
- **Mobile** : drawer pleine largeur
- Header : "Tutorat IA" + badge question + bouton fermer
- Messages : bulles gauche (IA, fond slate-800) / droite (élève, fond indigo teinté)
- Streaming : indicateur "..." animé
- Input fixé en bas + bouton envoi (indigo pill)
- Sans clé API : message avec lien Réglages

### Espace enseignant — Layout

- **Top nav** constante : "DekatjeBakLa" | "Mes classes" | "Mes sujets" | theme toggle | "Déconnexion"
- Pas de sidebar

### Espace enseignant — Mes classes (index)

- Grille CardComponent : nom, année scolaire, spécialité, nb élèves, nb sujets
- Bouton "Nouvelle classe" (indigo pill)

### Espace enseignant — Classe (show)

- En-tête : titre + badges (spécialité, année) + code d'accès
- Section élèves : tableau (nom, username, actions reset mdp/supprimer)
- Boutons : "Ajouter un élève" + "Ajout en lot" (ghost) + "Exporter fiches PDF" (ghost)
- Section sujets assignés

### Espace enseignant — Mes sujets (index)

- Tableau : titre, spécialité, année, statut (badge), date, nb questions
- Badges statut : draft (slate), pending_validation (amber), published (emerald), archived (slate ghost)
- Bouton "Nouveau sujet" (indigo pill)

### Espace enseignant — Sujet (show)

- En-tête : titre + badges + boutons actions (publier/dépublier, assigner)
- Section fichiers DT/DR
- Section extraction : statut ExtractionJob + retry
- Parties en accordéon, questions en sous-liste avec numéro, label tronqué, points, badge statut, boutons éditer/valider/supprimer

### Espace enseignant — Question (édition inline)

- Formulaire CardComponent : label, points, type réponse, correction, explication
- Boutons "Enregistrer" (indigo) + "Annuler" (ghost)

### Espace enseignant — Nouveau sujet (form)

- CardComponent centré : titre, spécialité, année, type exam
- Uploads fichiers PDF
- Bouton "Créer et lancer l'extraction" (indigo pill)

## Responsive

| Breakpoint | Valeur | Comportement |
|---|---|---|
| `sm` | 640px | Mobile landscape |
| `md` | 768px | Tablette |
| `lg` | 1024px | Desktop — sidebar élève fixe |

- Dashboard grilles : 2 col → 1 col sous `md`
- Tableaux enseignant : scroll horizontal mobile
- Sidebar question : fixe `lg:`, drawer `< lg`
- Bottom bar mobile : visible `< lg`, masquée au-dessus
- Hamburger : visible `< lg`, masqué au-dessus

## Accessibilité

- Contraste WCAG AA sur toutes les combinaisons texte/fond
- `aria-label` sur boutons icônes (hamburger, fermer, toggle theme)
- Focus visible : `focus-visible:ring-2 ring-indigo-500`
- HTML sémantique : `<nav>`, `<main>`, `<aside>`, `<button>`

## Approche de migration

Migration incrémentale (approche B) :

1. **Fondation** : installer Tailwind CSS 4 + ViewComponent, configurer thème custom
2. **Composants** : créer ButtonComponent, BadgeComponent, CardComponent, ProgressBarComponent, NavBarComponent, ThemeToggleComponent, ModalComponent
3. **Migration page par page** :
   - Home (login public)
   - Student : login → dashboard → question show → settings
   - Teacher : layout/nav → classrooms → subjects → parts/questions → students
4. Chaque page = un commit testable, l'inline cohabite temporairement

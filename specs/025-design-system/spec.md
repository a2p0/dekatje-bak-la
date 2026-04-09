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
- **Header personnalisé** : "Salut [prénom]" pour l'accueil chaleureux
- **Cartes sujets** avec style vibrant : bordures glow indigo en dark, gradient subtil sur hover, arrondis xl
- **Progress bar par sujet** sur chaque carte (existante, restylée)
- Pas de progress bar globale (redondant avec peu de sujets)

### Subject show (présentation + parties)
- Application directe du design system (arrondis xl, glow dark, gradient boutons)
- Badges corrigés (light/dark distinct)
- Breadcrumb compact en haut
- Cartes parties avec hover glow
- **Page "Bravo" (completion)** : festive — grand titre en gradient, confettis/animation subtile, résumé progression, bouton retour

### Page question élève — layout

#### Mobile
- **Bottom bar fixe** : prev/next + bouton Tutorat (gradient + icône). Toujours visible.
- **Correction** : blocs empilés (mobile-first). Correction → Explication → Data hints → Concepts → Documents.
- **Chat tutorat** : plein écran avec header contextuel rappelant la question (numéro + énoncé tronqué + lien "Voir").

#### Desktop
- **Sidebar gauche** (existante, toujours visible) : documents, présentations, navigation questions
- **Bouton Tutorat agrandi** dans la barre de progression (gradient + icône + glow)
- **Navigation prev/next** en bas du contenu (comme actuellement)
- **Chat tutorat** : drawer latéral droit 400px (existant, inchangé)

#### Commun mobile/desktop
- **Breadcrumb compact** : `Sujet › Partie 2 › Q2.3` — cliquable, retour facile
- **Présentations dans la sidebar** :
  - "Présentation commune" insérée avant la Partie 1
  - "Présentation spécifique" insérée avant la Partie A (première partie spécifique)
  - Accessibles à tout moment via clic dans la sidebar/drawer

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
5. Ajouter `aria-live` pour flash messages, streaming chat, erreurs (4.1.3, Level A)
6. Ajouter `aria-expanded` sur tous les toggles (4.1.2, Level A)
7. Corriger contrastes : `text-slate-400` → `text-slate-600` sur fond clair (1.4.3, Level AA) — slate-600 (#475569) = ~7:1 sur white, marge confortable
8. Ajouter `aria-describedby` pour les erreurs de formulaire (3.3.1, Level A)

---

## Composants à créer / corriger

### À corriger
- **BadgeComponent** : styles light/dark distincts (actuellement identiques → illisible en light)
- **ModalComponent** : ajouter focus trap, Escape key, close button, aria-labelledby
- **ButtonComponent** : ajouter variant gradient (primaire vibrant avec glow)

### À créer
- **BreadcrumbComponent** : `Sujet › Partie › Question`, cliquable
- **BottomBarComponent** : barre fixe mobile (prev/next + tutorat)
- **ConfettiComponent** : animation pour la page Bravo (Stimulus controller)
- **Student layout** : layout dédié avec NavBar intégré (supprime la duplication)

### À enrichir
- **NavBarComponent** : support breadcrumb, theme toggle toujours visible
- **CardComponent** : variante glow (bordure indigo + box-shadow en dark)
- **ProgressBarComponent** : variante gradient

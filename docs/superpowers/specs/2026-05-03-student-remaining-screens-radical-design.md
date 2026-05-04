# PR5 — Radical reskin : écrans élèves restants

**Date** : 2026-05-03
**Branche** : `057-student-remaining-screens-radical`
**Périmètre** : 3 vues élève non encore reskinées vers le design Radical

---

## Contexte

Les PR1–4 de la direction Radical ont reskinné le design system (tokens), le layout student, subjects/show, questions/show + correction, et le drawer tutorat. Il reste 3 écrans élève encore en slate/indigo :

- `app/views/student/sessions/new.html.erb` — login
- `app/views/student/subjects/index.html.erb` — liste des sujets
- `app/views/student/settings/show.html.erb` — réglages

**Approche retenue** : reskin pur token-by-token, composants Rails existants conservés (ButtonComponent, CardComponent, BadgeComponent, ProgressBarComponent, BreadcrumbComponent). Zéro changement fonctionnel, zéro migration.

**Référence design** : `tmp/Dekatje-handoff(1)/dekatje/project/directions/student-flows.jsx` et `subj-states-d.jsx`.

---

## Écran 1 — Login (`sessions/new`)

### Objectif
Premier écran vu par l'élève. Doit incarner l'identité Radical dès l'entrée.

### Changements
- Fond : `bg-rad-bg` (supprime le gradient `from-slate-50 to-white`)
- Suppression du radial glow indigo (`aria-hidden` div)
- Logo : 3 dots inline (rad-red / rad-yellow / rad-teal) + `font-serif italic` "DekatjeBakLa" (supprime gradient indigo `bg-clip-text`)
- Stripes 4 couleurs (`_stripes` partial) en haut de la card
- Card : `bg-rad-paper border-rad-rule rounded-2xl shadow-none` (supprime `backdrop-blur`, `dark:shadow-[...]`)
- Titre classe : `font-serif italic text-rad-text`
- Sous-titre : `text-rad-muted`
- Labels champs : `text-rad-muted uppercase tracking-wider text-[11px] font-bold`
- Inputs : `bg-rad-paper border-rad-rule rounded-xl focus:ring-2 focus:ring-rad-teal text-rad-text`
- Bouton submit : `bg-rad-red text-rad-cream font-bold rounded-[14px] w-full` (remplace `ButtonComponent variant: :gradient`)
- Lien "← Retour" : `text-rad-muted hover:text-rad-teal`

---

## Écran 2 — Liste des sujets (`subjects/index`)

### Objectif
Hub central de navigation élève. Grid de cards avec progression.

### Changements structure
- Wrapper : `bg-rad-bg min-h-screen`
- Stripes 4 couleurs en haut de page (render `_stripes` partial)
- Header 3 zones : `‹` retour (lien `student_root_path`), titre `font-serif italic` centré ("Mes sujets"), icône `≡` à droite (lien vers `student_settings_path`)
- Titre "Salut Prénom" : `font-serif text-2xl text-rad-text` (supprime gradient indigo + emoji 👋)
- Sous-titre : `text-rad-muted`

### Cards sujets
- CardComponent : passer variant `:flat` (ou surcharger classes) → `bg-rad-paper border border-rad-rule rounded-2xl`
- Badges : mapping couleurs
  - `:emerald` → `bg-rad-teal/10 text-rad-teal border-rad-teal/20`
  - `:indigo` → `bg-rad-red/10 text-rad-red border-rad-red/20`
  - `:amber` → `bg-rad-yellow/15 text-rad-ink border-rad-yellow/30`
  - `:slate` → `bg-rad-rule/40 text-rad-muted border-rad-rule`
- ProgressBarComponent : passer couleur `rad-teal` (ou `bg-rad-teal` override)
- Bouton "Commencer/Continuer" : `bg-rad-red text-rad-cream rounded-full font-bold`

### Empty state
- `bg-rad-paper border-rad-rule rounded-2xl` avec `text-rad-muted`

---

## Écran 3 — Réglages (`settings/show`)

### Objectif
Configuration API et mode par défaut. Design iOS-settings style du handoff.

### Suppressions
- **Champ spécialité** (section "Profil" entière retirée) — la spécialité est gérée par l'enseignant
- ~~Toggle "Utiliser ma clé personnelle"~~ — **conservé**

### Ajouts
- **Card profil** en haut de page : avatar rond `bg-rad-red text-rad-cream font-serif italic` (initiale prénom), nom complet + username + nom classe en `text-rad-muted`

### Changements structure
- Wrapper : `bg-rad-bg min-h-screen`
- Stripes 4 couleurs en haut
- Header : même pattern que subjects/index (`‹` + titre centré + `≡`)
- Suppression du `BreadcrumbComponent`

### Section "Mode par défaut"
- Remplacer les `radio_button` + borders indigo par un **toggle 2 boutons côte-à-côte** dans un container `rounded-xl border border-rad-rule overflow-hidden`
  - "Autonome" actif : `bg-rad-ink text-rad-cream`
  - "Tuteur IA" actif : `bg-rad-red text-rad-cream`
  - Inactif : `bg-rad-raise text-rad-muted`
- Les champs radio hidden restent dans le DOM pour la soumission du formulaire

### Section "Tuteur IA · Clé API"
- Titre section : `text-[10.5px] uppercase tracking-[0.16em] text-rad-muted font-bold`
- Bloc : `bg-rad-paper border-t border-b border-rad-rule`
- Rows provider/modèle : `border-b border-rad-rule px-5 py-[13px]`
- Selects : `bg-rad-raise border border-rad-rule rounded-lg text-rad-text`
- Input clé : `bg-rad-raise border-rad-rule rounded-xl font-mono focus:border-rad-teal`
- Bouton "Tester la clé" : `bg-rad-teal text-rad-cream rounded-full`
- Feedback : `text-rad-green` (✓) / `text-rad-red` (✗)
- Toggle "Utiliser ma clé personnelle" : conservé — `label` avec `accent-rad-teal`, texte `text-rad-text/text-rad-muted`
- Note mode gratuit : texte `text-rad-muted text-xs`

### Bouton save
- `bg-rad-red text-rad-cream w-full rounded-[14px] font-bold py-[14px]`

---

## Fichiers touchés

```
app/views/student/sessions/new.html.erb
app/views/student/subjects/index.html.erb
app/views/student/settings/show.html.erb
```

Aucune migration, aucun changement de modèle, aucun nouveau service.

---

## Tests

- Les specs Capybara existants doivent continuer à passer (pas de changement fonctionnel)
- Vérification manuelle : login → liste → réglages → enregistrer → retour liste
- Dark mode : vérifier les 3 écrans (tokens rad gèrent light/dark via CSS variables)

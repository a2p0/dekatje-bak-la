# Quickstart — Vérification manuelle 064-desktop-question-layout

**Branch** : `064-desktop-question-layout`
**Prérequis** : seeds dev OK (`bundle exec rails db:seed`), au moins 1 sujet publié avec parts, questions, DT attaché, et 1 élève actif.

## Setup

```bash
bundle install
bundle exec rails db:migrate  # aucune nouvelle migration, mais aligne le schema
bundle exec rails db:seed     # si nécessaire
bundle exec rails s
```

Démarrer Sidekiq dans un autre terminal (pour les conversations Tibo) :
```bash
bundle exec sidekiq
```

## US1 — Lecture question desktop

1. Login élève : `http://localhost:3000/<access_code>` puis identifiants.
2. Naviguer vers un sujet → première question.
3. **Vérifier sur viewport ≥1024px** :
   - [ ] Top navbar visible avec logo "DekatjeBakLa" en Fraunces italic, tabs (Mes sujets/Progression/Réglages), boutons Parties + Tibo, avatar.
   - [ ] Breadcrumb sous la navbar : Sujet › Partie X › Q1.2.
   - [ ] Layout split 50/50 : carte question à gauche, DT viewer à droite.
   - [ ] Bandeau références (badges DT1/DT2…) en haut du DT viewer si la question référence un DT.
   - [ ] Iframe PDF visible si `Subject.dt_file` attaché.
   - [ ] Si pas de DT : message "Aucun document technique pour cette question".
4. **Vérifier sur viewport <1024px** (resize fenêtre à 390×800 ou DevTools mobile mode) :
   - [ ] Navbar desktop cachée.
   - [ ] Layout mobile : sidebar masquée, question pleine largeur, DT en partial inline ou bouton "Voir DT".

## US2 — Correction desktop

1. Sur une question lecture, cliquer "Voir la correction".
2. **Vérifier sur viewport ≥1024px** :
   - [ ] Colonne gauche : carte verte (réponse), carte verte outlined (calcul), carte jaune outlined (data hints).
   - [ ] Colonne droite : iframe DT inchangée + bandeau "Donnée utile" en haut avec `source · location` du premier data hint.
3. **Sur viewport <1024px** :
   - [ ] Colonne unique, cartes correction empilées sous la question.

## US3 — Tutorat Tibo desktop

1. Question avec clé API élève active.
2. Cliquer le bouton "Tibo" dans la navbar.
3. **Vérifier sur viewport ≥1024px** :
   - [ ] Drawer s'ouvre depuis la droite, occupe ~60vw (max 900px).
   - [ ] Pane gauche du drawer : chat existant (header Tibo, messages, chips, input).
   - [ ] Pane droite du drawer (40%) : panneau contexte avec rappel question (label) + bloc partie (numéro + titre + objectif).
   - [ ] La colonne gauche question initiale reste visible derrière le drawer (drawer ne couvre que la colonne droite).
4. **Sur viewport <1024px** :
   - [ ] Drawer full-screen, pas de panneau contexte visible.
5. Fermer le drawer → la colonne DT redevient visible sans rechargement.

## US4 — Navigation Parties popover desktop

1. Cliquer "Parties" dans la navbar.
2. **Vérifier sur viewport ≥1024px** :
   - [ ] Sidebar apparaît depuis la gauche en overlay (avec backdrop éventuel).
   - [ ] Liste des parties et questions, états répondu/non visibles.
   - [ ] Cliquer une question → navigation + sidebar fermée.
3. **Sur viewport <1024px** :
   - [ ] Bouton "Parties" non visible (caché en `lg:`).
   - [ ] Le bouton `≡` du header de la question ouvre la même sidebar (comportement existant).

## SC-004 — Régression mobile

Lancer les specs existantes :
```bash
bundle exec rspec spec/features/student_question_navigation_spec.rb spec/features/student_correction_reveal_spec.rb spec/features/student_tutor_*.rb
```
- [ ] Toutes vertes.

## SC-005 — Nouveaux specs desktop

```bash
bundle exec rspec spec/features/student_desktop_*.rb
```
- [ ] 4 specs vertes (reading, correction, tutor, navigation).

## Single-overlay sanity check

1. Ouvrir Tibo.
2. Cliquer "Parties" → Tibo se ferme automatiquement, Parties s'ouvre.
3. Cliquer Tibo à nouveau → Parties se ferme, Tibo s'ouvre.
- [ ] Aucun état "deux overlays ouverts simultanément".

## Accessibilité clavier

1. Tab depuis le début de la page → navbar atteignable.
2. Activer le bouton "Parties" via Espace/Entrée → sidebar s'ouvre + focus sur premier élément focusable.
3. Échap → sidebar se ferme + focus retour au bouton.
4. Idem pour Tibo.
- [ ] Tous les overlays gèrent focus trap + restauration.

## Si tout est ✅

Le PR est prêt. Lancer la spec complète + lint :
```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
```

Puis ouvrir le PR avec le bilan SC-001 à SC-006 dans la description.

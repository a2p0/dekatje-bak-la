# questions/show — Radical design

**Date :** 2026-05-02
**Scope :** Reskin de `student/questions/show.html.erb` + `student/questions/_correction.html.erb`
**Branche cible :** 055-questions-show-radical → main via PR
**Dépendance :** PR #76 (subjects/show Radical) mergée sur main ✅

---

## Contexte

PR 3 de la série de 5 redesign Radical. Couvre l'écran de lecture d'une question et l'écran de correction. Les tokens Radical (`bg-rad-bg`, `text-rad-text`, `font-serif`, `font-mono`, `pattern-madras`, etc.) sont disponibles via PR #75.

Aucun controller Rails modifié. Aucune migration. Aucun nouveau Stimulus controller.
Le partial `_stripes` existe déjà (`app/views/student/subjects/_stripes.html.erb`) — réutilisé tel quel.

Le drawer tutorat (`conversations/_drawer`) est hors scope — PR4.
La sidebar (`_sidebar`, `_sidebar_part`) : reskin CSS uniquement, pas de restructuration.

---

## Fichiers touchés

| Action | Fichier |
|---|---|
| Modifier | `app/views/student/questions/show.html.erb` |
| Modifier | `app/views/student/questions/_correction.html.erb` |
| Modifier (CSS only) | `app/views/student/questions/_sidebar.html.erb` (sidebar desktop) |

---

## Décisions de design

| Question | Décision |
|---|---|
| Scope | B — lecture + correction uniquement, drawer en PR4 |
| Desktop layout | B — conserver sidebar, restyler en Radical (rad-paper/rad-rule) |
| Bouton Tibo | B — restyler inline (avatar T rouge + label "Tibo", fond rad-ink) |
| Mise en situation collapsible | B — toujours visible, restyler avec yellow accent bar |
| Bottom CTA | B — garder structure actuelle (correction mid-page + nav séparée), restyler |

---

## Design détaillé

### show.html.erb

#### Structure globale
- Wrapper `bg-rad-bg` — suppression de toutes les classes `dark:`
- Sidebar `<aside>` : `bg-rad-paper border-r border-rad-rule` (était `bg-slate-900 border-indigo-500/10`)
- `pb-20 lg:pb-0` conservé pour la mobile bottom bar

#### Stripes
- `<%= render "student/subjects/stripes" %>` inséré en dehors du wrapper flex, juste avant lui (comme en PR2 sur subjects/show)
- Dans le flux normal, pas en position absolue — hauteur 6px, pleine largeur

#### Header compact (remplace breadcrumb + barre progression)
Structure en 3 colonnes :
```
[← retour]   [BAC STI2D · SIN (muted uppercase) + titre serif italic]   [≡ hamburger]
```
- Colonne gauche : lien `← ` vers `student_subject_path` (retour au sujet), `text-rad-text`
- Colonne centre :
  - Label `text-[10.5px] tracking-[0.16em] uppercase text-rad-muted font-bold` : exam_type + specialty
  - Titre `font-serif italic text-[14px] text-rad-text leading-none` : `@subject.title`
- Colonne droite : bouton `≡` `data-action="click->sidebar#open"` (même action qu'actuellement), visible sur mobile uniquement (`lg:hidden`) — sur desktop la sidebar est toujours visible
- Suppression du `BreadcrumbComponent`

#### Barre de progression segmentée
Remplace `ProgressBarComponent`. Inline dans le header ou en ligne séparée sous le header :
- `total` segments de hauteur 4px, `border-radius: 2px`, gap 3px
- Segment `i < answered` : `bg-rad-teal`
- Segment `i === answered` (courant) : `bg-rad-red`
- Segments restants : `bg-rad-rule`
- Label `text-[11px] text-rad-muted font-semibold` : `#{idx+1} / #{total}`

#### Part header sticky
```
[PARTIE I · COMMUNE · 12 PTS]   ← uppercase muted 10.5px tracking-wide
[Titre de la partie en serif 18px]
```
- Fond `bg-rad-bg/95 backdrop-blur-sm`
- Border bottom `border-rad-rule`
- Suppression du `dark:` partout

#### Context card (mise en situation locale)
Visible si `@question.context_text.present?` :
- Fond `bg-rad-paper border border-rad-rule rounded-2xl`
- Header : accent bar jaune `w-1 h-[14px] bg-rad-yellow rounded-sm` + label uppercase muted "Mise en situation"
- Corps : `text-rad-muted text-[13px] leading-[1.55]`

#### Question card
- Fond `bg-rad-paper border border-rad-rule rounded-2xl shadow-sm`
- Colonne gauche (flex-shrink-0, w-14) :
  - Box numéro : `w-14 h-14 rounded-[14px] bg-rad-red` — chiffre en `font-serif text-[24px] text-rad-cream`
  - Badges DT/DR : fond `bg-rad-yellow text-rad-ink text-[11px] font-bold px-[10px] py-1 rounded-[6px] tracking-[0.04em]`
- Colonne droite : label `font-serif text-[19px] leading-[1.3] text-rad-text`
- Context_text sous le label si présent : `font-serif italic text-[13px] text-rad-muted`

#### Turbo frame correction — bouton "Voir la correction"
- Style : `border border-rad-text text-rad-text bg-transparent rounded-[14px] px-8 py-3 text-[13.5px] font-bold`
- Suppression du gradient indigo

#### Bouton Tibo (tutor_available)
Structure interne remplacée :
```html
<span class="w-6 h-6 rounded-full bg-rad-red text-rad-cream flex items-center justify-center font-serif italic text-[13px]">T</span>
Tibo
```
- Fond du bouton : `bg-rad-ink text-rad-cream`
- Shadow : `shadow-[0_8px_20px_-8px_rgba(0,0,0,0.35)]`
- `data-controller`, `data-action`, `aria-*` : inchangés

Lien "Activer le tuteur" (tutor indisponible) : `text-rad-muted border-rad-rule bg-rad-paper`

#### Nav desktop
- `← Qn` : `text-rad-teal text-sm`
- "Question suivante →" : `bg-rad-red text-rad-cream rounded-[14px] px-6 py-2.5 font-bold`
- "Fin de la partie" / `button_to` : même style `bg-rad-red`
- Border top : `border-rad-rule`

#### Mobile bottom bar
- Fond : `bg-rad-bg border-t border-rad-rule`
- Suppression `dark:` partout
- Lien prev : `text-rad-muted`
- Bouton Tibo : même reskin que desktop (fond `rad-ink`, avatar T)
- Lien next : `text-rad-red font-bold`

#### Sidebar `<aside>` (CSS only)
- `bg-rad-paper` (était `bg-slate-900`)
- `border-r border-rad-rule` (était `border-indigo-500/10`)
- Suppression `dark:` sur l'aside

---

### _correction.html.erb

#### Carte réponse (grande carte verte)
- Fond : `bg-rad-green rounded-[20px] p-[22px_22px_26px] relative overflow-hidden`
- Overlay madras : `<div class="pattern-madras absolute inset-0 opacity-[0.18]"></div>`
- Header : `✓ RÉPONSE` uppercase muted 10.5px tracking-wide opacity-90
- Texte correction : `font-serif text-[36px] text-rad-cream leading-none` si court (≤ 60 chars)
- Si long (> 60 chars) : `font-serif text-[20px] text-rad-cream leading-[1.4]`
- `correction_text` affiché dans cette carte (remplace `border-l-4 border-emerald-500`)

#### Détail / explication
- Fond : `bg-rad-paper border border-rad-rule rounded-[18px] overflow-hidden`
- Header : accent bar teal `w-1 bg-rad-teal` + avatar `=` vert + titre serif "Détail du calcul" (si `answer_type == "calculation"`) ou "Pourquoi" (sinon)
- Corps : `font-serif text-[17px] leading-[1.5] text-rad-text` pour explanation_text
- Si `answer_type == "calculation"` : corps en `font-mono text-[14px] leading-[1.7]`

#### Data hints
- Container : `bg-rad-paper border border-rad-rule rounded-[18px] overflow-hidden`
- Header : accent bar jaune + avatar `i` jaune + titre serif "Où trouver les données ?"
- Chaque hint : badge source `bg-rad-yellow text-rad-ink` (premier) ou `bg-rad-raise border-rad-rule` (suivants) + location `text-rad-muted text-[13px]` + value `font-mono text-[13px] font-medium`
- Séparateurs `border-t border-rad-rule`

#### Key concepts
- Fond : `bg-rad-paper border border-rad-rule rounded-[18px] p-[14px_18px]`
- Label section : uppercase muted 10.5px
- Pills : `font-serif italic text-[14px] border border-rad-rule bg-rad-paper text-rad-text rounded-full px-3 py-1`

#### Documents correction
- Reskin : fond `bg-rad-paper border border-rad-rule rounded-[18px]`
- Liens : `text-rad-teal`

#### Bouton "Expliquer la correction" (mode tutoré)
- `text-rad-teal underline` (était `text-indigo-500`)
- `data-action` inchangé

---

## Tests à écrire / mettre à jour

### Request specs (`spec/requests/student/questions_spec.rb`)
Les sélecteurs textuels existants ne changent pas (le texte des boutons comme "Voir la correction", "Question suivante" reste identique).
Vérifier que les specs existantes passent sans modification.

### Feature specs
Ajouter un bloc `describe "Radical UI — questions/show"` dans `spec/features/student/subject_workflow_spec.rb` :

1. **Stripes présentes** — `expect(page).to have_css(".stripes")` (ou la classe utilisée)
2. **Question card avec number box** — `expect(page).to have_css("[data-testid='question-number-box']")` si ajouté, sinon vérifier la classe
3. **Correction card verte** — après reveal, vérifier `have_css(".bg-rad-green")` ou équivalent
4. **Bouton Tibo restyled** — `expect(page).to have_content("Tibo")` (était "Tutorat")
5. **Nav desktop** — `expect(page).to have_link("Question suivante →")`

---

## Invariants à préserver

- `turbo_frame_tag "question_#{@question.id}_correction"` : structure et ID inchangés
- `data-controller="sidebar chat-drawer"` sur le wrapper : inchangé
- `data-controller="tutor-activator"` + `data-action="click->tutor-activator#activate"` : inchangés
- `data-chat-drawer-toggle="true"` sur les boutons Tibo : inchangé
- `student_subject_part_completion_path` dans `button_to` fin de partie : inchangé
- Tous les chemins de navigation (prev_href, next_href, end_of_part) : inchangés

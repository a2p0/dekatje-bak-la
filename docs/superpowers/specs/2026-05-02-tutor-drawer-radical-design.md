# Tutor Drawer — Radical Reskin (PR4)

## Scope

Reskin visuel du drawer tutorat (`conversations/_drawer.html.erb`, `conversations/_message.html.erb`, `conversations/_confidence_form.html.erb`) vers le design system Radical. Aucun changement de comportement, de logique Stimulus, ni de routes.

Fichiers non touchés : controllers Stimulus (`tutor-chat`, `confidence-form`), routes, modèles.

---

## Tokens Radical utilisés

Palette CSS vars déjà définie dans `app/assets/tailwind/application.css` :

| Token | Light | Dark |
|---|---|---|
| `rad-bg` | `#fbf7ee` | `#0f2f33` |
| `rad-paper` | `#ffffff` | `#143b40` |
| `rad-raise` | `#fdfaf3` | `#1a4a50` |
| `rad-text` | `#0e1b1f` | `#f5ecdc` |
| `rad-muted` | `#6b665a` | `#a8c2c5` |
| `rad-rule` | `#e6dcc1` | `#22585e` |
| `rad-red` | `#d4452e` | `#e85a44` |
| `rad-yellow` | `#e8b53f` | `#f0c25e` |
| `rad-teal` | `#127566` | `#5fc5b8` |
| `rad-ink` | `#0e1b1f` | `#f5ecdc` |
| `rad-cream` | `#fbf7ee` | `#fbf7ee` |

Deux valeurs arbitraires nécessaires (pas de token Tailwind) :
- Header/footer drawer light : `#e8e0cc` (beige chaud, intermédiaire entre `rad-bg` et `rad-rule`)
- Dark : `rad-raise` (`#1a4a50`) — token existant

---

## `_drawer.html.erb`

### Backdrop
Inchangé : `fixed inset-0 bg-black/50 z-40`.

### Conteneur drawer
- Remplacer `bg-white dark:bg-slate-900/95 border-l border-slate-200 dark:border-indigo-500/15` par `bg-rad-bg border-l border-rad-rule`
- Supprimer `backdrop-blur-sm` (non prescrit dans le design)

### Header
- Background : `bg-[#e8e0cc] dark:bg-rad-raise`
- **Stripes martiniquaises 4px** au sommet : `<div class="flex h-1">` avec 4 `<div class="flex-1">` en red / yellow / teal / ink
- Disposition : chevron ‹ à gauche, infos Tibo au centre, chip Q{number} à droite
- Bouton fermeture : chevron `‹` (`text-rad-text opacity-70`, `text-[22px]`) — remplace le ✕ actuel
- **Avatar Tibo** : cercle 40×40px `bg-rad-red`, lettre T `font-serif italic text-[19px] text-rad-cream`
  - Dot teal "online" : 10×10px `bg-rad-teal rounded-full border-2 border-[#e8e0cc] dark:border-rad-raise` positionné `absolute bottom-[1px] right-[1px]`
- Titre : `font-serif italic text-[17px] text-rad-text leading-none` "Tibo, ton tuteur"
- Sous-titre : `text-[11px] text-rad-muted mt-[3px]` "Sur la Q{number} · ne donne pas la réponse"
- Chip question : `text-[11px] font-bold px-2 py-1 rounded-lg bg-black/[.07] dark:bg-white/10 text-rad-muted` "Q{number} ↗" — lien vers la question (ou span si pas de lien)
- **Supprimer** l'ancienne card `bg-indigo-50` / `bg-indigo-500/10`

### Zone messages (`#tutor-chat-messages`)
- Background du drawer : `bg-rad-bg` + pattern madras via `style` inline :
  ```
  background-image: repeating-linear-gradient(45deg, rgba(212,69,46,0.06) 0 1px, transparent 1px 22px),
                    repeating-linear-gradient(-45deg, rgba(212,69,46,0.06) 0 1px, transparent 1px 22px),
                    repeating-linear-gradient(45deg, rgba(18,117,102,0.05) 0 1px, transparent 1px 7px),
                    repeating-linear-gradient(-45deg, rgba(18,117,102,0.05) 0 1px, transparent 1px 7px)
  ```
  Dark : remplacer les couleurs par `rgba(255,255,255,0.04)` et `rgba(255,255,255,0.025)`.
  Implémentation : classe utilitaire CSS dans `application.css` ou style inline conditionnel ERB.

- État vide : `text-rad-muted text-sm text-center mt-10`

### Streaming placeholder
- Remplacer `bg-slate-100 dark:bg-slate-800` par `bg-rad-paper border border-rad-rule`
- Ajouter avatar T 28px à gauche (même structure que bulles assistant dans `_message.html.erb`)
- Structure : `flex gap-2.5 items-start mx-4 mb-3`

### Input bar
- Background conteneur : `bg-[#e8e0cc] dark:bg-rad-raise border-t border-rad-rule`
- Champ : pill `bg-rad-paper border border-rad-rule rounded-full px-4 py-2 text-sm text-rad-text placeholder:text-rad-muted focus:outline-none focus:ring-2 focus:ring-rad-teal`
- Bouton send : cercle `w-10 h-10 rounded-full bg-rad-red text-rad-cream border-0 flex items-center justify-center text-[16px] cursor-pointer`
- Libellé bouton : `↑` (remplace "Envoyer")
- Garder `disabled:opacity-50`

---

## `_message.html.erb`

### Bulle user
- Remplacer `bg-gradient-to-br from-indigo-500 to-violet-500 text-white` par `bg-rad-red text-rad-cream`
- `rounded-2xl rounded-tr-sm` (était `rounded-br-sm`)
- `self-end max-w-[82%] text-sm leading-relaxed break-words`

### Bulle assistant
- Structure : `flex gap-2.5 items-start max-w-[86%]`
- Avatar T 28px : `w-7 h-7 rounded-full bg-rad-red flex-shrink-0 flex items-center justify-center`
  - Lettre : `font-serif italic text-[13px] text-rad-cream`
- Bulle : `bg-rad-paper border border-rad-rule rounded-2xl rounded-tl-sm px-3 py-2 text-sm leading-relaxed text-rad-text break-words`
- Supprimer `dark:bg-slate-800 dark:text-slate-200`

### Message system
- `text-xs italic text-rad-muted text-center self-center max-w-[85%]` — inchangé dans la logique, juste purger les tokens dark: slate

---

## `_confidence_form.html.erb`

- Container : `bg-rad-paper border border-rad-rule rounded-2xl p-4 max-w-[90%] self-start mt-2`
- Label : `text-xs font-semibold text-rad-muted mb-3`
- Boutons 1-5 : `w-9 h-9 rounded-full border border-rad-rule text-sm font-semibold text-rad-muted bg-rad-paper hover:bg-rad-raise hover:border-rad-teal hover:text-rad-teal transition-colors cursor-pointer`
- Légende : `text-[10px] text-rad-muted mt-2`

---

## Contraintes

- Pas de chips de suggestion (post-MVP)
- Pas de changement de logique Stimulus
- Le pattern madras doit fonctionner en light et dark — utiliser ERB conditionnel si nécessaire, ou deux classes CSS dédiées dans `application.css`
- Accessibilité : `aria-label`, `role="dialog"`, `aria-modal`, `aria-hidden` conservés tels quels

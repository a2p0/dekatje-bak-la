# Contract: Design Tokens — API de consommation pour B2-B7

**Date** : 2026-05-17
**Status** : Phase 1 (planning)
**Garantit** : à partir du merge de B1, les développeurs des phases B2-B7 et au-delà peuvent compter sur cette API stable pour construire et refondre les composants.

---

## 1. Tokens consommables

### 1.1 Tokens sémantiques (à utiliser PAR DÉFAUT)

19 tokens sémantiques sont garantis stables. Toujours préférer un sémantique à une primitive.

| Token | Quand l'utiliser |
|---|---|
| `--color-surface` | Background de cards, drawers, modales (le « papier » principal) |
| `--color-surface-raised` | Background d'éléments élevés au-dessus de la surface (chat bubbles, sticky headers internes à une card) |
| `--color-surface-sunken` | Background de la page sous les cards (le « canvas ») |
| `--color-on-surface` | Couleur du texte principal sur une surface |
| `--color-on-surface-muted` | Texte secondaire (sous-titres, captions, helper text) |
| `--color-rule` | Bordure douce (séparateurs entre sections d'une card, dividers) |
| `--color-rule-strong` | Bordure marquée (inputs, focus rings, outlines de cards en hover) |
| `--color-accent-primary` | CTA primaire (bouton principal d'une page, lien actif dans la nav) |
| `--color-on-accent-primary` | Texte/icône SUR un fond `accent-primary` (assure le contraste) |
| `--color-accent-secondary` | CTA secondaire, badges informatifs neutres, illustrations contextuelles |
| `--color-on-accent-secondary` | Texte/icône SUR un fond `accent-secondary` |
| `--color-success` | Validation positive (badge « publié », icône check, bordure d'une card succès) |
| `--color-on-success` | Texte SUR un fond `success` |
| `--color-warning` | Avertissement non-bloquant (badge « à valider », bandeau information importante) |
| `--color-on-warning` | Texte SUR un fond `warning` |
| `--color-danger` | Action destructive (bouton supprimer, erreur de saisie, état d'échec) |
| `--color-on-danger` | Texte SUR un fond `danger` |
| `--color-info` | Information neutre (banner, tooltip explicatif, badge système) |
| `--color-on-info` | Texte SUR un fond `info` |

**Comportement** : ces tokens **changent automatiquement** selon `data-audience` (student/teacher/public) et le mode (light/dark). Aucune logique conditionnelle nécessaire dans les composants.

### 1.2 Classes Tailwind générées

Tailwind v4 + `@theme` génère automatiquement les utilitaires correspondants :
- `bg-<role>` (ex: `bg-accent-primary`, `bg-surface-raised`)
- `text-<role>` (ex: `text-on-surface`, `text-on-surface-muted`)
- `border-<role>` (ex: `border-rule`, `border-rule-strong`)
- (et toutes les autres utilités acceptant une couleur : `ring-`, `divide-`, `placeholder-`, `outline-`, `caret-`, etc.)

Une classe `bg-accent-primary` sur un élément rendra :
- En rouge sur un layout élève (light ou dark)
- En teal sur un layout teacher (light ou dark)
- En rouge sur les pages publiques (équivalent au rendu actuel)

Sans aucune condition Ruby/ERB.

### 1.3 Tokens primitives (à NE PAS utiliser)

Les primitives (`--rad-prim-balisier-red`, `--rad-prim-sea-teal`, etc.) sont définies mais **doivent rester invisibles aux développeurs des phases B2-B7**.

**Exception** : si un cas d'usage légitime apparaît où un sémantique manque (ex: besoin d'utiliser le jaune brut sans qu'il s'agisse de `warning`), créer un NOUVEAU sémantique plutôt que de consommer la primitive. Documenter la justification dans la PR.

### 1.4 Tokens aliases (rétrocompat — figés)

Les 12 tokens `--color-rad-*` historiques continuent de fonctionner mais sont **dépréciés** à partir de B1. Aucun nouveau composant ne doit les utiliser.

- B4 migrera les vues élève qui les utilisent vers les sémantiques.
- B5 fera de même pour les vues teacher.
- Suppression définitive des aliases : prévue post-B5 (feature dédiée).

---

## 2. Garanties de stabilité

| Garantie | Portée |
|---|---|
| **Le set de 19 sémantiques NE rétrécira PAS** entre B1 et B7 | Critique pour B2-B7 |
| **Les noms des sémantiques NE changeront PAS** | Critique pour B2-B7 |
| **Les valeurs résolues NE changeront PAS sans annonce** | Le mapping primitive → sémantique peut évoluer si la palette Radical s'enrichit, mais toute évolution est documentée dans une feature dédiée |
| **Les classes Tailwind générées (`bg-<role>`, etc.) sont stables** | Critique |
| **Le mécanisme `data-audience` reste sur `<body>`** | Pas de déplacement vers `<html>` ou un wrapper |
| **Le mécanisme `.dark` reste sur `<html>`** | Compatibilité avec le script JS dark mode existant |

## 3. Ce qu'il ne FAUT PAS faire

❌ **Hardcoder une couleur hex** dans un composant ou une vue : `bg-[#d4452e]`, `color: red`, etc.
❌ **Consommer une primitive directement** : `bg-rad-prim-balisier-red`, `var(--rad-prim-sea-teal)`.
❌ **Utiliser un alias dans un nouveau composant** : `bg-rad-red`, `text-rad-muted`. (Sauf si la feature explicite est de patcher un composant existant qui les utilisait déjà, en attendant sa refonte.)
❌ **Mettre une condition Ruby** sur l'audience pour changer une couleur : `<%= "bg-red-500" if user.teacher? %>`. Si le token n'est pas adaptatif → on l'enrichit dans un nouveau spec, pas dans la vue.
❌ **Ajouter un sémantique sans cas d'usage réel** : la stabilité du set vient de sa restreinte. Tout ajout passe par une mini-feature documentée.

---

## 4. Comment vérifier qu'un composant respecte le contrat

### 4.1 Auto-check développeur

1. `grep -E "bg-\[#|color: ?#|var\(--rad-prim" app/components/mon_component.html.erb` → doit retourner 0 ligne
2. `grep -E "bg-rad-|text-rad-|border-rad-" app/components/mon_component.html.erb` → doit retourner 0 ligne pour un composant créé après B1
3. Tester visuellement le composant sur `/teacher/design-system/preview` (qui rend les 19 tokens × 4 combinaisons)

### 4.2 Test automatisé (pattern type)

Spec RSpec via Capybara (Selenium) :

```ruby
RSpec.describe "MonComponent under data-audience", type: :system do
  it "uses accent-primary teal under teacher layout" do
    visit "/teacher/design-system/preview"
    color = page.evaluate_script(
      "getComputedStyle(document.getElementById('probe-accent')).backgroundColor"
    )
    expect(color).to eq("rgb(18, 117, 102)") # sea-teal light
  end
end
```

Pattern : utiliser un élément probe (`<div id="probe-X" class="bg-accent-primary">`) déjà présent dans la page démo, puis lire `backgroundColor` via `getComputedStyle`. **Ne PAS** lire directement la CSS variable (`getPropertyValue('--color-accent-primary')` retourne la string littérale `var(...)`, pas la valeur résolue — cf. research.md Q4).

---

## 5. Évolution du contrat

Toute modification de ce contrat (ajout de sémantique, retrait d'alias, changement de comportement) DOIT :
1. Faire l'objet d'une feature dédiée (speckit ou diagnostic→plan→PR).
2. Mettre à jour ce fichier `contracts/design-tokens.md` (déplacé dans `docs/design-system/` au moment de sa première évolution post-B1).
3. Mettre à jour la page démo `/teacher/design-system/preview` pour refléter les nouveaux tokens.
4. Lister explicitement les composants impactés et leur statut de migration.

---

## 6. Référence : exemple complet « refondre un Button »

**Avant B1** (état actuel, vues élève) :
```erb
<%= link_to "Question suivante",
      next_question_path,
      class: "bg-rad-red text-rad-cream font-bold rounded-[14px] px-5 py-3" %>
```

**Après B2 (refonte ButtonComponent en utilisant le contrat)** :
```erb
<%= render ButtonComponent.new(
      variant: :primary,
      href: next_question_path
    ) do %>
  Question suivante
<% end %>
```

Où `ButtonComponent` rend en interne :
```erb
<%= link_to @href,
      class: "bg-accent-primary text-on-accent-primary font-bold rounded-button px-5 py-3" %>
```

→ Sur layout élève : `bg-accent-primary` = balisier-red, `text-on-accent-primary` = cream.
→ Sur layout teacher : `bg-accent-primary` = sea-teal, `text-on-accent-primary` = cream.
→ Sur pages publiques : `bg-accent-primary` = balisier-red.

Le composant ne sait rien de l'audience. C'est le contrat qui fait le travail.

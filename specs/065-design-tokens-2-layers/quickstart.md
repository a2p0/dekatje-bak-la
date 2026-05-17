# Quickstart: Utiliser le design system Radical (B2-B7)

**Date** : 2026-05-17
**Pour** : développeurs qui travaillent sur DekatjeBakLa après le merge de B1
**Référence canonique** : [contracts/design-tokens.md](./contracts/design-tokens.md)

---

## En 30 secondes

1. Pour styliser un composant ou une vue : **utilise une classe Tailwind sémantique**, ex: `bg-accent-primary`, `text-on-surface`, `border-rule`.
2. **N'utilise JAMAIS** : un hex en dur (`bg-[#d4452e]`), une primitive (`bg-rad-prim-*`), ni un alias dans un nouveau code (`bg-rad-red`).
3. Pour voir tous les tokens en live : ouvre [`/teacher/design-system/preview`](http://localhost:3000/teacher/design-system/preview) après login teacher.
4. Si ton composant doit avoir un look différent entre teacher et élève : **n'ajoute aucune condition Ruby**, utilise les bons sémantiques (`accent-primary` change automatiquement de teal à rouge selon le layout).

---

## Les 19 tokens à connaître

Mémorise ces 5 groupes :

| Groupe | Tokens | Pour quoi |
|---|---|---|
| **Surfaces** | `surface`, `surface-raised`, `surface-sunken` | Backgrounds des éléments |
| **Textes** | `on-surface`, `on-surface-muted` | Textes principaux/secondaires |
| **Rules** | `rule`, `rule-strong` | Bordures, séparateurs |
| **Accents brand** | `accent-primary`, `on-accent-primary`, `accent-secondary`, `on-accent-secondary` | CTA, éléments d'identité visuelle |
| **États** | `success`, `warning`, `danger`, `info` (+ `on-*` pour chacun) | Statuts, alertes, validations |

Convention : `on-X` est toujours **le texte ou l'icône posé sur un fond X**, calibré en contraste.

---

## Mini recettes

### Recette 1 — Un bouton primaire

```erb
<button class="bg-accent-primary text-on-accent-primary px-5 py-3 rounded-button font-semibold">
  Action principale
</button>
```

→ Rouge sur élève, teal sur teacher. Un seul code source.

### Recette 2 — Une card avec header et footer

```erb
<div class="bg-surface border border-rule rounded-card overflow-hidden">
  <header class="px-5 py-4 border-b border-rule">
    <h2 class="text-on-surface text-lg font-semibold">Titre de la card</h2>
  </header>
  <div class="px-5 py-4 text-on-surface">
    Contenu principal.
    <p class="text-on-surface-muted text-sm mt-2">Sous-texte secondaire.</p>
  </div>
  <footer class="px-5 py-3 bg-surface-raised border-t border-rule">
    Footer optionnel
  </footer>
</div>
```

### Recette 3 — Un badge de statut

```erb
<span class="inline-flex items-center gap-1 px-2.5 py-0.5 bg-success/15 text-success border border-success/30 rounded-pill text-xs font-medium">
  Publié
</span>
```

(Le `/15` et `/30` sont des opacités Tailwind sur les couleurs — supportés out-of-the-box.)

### Recette 4 — Un input avec focus visible

```erb
<input
  type="text"
  class="w-full px-3 py-2 bg-surface text-on-surface border border-rule rounded-input focus:outline-none focus:ring-2 focus:ring-accent-primary focus:border-rule-strong"
/>
```

### Recette 5 — Une alerte d'erreur

```erb
<div class="px-4 py-3 bg-danger/10 text-danger border border-danger/30 rounded-card">
  <strong class="font-semibold">Erreur :</strong> Le PDF dépasse la limite de 20 Mo.
</div>
```

---

## Tester un composant sous différentes audiences

### Option A — Visuel (le plus rapide)

1. Ajoute temporairement ton composant à la page démo `/teacher/design-system/preview`.
2. Ouvre la page sous chaque audience. La page démo a des sélecteurs intégrés pour basculer student/teacher/public et light/dark.

### Option B — Spec automatisé

Pattern pour un spec system qui vérifie qu'un token rend la bonne couleur :

```ruby
# spec/system/mon_component_audience_spec.rb
require "rails_helper"

RSpec.describe "MonComponent under different audiences", type: :system, js: true do
  before { driven_by :selenium_chrome_headless }

  it "renders accent-primary in teal for teacher" do
    sign_in_as_teacher
    visit teacher_dashboard_path
    # Suppose qu'on a un probe ou un élément avec class="bg-accent-primary"
    color = page.evaluate_script(<<~JS)
      const el = document.querySelector('.bg-accent-primary');
      return getComputedStyle(el).backgroundColor;
    JS
    expect(color).to eq("rgb(18, 117, 102)") # sea-teal #127566
  end

  it "renders accent-primary in red for student" do
    sign_in_as_student
    visit student_root_path
    color = page.evaluate_script("getComputedStyle(document.querySelector('.bg-accent-primary')).backgroundColor")
    expect(color).to eq("rgb(212, 69, 46)") # balisier-red #d4452e
  end
end
```

**Piège** : ne tente PAS de lire directement la CSS variable :
```ruby
# ❌ NE FONCTIONNE PAS — retourne "var(--rad-prim-balisier-red)" (string littérale)
page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--color-accent-primary')")

# ✅ FONCTIONNE — retourne la couleur résolue
page.evaluate_script("getComputedStyle(document.querySelector('.bg-accent-primary')).backgroundColor")
```

---

## FAQ

### Quand utiliser `surface` vs `surface-raised` vs `surface-sunken` ?

- **`surface-sunken`** : c'est le canvas de la page, derrière tout (équivalent du body actuel).
- **`surface`** : c'est la « feuille de papier » qui repose sur le canvas (une card, un drawer).
- **`surface-raised`** : c'est ce qui est posé SUR la surface (un footer de card, une bulle de chat, un sticky header interne).

Hiérarchie visuelle : sunken → surface → raised, de la plus enfoncée à la plus en relief.

### Quand utiliser `rule` vs `rule-strong` ?

- **`rule`** : divider doux à l'intérieur d'une card, séparateurs subtils, bordures qui ne doivent pas se voir.
- **`rule-strong`** : bordures qui structurent (cards en hover, inputs au repos, focus rings, outlines marqués).

### Et si j'ai besoin d'un sémantique qui n'existe pas (ex: « accent-tertiary ») ?

Ouvrir une feature dédiée. Le set de 19 est délibérément restreint pour rester maintenable. Si plusieurs composants ont le même besoin justifié, on l'ajoute. Si c'est un cas isolé, on regarde s'il peut se traiter avec les sémantiques existants.

### Le mode dark fonctionne tout seul ?

Oui. Si tu utilises uniquement les sémantiques, le dark mode est gratuit. Aucune classe `dark:` n'est nécessaire pour les couleurs (le token résout en valeur dark automatiquement quand `.dark` est sur `<html>`).

Exception : si tu fais quelque chose de spécial qui n'est pas couvert par les tokens (ex: un dégradé custom, une image qui change selon le thème), tu peux utiliser `dark:` ponctuellement.

### Et les composants existants qui utilisent encore `bg-rad-*` ?

Ils continuent de fonctionner exactement comme avant B1 (rétrocompat 100 %). B4 (élève) et B5 (teacher) les migrent vers les sémantiques. Si tu touches à un de ces composants en attendant : tu peux profiter d'y faire la migration ponctuelle, mais ce n'est pas obligatoire.

### Et les magic numbers `[14px]`, `[10.5px]`, `[18px]` qui traînent dans les vues élève ?

Hors scope B1. Phase B6 les nettoiera. Si tu en ajoutes dans un nouveau code, essaie de mapper sur une échelle Tailwind standard (`text-sm`, `text-base`, etc.) ou sur un radius token (`rounded-card`, `rounded-button`, `rounded-input`, `rounded-pill`).

---

## Liens utiles

- **Contrat complet** : [contracts/design-tokens.md](./contracts/design-tokens.md)
- **Data model** (mapping primitives ↔ sémantiques) : [data-model.md](./data-model.md)
- **Décisions techniques** (recherche Phase 0) : [research.md](./research.md)
- **Spec d'origine** : [spec.md](./spec.md)
- **Page démo en live** : `/teacher/design-system/preview` (auth teacher requise)

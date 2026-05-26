# Feature B2a — Refonte des atomes (Button, Badge, Card)

**Date** : 2026-05-25
**Branche cible** : `066-design-system-b2a-atoms-refactor`
**Phase** : B2a — première sous-feature de B2 (Atomes refondus)
**Prérequis** : B1 (PR #102, tokens 2 couches `--color-*` + `data-audience` livrés)

---

## 1. Contexte

Le projet a un design Radical déployé côté élève (PRs 054-057) et une architecture de tokens sémantiques 2 couches livrée en B1 (PR #102, merge `be4cc53`). Les ViewComponents atomiques existants (`ButtonComponent`, `BadgeComponent`, `CardComponent`) sont restés sur des couleurs Tailwind hardcodées (indigo/emerald/violet/slate) et exposent une API orientée couleur plutôt qu'intention. L'audit UI 10 dimensions (`docs/audits/2026-05-16-ui-design-audit.md`) et la synthèse Radical unifié (`docs/design-system/2026-05-17-radical-unified-synthesis.md` §4.1, §7) prescrivent leur refonte vers une API sémantique consommant les tokens B1.

B2 est découpé en deux sous-features (validé brainstorming 2026-05-25) :

- **B2a (cette feature)** — refonte des 3 composants atomiques existants (Button, Badge, Card)
- **B2b (différée)** — création des 2 nouveaux composants atomiques (Field, Stripes)

Cette feature traite la dette technique avant d'enrichir le système.

---

## 2. Objectif

Refondre `ButtonComponent`, `BadgeComponent`, `CardComponent` pour exposer une API de variantes sémantiques branchées sur les tokens B1, tout en garantissant **zéro régression visuelle** sur les 79 sites d'appel existants via un pont temporaire d'aliases legacy.

---

## 3. Périmètre

### 3.1 In scope

- Refonte des classes Tailwind de `ButtonComponent`, `BadgeComponent`, `CardComponent` pour consommer les tokens sémantiques (`accent-primary`, `surface`, `on-accent`, `rule`, etc.)
- Nouvelles variantes sémantiques exposées par API publique :
  - Button : `:primary`, `:secondary`, `:ghost`, `:danger`, `:ink`
  - Badge : `:primary`, `:secondary`, `:warning`, `:success`, `:neutral`, `:specialty_sin`, `:specialty_itec`, `:specialty_ec`
  - Card : `variant: :default | :elevated | :hero | :outlined` + `accent: :primary | :secondary | :warning | :success`
- Conservation pixel-perfect des anciennes variantes en aliases marqués `# DEPRECATED`
  - Button : `:gradient` (= rendu indigo gradient actuel), `:success` (= rendu emerald actuel)
  - Badge : `:indigo`, `:emerald`, `:amber`, `:blue`, `:slate`, `:rose`, `:rad_teal`, `:rad_red`, `:rad_yellow`, `:rad_muted`
  - Card : `:rad`, `:glow`, `:default` (legacy)
- Bugfix `CardComponent` footer (audit P1 #6) : le footer hérite des tokens de la variant courante (plus de `border-rad-rule` figé)
- Nouveaux états ButtonComponent : `disabled:`, `loading:` (spinner inline + `aria-busy`)
- Focus ring sur Button : `accent-secondary` + offset 2px (corrige audit P1 #5)
- Tests RSpec ViewComponent : nouvelles variantes + aliases legacy (pixel-perfect) + bugfix footer + états Button
- Issue GitHub de suivi : « B2 — supprimer les alias legacy des atomes refondus », référencée en commentaire dans chaque composant

### 3.2 Out of scope

- **Aucune migration de vue** : les 79 sites d'appel existants restent intacts (adoption zéro, conforme à la stratégie validée)
- Page démo `/teacher/design-system/preview` non touchée (PR docs dédiée plus tard)
- Field, Stripes (→ B2b)
- EmptyStateComponent (reporté en B3 — c'est un composé, pas un atome)
- Composés : NavBar, BottomBar, Modal, Flash, ProgressBar, Breadcrumb, ThemeToggle (→ B3)
- Adoption student (CTA ad-hoc → ButtonComponent) (→ B4)
- Reskin teacher (`data-audience="teacher"` activé + migration couleurs) (→ B5)

---

## 4. Critères de succès

| ID | Critère | Validation |
|---|---|---|
| SC-1 | Les 3 composants exposent les nouvelles variantes sémantiques avec les tokens B1 (pas de couleur Tailwind hardcodée dans le code des nouvelles variantes) | RSpec : chaque nouvelle variante rend une classe contenant le token sémantique attendu |
| SC-2 | Zéro régression visuelle sur les 79 sites d'appel existants | Diff ImageMagick AE=0 sur baseline B1 étendue (5 écrans × light/dark) avant merge |
| SC-3 | Le bug du footer Card (P1 #6) est corrigé : footer hérite des tokens de la variant courante | Spec RSpec dédié : Card `:hero accent: :success` rend un footer avec border-top accent-success |
| SC-4 | 100% des specs ViewComponent passent (anciennes baselines + nouvelles variantes + bugfix) | CI verte |
| SC-5 | Une issue GitHub de suivi est ouverte, référencée par chaque alias legacy | Manuel : grep `DEPRECATED` dans `app/components/`, vérification du lien |

---

## 5. Architecture

### 5.1 Stratégie de rétrocompat (pont temporaire)

Validée brainstorming 2026-05-25 : option 1 « pont temporaire (deprecation soft) ».

- Les anciens noms de variantes (`:gradient`, `:indigo`, `:emerald`, `:rad`, `:glow`, etc.) restent disponibles en aliases qui **gèlent exactement le rendu Tailwind d'avant B2a**.
- Chaque alias est annoté `# DEPRECATED — see #<ISSUE>` dans le code Ruby.
- Suppression des aliases en B4 (student) et B5 (teacher) quand les sites d'appel auront été migrés ou rendus obsolètes par le reskin.

Justification : pattern déjà validé en B1 (aliases `--color-rad-*` conservés, désamorcés par la suite). Permet d'isoler la refonte des composants de la migration des vues — risque de régression contenu, PR de taille raisonnable.

### 5.2 ButtonComponent

**API publique** :
```ruby
ButtonComponent.new(
  variant: :primary | :secondary | :ghost | :danger | :ink | :gradient (DEPRECATED) | :success (DEPRECATED),
  size: :sm | :md | :lg,
  pill: false,
  href: nil,
  disabled: false,
  loading: false,
  **html_options
)
```

**Tokens sémantiques utilisés (nouvelles variantes)** :

> ⚠️ **Mapping corrigé 2026-05-26**. Les noms originalement écrits dans ce spec
> (`accent-warning`, `accent-success`, `text-primary`, `text-muted`,
> `surface-elevated`, `surface-inverse`, `on-inverse`, `on-accent` sans suffixe)
> n'existaient pas dans B1. Tokens B1 réels disponibles :
> `surface`, `surface-raised`, `surface-sunken`, `on-surface`,
> `on-surface-muted`, `rule`, `rule-strong`, `accent-primary`,
> `on-accent-primary`, `accent-secondary`, `on-accent-secondary`,
> `success`, `warning`, `danger`, `info` + leurs `on-*`.

- `:primary` → `bg-accent-primary text-on-accent-primary`
- `:secondary` → `bg-transparent border border-on-surface text-on-surface`
- `:ghost` → `bg-transparent text-on-surface-muted`
- `:danger` → `bg-danger text-on-danger`
- `:ink` → `bg-on-surface text-surface` (inversion sémantique : `on-surface` = ink/cream selon thème devient le fond, `surface` devient le texte)

**Tailles** : inchangées de l'existant (sm/md/lg padding+text).

**États** :
- `:focus-visible` : ring `accent-secondary` + offset 2px (corrige audit P1 #5)
- `:hover` : assombrissement de la couleur d'accent (Tailwind `/90`)
- `:disabled` : `opacity-60 cursor-not-allowed`, ajoute `aria-disabled="true"`
- `:loading` : ajoute un span spinner inline avant le contenu, ajoute `aria-busy="true"`, désactive le clic

**Aliases legacy** : `gradient` et `success` rendent exactement les classes Tailwind d'avant B2a (cf. `PRIMARY_CLASSES` et la chaîne emerald actuelles).

### 5.3 BadgeComponent

**API publique** (param `color:` conservé pour ne pas migrer les 10 sites d'appel) :
```ruby
BadgeComponent.new(
  color: :primary | :secondary | :warning | :success | :neutral
       | :specialty_sin | :specialty_itec | :specialty_ec
       | :indigo (DEPRECATED) | :emerald (DEPRECATED) | :amber (DEPRECATED)
       | :blue (DEPRECATED) | :slate (DEPRECATED) | :rose (DEPRECATED)
       | :rad_teal (DEPRECATED) | :rad_red (DEPRECATED)
       | :rad_yellow (DEPRECATED) | :rad_muted (DEPRECATED),
  label:
)
```

**Tokens sémantiques utilisés** (pattern bg @ 10% + text + border @ 20%, mapping corrigé 2026-05-26 vers tokens B1 réels) :
- `:primary` → `bg-accent-primary/10 text-accent-primary border border-accent-primary/20`
- `:secondary` → `bg-accent-secondary/10 text-accent-secondary border border-accent-secondary/20`
- `:warning` → `bg-warning/10 text-warning border border-warning/20`
- `:success` → `bg-success/10 text-success border border-success/20`
- `:neutral` → `bg-rule/40 text-on-surface-muted border border-rule`
- `:specialty_sin/itec/ec` → couleurs métier. Mapping concret à figer pendant l'implémentation par grep des sites d'appel actuels : si une vue passe aujourd'hui `BadgeComponent.new(color: :rad_yellow, label: "SIN")`, la nouvelle variante `:specialty_sin` doit rendre les mêmes classes que `:rad_yellow` legacy. Sinon, choisir un mapping cohérent avec le bundle `teacher/shared.jsx:73-91` (`Badge color={specialtyColor(c.specialty)}`).

**API d'init** : préservée à l'identique (`color:`, `label:`).

**Aliases legacy** : 10 noms gardés, classes Tailwind d'avant figées.

### 5.4 CardComponent

**API publique** :
```ruby
CardComponent.new(
  variant: :default | :elevated | :hero | :outlined
         | :rad (DEPRECATED) | :glow (DEPRECATED),
  accent: nil | :primary | :secondary | :warning | :success
)
```

**Variantes** (mapping corrigé 2026-05-26 vers tokens B1 réels) :
- `:default` → `bg-surface border border-rule rounded-2xl`
- `:elevated` → `bg-surface-raised border border-rule shadow-sm rounded-2xl`
- `:hero` → `bg-{accent_bg} text-{accent_on} rounded-2xl` où accent map à : primary→`accent-primary/on-accent-primary`, secondary→`accent-secondary/on-accent-secondary`, success→`success/on-success`, warning→`warning/on-warning`, danger→`danger/on-danger`
- `:outlined` → `bg-transparent border-l-4 border-{accent_bg} rounded-2xl` (même mapping)

**Slots** : `header`, `body`, `footer` — inchangés.

**Bugfix footer (SC-3)** : le template `card_component.html.erb` ne hardcode plus `border-rad-rule` sur le footer. À la place, `CardComponent` expose une méthode helper `footer_classes` qui retourne les classes appropriées en fonction de `@variant` et `@accent`. Le template appelle `<div class="<%= footer_classes %>">` pour le footer.

**Aliases legacy** : `:rad` et `:glow` gèlent les classes actuelles ; `:default` reste rendu à l'identique.

### 5.5 Ordre d'implémentation interne

1. **Card** d'abord (le plus petit, contient le bugfix qui motive la PR) — permet de calibrer l'approche tests/aliases sur un composant simple.
2. **Badge** ensuite (refonte sémantique nombreuse mais sans logique d'état).
3. **Button** en dernier (le plus risqué : 18 sites d'appel, états nouveaux, focus ring).

---

## 6. Validation et tests

### 6.1 Tests RSpec ViewComponent

Localisation : `spec/components/{button,badge,card}_component_spec.rb`. Couverture :

**`button_component_spec.rb`** (~12 specs) :
- 5 variantes sémantiques × rendu de la classe token attendue (`bg-accent-primary`, etc.)
- 2 aliases legacy × pixel-perfect baseline (string literal du rendu d'avant)
- 1 spec par taille (sm/md/lg) × rendu classes padding+text attendues (regression guards — tailles inchangées vs existant mais garde contre dérive future)
- 1 spec `disabled: true` → rendu `aria-disabled="true" opacity-60`
- 1 spec `loading: true` → rendu `aria-busy="true"` + span spinner présent
- 1 spec focus-visible → rendu ring `accent-secondary` + offset 2px
- 1 spec `href:` → rendu `<a>` au lieu de `<button>`
- 1 spec `pill: true` → rendu `rounded-full`

**`badge_component_spec.rb`** (~18 specs) :
- 5 variantes sémantiques × rendu attendu
- 3 variantes specialty × rendu attendu
- 10 aliases legacy × pixel-perfect baseline (10 specs courts)

**`card_component_spec.rb`** (~10 specs) :
- 4 variantes × rendu attendu (default, elevated, hero, outlined)
- 4 accents × variantes hero/outlined (mapping correct du bg/border)
- 2 aliases legacy × pixel-perfect baseline (rad, glow)
- 1 spec dédié SC-3 : `Card variant: :hero, accent: :success` rend un footer avec border-top contenant `accent-success` (et non `border-rad-rule`)
- 1 spec slots header/body/footer rendus quand fournis

### 6.2 Validation visuelle (SC-2)

Avant merge :
1. Reprendre la baseline B1 (5 écrans × light/dark — cf. mémoire feature 065)
2. Capturer les mêmes écrans sur la branche B2a
3. Diff ImageMagick AE=0 attendu pour chaque image

Si AE > 0 sur une image : soit un alias legacy a dérivé du rendu original, soit un site d'appel utilise un défaut qui a bougé. Investigation requise avant merge.

### 6.3 CI

Pas de changement de pipeline. La suite RSpec complète s'exécute. Pas de spec system/Capybara ajouté (les composants sont testés en isolation, suffisant pour B2a).

---

## 7. Issue GitHub de suivi

À créer dans la même PR (référencée depuis le code) :

**Titre** : « B2 — supprimer les alias legacy des atomes refondus (Button/Badge/Card) »

**Body** :
- Liste des aliases à supprimer une fois tous les sites d'appel migrés :
  - Button : `:gradient`, `:success` (et `PRIMARY_CLASSES` constant)
  - Badge : `:indigo`, `:emerald`, `:amber`, `:blue`, `:slate`, `:rose`, `:rad_teal`, `:rad_red`, `:rad_yellow`, `:rad_muted`
  - Card : `:rad`, `:glow`, et toute branche `case @variant when :default` legacy
- Closing : après B5 (reskin teacher) quand le dernier site d'appel aura été migré ou supprimé

Chaque alias dans le code aura un commentaire `# DEPRECATED — see #<ISSUE_NUMBER>`.

Note : `<ISSUE_NUMBER>` est un placeholder à substituer pendant l'implémentation (l'issue est créée dans la même PR, son numéro inséré dans le code une fois connu).

---

## 8. Risques et mitigations

| Risque | Probabilité | Mitigation |
|---|---|---|
| Un alias legacy diverge accidentellement du rendu original | Moyenne | Specs pixel-perfect (string literal) sur chaque alias |
| Bugfix footer Card change un rendu existant non visible dans les écrans baseline | Faible | Grep préalable des sites d'appel qui utilisent `footer` slot → screenshots dédiés si différents de la baseline B1 |
| Le rename interne `VARIANTS → VARIANTS` (Button) ou `COLORS → COLORS` (Badge) casse un import quelque part | Très faible | Grep `BadgeComponent::COLORS` et `ButtonComponent::VARIANTS` avant refacto |
| Le focus ring `accent-secondary` provoque un changement visuel notable sur les screenshots baseline (qui ne capture pas un état focus) | Faible | Screenshots baseline = états repos ; focus ring vérifié séparément en RSpec uniquement |

---

## 9. Définition de "terminé"

Conforme à la constitution §Definition of Done :

- [x] Plan validé par l'utilisateur avant implémentation *(en cours)*
- [ ] Tests RSpec passent (unit ViewComponent + bugfix dédié)
- [ ] Branche dédiée `066-design-system-b2a-atoms-refactor` créée
- [ ] PR créée et CI verte
- [ ] Diff visuel ImageMagick AE=0 sur baseline B1 étendue (light + dark) ← SC-2
- [ ] Issue GitHub de suivi créée, référencée depuis le code
- [ ] Pas de couleur Tailwind hardcodée dans les nouvelles variantes (grep `bg-indigo|bg-emerald|bg-violet|bg-slate` dans Button/Badge/Card nouvelles variantes = 0 match)
- [ ] Interface inchangée pour les sites d'appel existants

---

## 10. Suite

Après merge B2a :
- **B2b** — création de `FieldComponent` et `StripesComponent` (nouveaux composants, pas de rétrocompat, plus simple)
- **B3** — composés (NavBar, Modal, Flash, ProgressBar, EmptyState, ThemeToggle, BottomBar, Breadcrumb)
- **B4** — adoption student
- **B5** — reskin teacher (suppression des aliases legacy au passage)

---

## Annexes

### A.1 Fichiers Rails touchés

```
app/components/button_component.rb       (refonte API + classes)
app/components/badge_component.rb        (refonte API + classes)
app/components/card_component.rb         (refonte + footer_classes helper)
app/components/card_component.html.erb   (utilise footer_classes au lieu de border-rad-rule figé)
spec/components/button_component_spec.rb (nouveau ou refonte si existe)
spec/components/badge_component_spec.rb  (nouveau ou refonte si existe)
spec/components/card_component_spec.rb   (nouveau ou refonte si existe)
```

### A.2 Sites d'appel (inventaire, intacts en B2a)

- **ButtonComponent (18 vues)** : views/teacher/classrooms/{edit,index,show,new}, views/teacher/subjects/{new,index,show,_stats,_parts_list,assignments/edit,validations/show}, views/users/{passwords/new,passwords/edit,registrations/new,registrations/edit,sessions/new}, views/student/settings/show, views/pages/home, components/bottom_bar_component
- **BadgeComponent (10 vues)** : views/student/questions/_sidebar, views/student/subjects/index, views/teacher/{classrooms/index,classrooms/show,subjects/show,subjects/index,subjects/_parts_list,subjects/_extraction_status,subjects/assignments/edit,questions/_question}
- **CardComponent (5 vues)** : views/teacher/{classrooms/index,classrooms/show,subjects/show,questions/_question}, views/student/subjects/index

### A.3 Références

- Roadmap : `docs/design-system/2026-05-17-radical-unified-synthesis.md` §4.1, §7
- Audit : `docs/audits/2026-05-16-ui-design-audit.md` (findings P1 #5, P1 #6, #8)
- Bundle source : `.design-bundles/h-YiyL6SBBamTp3pu9UnSZsg/` (gitignored — `teacher/shared.jsx:157-160` pour tailles Button, `radical.jsx:182-193` pour Card hero)
- B1 livré : PR #102 merge `be4cc53`, mémoire `feature-065-design-tokens-b1-merged.md`

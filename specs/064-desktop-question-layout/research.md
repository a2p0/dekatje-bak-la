# Phase 0 — Research: Desktop Question Layout

**Feature** : 064-desktop-question-layout
**Date** : 2026-05-11

## R1 — Coordination overlays Parties ↔ Tibo (un seul actif à la fois)

**Question** : Comment garantir FR-012 ("un seul overlay actif à la fois") sans state manager ?

**Decision** : Événements DOM customs entre les deux Stimulus controllers.

- Quand `chat_drawer#open` est appelé : il dispatche `overlay:open` (detail: `{name: "tibo"}`). `sidebar_controller` écoute et ferme si actuellement ouvert avec un autre `name`.
- Symétrique : `sidebar#open` dispatch `overlay:open` (detail: `{name: "sidebar"}`) ; `chat_drawer` ferme.

**Rationale** :
- Stimulus pattern idiomatique : les controllers communiquent via le DOM, pas de couplage direct.
- Pas de store global, pas de Redux.
- Réutilise les méthodes `open`/`close` existantes ; on ajoute juste un listener.

**Alternatives considered** :
- ❌ Variable globale `window.activeOverlay` — fuite d'état, debug pénible.
- ❌ Pinia/Zustand-like store — overkill, hors stack Hotwire.
- ❌ Tout réécrire dans un unique `overlay_controller` — casse la séparation de responsabilités, gros refactor pour gain nul.

## R2 — Sidebar Parties : nouveau popover ou recyclage du drawer existant ?

**Question** : Le design propose un "popover via bouton Parties". L'app a déjà une sidebar full-height avec `sidebar_controller`. Faut-il un nouveau composant popover ?

**Decision** : Réutilisation pure du drawer existant, sans changer le markup.

- Mobile (<lg) : comportement actuel inchangé (drawer left, backdrop, focus trap).
- Desktop (≥lg) : passer de `lg:relative lg:translate-x-0` (sidebar permanente) à `lg:fixed lg:-translate-x-full` (sidebar masquée par défaut). Le bouton "Parties" dans la navbar appelle `sidebar#open` qui translate à `0`. Backdrop devient `lg:block` quand ouvert.

**Rationale** :
- Zéro markup nouveau, zéro nouvel asset CSS, zéro nouveau controller.
- Le `sidebar_controller` actuel a déjà `open`/`close`/`updateToggles` qui marchent transversalement.
- Le focus trap est déjà câblé.

**Alternatives considered** :
- ❌ Vrai popover anchored sur le bouton (Floating UI) — dépendance ajoutée pour un gain UX marginal.
- ❌ Modal centré — pas la sémantique d'une nav.

## R3 — Drawer Tibo desktop : 60/40 chat | contexte

**Question** : Comment passer le drawer de `w-[420px]` à un layout 60/40 en desktop sans casser le mobile ?

**Decision** : Élargir le drawer à `lg:w-[60vw] lg:max-w-[900px]` et ajouter à l'intérieur un panneau contexte rendu via partial `_context_panel.html.erb`.

Structure :
```
<div id="tutor-chat-drawer" class="... lg:flex">
  <div class="flex-1 lg:basis-3/5 ...">  <!-- chat existing -->
    ...
  </div>
  <aside class="hidden lg:block lg:basis-2/5 border-l border-rad-rule ...">
    <!-- _context_panel.html.erb : rappel question + objectif partie -->
  </aside>
</div>
```

**Rationale** :
- Le chat actuel n'a pas besoin de changer de structure.
- `lg:flex` + `basis-3/5`/`basis-2/5` donne le ratio 60/40 demandé.
- Panneau contexte caché sur mobile (`hidden lg:block`) — comportement mobile préservé.
- Contenu du contexte = rappel `question.label` + lien éventuel + objectif `part.objective_text` ; toutes ces données sont déjà passées au drawer comme locals.

**Alternatives considered** :
- ❌ Deux drawers séparés synchronisés — complexité ++, focus management cassé.
- ❌ Resize JS dynamique — pure CSS suffit.

## R4 — DT viewer desktop : iframe + bandeau références

**Question** : Le design dessine onglets DT1/DT2/DT3 + pagination, mais le modèle réel n'a qu'un seul PDF (`Subject.dt_file` via ActiveStorage). Comment afficher la colonne droite ?

**Decision** : Iframe unique du `Subject.dt_file` + 2 bandeaux superposés (références + donnée utile).

Structure :
```erb
<%# _dt_viewer.html.erb %>
<% if @subject.dt_file.attached? && @question.dt_references.present? %>
  <%# Bandeau références %>
  <div class="bg-rad-paper border-b border-rad-rule px-4 py-2 flex gap-2">
    <% @question.dt_references.each do |ref| %>
      <span class="badge bg-rad-yellow ...">DT<%= ref %></span>
    <% end %>
  </div>

  <%# Bandeau donnée utile (correction seulement) %>
  <% if @show_data_hint && @question.answer&.data_hints.present? %>
    <%= render "data_hint_banner", hint: @question.answer.data_hints.first %>
  <% end %>

  <%# Iframe PDF %>
  <iframe src="<%= rails_blob_url(@subject.dt_file) %>" class="flex-1" title="Document Technique"></iframe>
<% else %>
  <div class="empty-state">Aucun DT pour cette question</div>
<% end %>
```

**Rationale** :
- Conforme au modèle réel.
- Évite d'introduire un `TechnicalDocument` qui n'existe pas.
- Le bandeau "donnée utile" affiche `hint['source']` + `hint['location']` textuellement (pas de page extraite).

**Alternatives considered** :
- ❌ Tabs `pdf_tabs_controller` étendu — pas de PDFs séparés à monter en onglets.
- ❌ Surlignage de la page dans l'iframe — impossible sans pdf.js, hors scope.

## R5 — Navbar desktop : layout vs partial vs ViewComponent

**Question** : Où placer la navbar desktop ?

**Decision** : Partial `_desktop_nav.html.erb` rendu depuis `layouts/student.html.erb` conditionnellement.

```erb
<%# layouts/student.html.erb %>
<% if request.path.starts_with?("/#{params[:access_code]}") && current_student %>
  <%= render "shared/desktop_nav" %>
<% end %>
```

**Rationale** :
- Partial = simple, pas besoin de slots/multiline ViewComponent.
- Conditionnel sur `current_student` évite de la rendre sur la page de login.
- Hidden sur mobile via classes Tailwind (`hidden lg:flex`).

**Alternatives considered** :
- ❌ ViewComponent dédié — pas de logique métier, partial suffit.
- ❌ Inclure dans `show.html.erb` directement — visible aussi sur subjects/index/etc., d'où le placement dans le layout.

## R6 — Specs Capybara desktop : driver et viewport

**Question** : Le driver `:headless_chrome` est déjà à `1400×900`, donc >1024. Suffisant pour tester desktop ?

**Decision** : Oui — le driver actuel teste déjà desktop par défaut. Pour vérifier le **mobile**, il faut soit changer la window size avant le scenario, soit utiliser `page.driver.browser.manage.window.resize_to(390, 800)` au début des specs mobile spécifiques.

**Rationale** :
- Les specs existantes ont été écrites contre 1400×900 mais visaient le mobile en cachant ce qui est `lg:hidden`. Donc :
  - Specs existantes vérifient surtout le markup commun + ce qui n'est pas `lg:hidden`.
  - Nouvelles specs desktop vérifient ce qui est `lg:flex`/`lg:block` (navbar, DT viewer panel, etc.).
  - Une spec sentinel mobile (resize_to 390) garantit que `lg:` ne casse rien.

**Alternatives considered** :
- ❌ Cuprite — pas dans la stack, ajouter une dépendance.
- ❌ Multiple drivers — surcharge config.

## R7 — Bouton « Parties » dans la navbar

**Question** : Le bouton "Parties" doit-il être visible en mobile (pour cohérence) ou strictly desktop ?

**Decision** : Visible seulement en desktop (`hidden lg:inline-flex`). En mobile, le bouton `≡` dans le header de la question est déjà là.

**Rationale** :
- Évite la duplication UI sur mobile.
- Le bouton `≡` mobile existant continue à utiliser le même `sidebar#open` — comportement cohérent.

## R8 — Bouton "Parties" hors du scope `data-controller="sidebar"`

**Question** : Le bouton "Parties" est rendu dans le partial `_desktop_nav.html.erb` inclus depuis le layout. Le `data-controller="sidebar"` est monté sur le wrapper de `show.html.erb`. Comment câbler le `click->sidebar#open` quand le bouton est hors du scope ?

**Decision** : Déplacer `data-controller="sidebar chat-drawer"` du wrapper interne de `show.html.erb` vers `<main id="main-content">` dans `layouts/student.html.erb`. Ainsi le scope englobe à la fois la navbar (rendue dans le layout) et le contenu de la page.

**Rationale** :
- Stimulus controllers descendent dans le DOM, leur scope englobe tous les enfants. Mettre le `data-controller` plus haut élargit naturellement le scope.
- `<main>` est la frontière naturelle entre l'app shell (qui doit avoir l'état overlay) et le shell HTML pur (head, body).
- Le `data-sidebar-target="drawer"` reste sur l'`<aside>` interne, le controller le retrouve.
- Aucun coût (le controller est instancié au même moment).
- Note Stimulus : la syntaxe `click@window->sidebar#open` n'est pas supportée pour les events DOM standards (`@window` vaut surtout pour `keydown`/`resize` globaux), donc l'approche élargissement scope est plus propre que tenter une délégation window.

**Alternatives considered** :
- ❌ Custom event sur window + listener générique — surcharge inutile.
- ❌ Dupliquer un controller "navbar_sidebar" — duplication.
- ❌ Outlets Stimulus — overkill pour un seul scope.

**Conséquence sur tasks.md** :
- T011 (navbar) : ajouter `data-action="click->sidebar#open"` sur le bouton Parties sans souci.
- T012 (insertion navbar dans layout) : le `<main>` du layout doit recevoir `data-controller="sidebar chat-drawer"`.
- T015 (refactor `show.html.erb`) : RETIRER `data-controller="sidebar chat-drawer"` du wrapper interne (déplacé en T012).

## Synthèse

| Domaine | Décision | Risque |
|---|---|---|
| Coordination overlays | Événements DOM customs | Bas — pattern Stimulus standard |
| Sidebar Parties | Recyclage `sidebar_controller` | Bas — markup conservé, classes ajoutées |
| Drawer Tibo desktop | `lg:flex` + 2 panes 60/40 | Bas — pure CSS Tailwind |
| DT viewer | iframe `Subject.dt_file` + bandeaux | Bas — modèle réel respecté |
| Navbar | Partial conditionnel dans layout | Bas |
| Tests | Driver desktop existant + 1 spec mobile sentinel | Bas |

**Aucune NEEDS CLARIFICATION restante.** Prêt pour Phase 1 (data-model + contracts + quickstart).

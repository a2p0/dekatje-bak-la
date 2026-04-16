# Notes de session — cadrage 041

**Session d'origine** : 2026-04-16
**But** : fournir aux sessions futures (ou à un dev qui reprend) le contexte qui a mené à cette spec, au-delà du "quoi" capturé dans `spec.md`.

## Comment on est arrivés ici

Le point de départ n'était **pas** ces 3 bugs. Le backlog proposait 3 items :

1. Tuning prompt tuteur (040 retry) — pris par une autre instance Claude en parallèle.
2. QA manuelle Vague 5.
3. **Teacher pages redesign (027)** — choisi.

Dans le cadrage de 027, on a dispatché **3 agents d'audit en parallèle** (UI Designer, UX Architect, Accessibility Auditor) sur les pages teacher existantes, comparées au design system appliqué aux pages student (branche 025 mergée).

## Résultats clés des audits

**Convergence** : `teacher/subjects/show` identifiée comme page pilote idéale par UI et UX indépendamment (densité, CTA dispersés, 4 sous-partials à refondre).

**Mais les audits ont aussi révélé 3 vrais bugs produit (P0)** qui n'ont rien à voir avec le design :

- **P0-a — Credentials éphémères** : bandeau `@generated_credentials` rendu une fois puis `session.delete` → rafraîchir = perte des mots de passe en clair → reset massif. L'export PDF existe déjà, il suffit d'exposer un bouton dans le bandeau. (`app/views/teacher/classrooms/show.html.erb:18-51`, `app/controllers/teacher/classrooms_controller.rb:30`)

- **P0-b — Aucune action `destroy` pour Subject/Classroom** : pas de route REST, pas de bouton UI. Un sujet créé par erreur n'a aucun recours côté utilisateur.

- **P0-c — Feedback extraction opaque** : spinner "Extraction en cours…" sans aucune info temporelle. L'enseignant ferme l'onglet par impatience (extraction dure 1-3 min).

## Décision de cadrage (pourquoi 041 existe)

Plutôt que de tout mélanger dans 027 (refonte visuelle), on a séparé :

| Périmètre | Branche | Statut |
|---|---|---|
| **Bugs produit P0** | **041 (cette feature)** | **En cours** |
| Refonte visuelle `subjects/show` + infra composants (FormField, Table, EmptyState, SectionHeader, Accordion) | 027 (reportée) | Pas démarrée |
| Destroy Classroom (soft-delete + cascade Students/Sessions) | 042 (reportée) | Pas démarrée |
| Quick wins a11y transverses (contrastes text-slate-500, aria-hidden SVG, iframe titles, scope tables) | 027 ou PR dédiée | Pas démarrée |

**Scope α choisi pour 041** (vs β qui incluait destroy Classroom + vues archivés) : on règle les vrais blocages rapidement, le reste peut attendre.

## Ce qu'on a vérifié dans le code avant d'écrire la spec

- `Subject` a déjà `discarded_at` colonne + `scope :kept` (`app/models/subject.rb:32`). **Pas de gem `discarded` installée** — c'est un pattern maison. `Question` fait pareil.
- Attention piège : `Subject` a un enum `status: archived` **différent** du soft-delete `discarded_at`. L'enum est un state pédagogique, le `discarded_at` est la suppression utilisateur.
- `ExtractionJob` n'a **pas** de colonne `started_at`. Colonnes : `id, created_at, error_message, exam_session_id, provider_used, raw_json, status, subject_id, updated_at`. Décision : utiliser `updated_at` comme proxy du passage à processing (documenté R3 dans research.md).
- Route `teacher_classroom_export_path(..., format: :pdf)` existe déjà (`config/routes.rb:12`, `resource :export, only: [ :show ], module: "classrooms"`). Pas de modif du service d'export.
- Projet n'utilise pas Pundit — autorisation via scoping `current_teacher.subjects`.

## Choix d'implémentation non-évidents

- **Durcissement de `set_subject`** (T009) : passe de `current_teacher.subjects.find_by(id: params[:id])` à `current_teacher.subjects.kept.find_by(id: params[:id])`. **Change aussi `show`** → un enseignant qui tape l'URL d'un sujet archivé reçoit "Sujet introuvable.". Accepté dans scope α, à revoir si besoin d'une vue "archivés" (→ feature ultérieure).
- **Style du bouton "Archiver"** : pas de variant `:danger` ajoutée à `ButtonComponent` (c'est du design system, scope 027). On utilise un `button_to` + classes inline `text-red-600 underline` — cohérent avec la "Supprimer la session" existante à `subjects/show.html.erb:36-40`.
- **Pas de test de download réel** pour US1 : on vérifie juste la présence du lien et son href. Capybara-Selenium pour download est fragile/lent, et l'export PDF lui-même est testé ailleurs (R7).

## Référence — 10 recommandations UI hors scope 041

Pour la future 027, les 10 recommandations de l'UI Designer (à relire avant de commencer 027) :

1. Retirer `max-w-6xl mx-auto px-4 py-6` de `layouts/teacher.html.erb:38`.
2. Câbler slot `breadcrumb` de `NavBarComponent` sur toutes les pages teacher.
3. Créer `FormFieldComponent` (labels + inputs + hints + errors).
4. Étendre `ButtonComponent` avec variants `:danger` et `:emerald`.
5. Créer `SectionHeaderComponent` (eyebrow indigo + h2 + actions).
6. Créer `TableComponent` (thead/tbody/scope/caption + empty slot).
7. Créer `EmptyStateComponent` (card centrée + CTA).
8. Passer toutes Card teacher à `variant: :glow`, bg-white/80 + border indigo-500/15.
9. Créer `AccordionComponent` (summary + chevron animé).
10. Remplacer le bloc credentials de `classrooms/show:19-50` par un `AlertComponent` (variant warning).

## Référence — Barrières a11y transverses (audit B1-B29)

**Quick wins pre-refonte (2-3h)** :
- B1 : skip link `layouts/teacher.html.erb:26` manque `focus:top-2 focus:left-2`.
- B3-B4 : tables sans `scope="col"` ni `<caption>` (classrooms/show:28-30, classrooms/show:93-95, subjects/index:16-21).
- B7 : `#extraction-status` sans `aria-live` → **traité dans US3 de 041**.
- B12 : `text-slate-500` sur `bg-slate-50` = 3.68:1 → fail AA. 20+ occurrences, remplacer par `text-slate-600`.
- B18 : iframes PDF sans `title` (parts/show:86-92, 127-143).
- B29 : `text-red-500` sur `bg-slate-50` = 3.77:1 → fail AA. Remplacer par `text-red-600` (on utilise déjà `text-red-600` dans 041 pour "Archiver" — cohérent).

## Pour reprendre l'implémentation

Lire dans l'ordre :
1. `CLAUDE.md` (racine) — stack, modèle, conventions.
2. `.specify/memory/constitution.md` — contraintes NON-NEGOTIABLE (surtout IV : tests TDD, CI autoritative).
3. `specs/041-teacher-p0-bugs/spec.md` — les 3 user stories + FR/SC.
4. `specs/041-teacher-p0-bugs/plan.md` — constitution check, structure fichiers touchés.
5. `specs/041-teacher-p0-bugs/research.md` — 8 décisions R1-R8, pourquoi chaque choix.
6. `specs/041-teacher-p0-bugs/quickstart.md` — code à copier-coller + specs.
7. `specs/041-teacher-p0-bugs/tasks.md` — **enchaîner T001 → T020**.

La commande d'enchaînement : `/speckit.implement` (ou exécuter manuellement task par task).

## Risque d'interférence avec l'autre worktree

Les deux working trees partagent :
- PostgreSQL (Neon pooled) et Redis (local) — **ne pas lancer `rails server` dans les deux en même temps** ; les specs Rails sont OK (transactions).
- `MEMORY.md` dans `~/.claude/projects/…/memory/` — concurrent writes possibles mais rares.

Ne partagent PAS :
- Working dir / index / branches (worktrees distincts).
- Contextes de conversation Claude.

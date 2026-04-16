---
description: "Task list — Tuning itératif du prompt tuteur"
---

# Tasks: Tuning itératif du prompt tuteur

**Input**: Design documents from `/specs/038-tutor-prompt-tuning/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md, hypotheses.md

**Tests** : non régression via spec unitaire `build_context_spec` (doit rester vert) ; **validation qualitative = sim LLM** (pas TDD classique, voir Plan §Constitution Check §IV).

**Organization** : les 3 user stories correspondent aux 3 critères à améliorer. Les 5 hypothèses (H1-H5) de `research.md` sont distribuées dans les US selon le critère qu'elles ciblent principalement :

- **US1 Guidage** : H2 (questions verbe+objet), H5 (request_hint systématique)
- **US2 Process** : H1 (transition systématique)
- **US3 Focalisation** : H3 (refus méta), H4 (validation conditionnelle)

**Règle d'itération** (FR-006) : chaque H passe par sim réduite + décision KEEP/REVERT avant la suivante.

## Format: `[ID] [P?] [Story] Description`

- **[P]** : non applicable ici (toutes les H modifient le même fichier `build_context.rb`)
- **[Story]** : US1 / US2 / US3
- Chemins absolus depuis la racine du projet Rails

---

## Phase 1: Setup

**Purpose** : préparer l'environnement d'itération.

- [ ] T001 Vérifier que la CI est verte sur `main` (baseline) via `gh run list --limit 1`
- [ ] T002 Vérifier que la branche locale `038-tutor-prompt-tuning` existe et est à jour — `git branch --show-current`

---

## Phase 2: Foundational

**Purpose** : aucun prérequis bloquant — le code est opérationnel (PR #49 mergée). Cette phase sert de checkpoint avant de commencer.

- [ ] T004 Lancer une sim réduite **de contrôle** (sans modification) pour vérifier que la baseline est reproductible et que le workflow tourne depuis la branche. Config : `questions=A.1, profiles=bon_eleve,eleve_en_difficulte, tuteur/élève=Haiku 4.5, juge=Sonnet 4.6`. Enregistrer le run_id dans `hypotheses.md` section "Baseline control".
- [ ] T005 Vérifier que `bundle exec rspec spec/services/tutor/build_context_spec.rb` passe (0 failure) sur la branche.

**Checkpoint** : si T004 donne des scores radicalement différents de la baseline `24503225082` (delta > 0.5 pt sur un critère), **stop** : diagnostiquer avant de modifier le prompt (variance modèle ? bug sim ?). Sinon continuer.

---

## Phase 3: US2 — Respect du process (Priority: P1)

**Goal** : le tuteur appelle `transition` via outil avant tout texte, sortant d'`idle` dès le tour 1.

**Independent Test** : sim réduite — au moins 1 des 2 conversations doit atteindre `phase_rank >= 2` (greeting+reading), et le 1er message assistant doit *ne pas* annoncer "je vais d'abord passer à..." en texte libre.

Pourquoi US2 avant US1 : sans Process, le tuteur ne progresse pas dans les phases donc l'effet de H2/H5 sur le guidage serait masqué (on n'arrive même pas en `guiding`).

### Implementation for US2

- [ ] T006 [US2] Modifier `app/services/tutor/build_context.rb` section `[UTILISATION DES OUTILS]` : ajouter la directive **IMPÉRATIF** décrite dans `research.md` §H1 (transition comme PREMIER acte, avant tout texte). Commit `refactor(tutor-prompt): H1 — call transition before any text`.
- [ ] T007 [US2] Lancer sim réduite via `gh workflow run tutor_simulation.yml --ref 038-tutor-prompt-tuning -f subject_id=1 -f turns=5 -f questions=A.1 -f profiles=bon_eleve,eleve_en_difficulte -f tutor_model=anthropic/claude-haiku-4.5 -f student_model=anthropic/claude-haiku-4.5 -f judge_model=anthropic/claude-sonnet-4.6`
- [ ] T008 [US2] Télécharger artefact, agréger scores avec le one-liner de `quickstart.md` §2, remplir entrée H1 dans `specs/038-tutor-prompt-tuning/hypotheses.md`
- [ ] T009 [US2] Décision KEEP ou REVERT selon critère : gain ≥ 0.3 sur process ou rank ET pas de régression ≥ 0.2 ailleurs. Si REVERT : `git revert <commit T006>`.

**Checkpoint** : H1 statué. Phase rank et process doivent progresser si KEEP.

---

## Phase 4: US1 — Guidage progressif (Priority: P1)

**Goal** : en phase `guiding`, le tuteur formule des questions ciblées (verbe+objet) et enregistre les indices via `request_hint`.

**Independent Test** : sim réduite — ratio des messages assistant commençant par un verbe d'action orienté (Identifie, Repère, Cite, Relève, Compare) ≥ 0.7 en phase `guiding`.

### Implementation for US1

- [ ] T010 [US1] Modifier `build_context.rb` section `[RÈGLES PÉDAGOGIQUES]` : ajouter format question obligatoire (H2) avec 2 exemples positifs + 1 négatif (few-shot court). Commit `refactor(tutor-prompt): H2 — verb+object questions in guiding`.
- [ ] T011 [US1] Sim réduite + agrégation + remplir H2 dans hypotheses.md
- [ ] T012 [US1] Décision KEEP / REVERT (même critère)
- [ ] T013 [US1] (si budget restant) Modifier `build_context.rb` section `[UTILISATION DES OUTILS]` : H5 (request_hint systématique en guiding). Commit `refactor(tutor-prompt): H5 — mandatory request_hint in guiding`.
- [ ] T014 [US1] Sim réduite + agrégation + remplir H5
- [ ] T015 [US1] Décision KEEP / REVERT

**Checkpoint** : guidage doit progresser vers ≥ 4.0 si KEEP.

---

## Phase 5: US3 — Focalisation (Priority: P2)

**Goal** : le tuteur refuse les dérives méta et valide uniquement les faits sourcés.

**Independent Test** : sim réduite avec profil `eleve_hors_sujet` — le tuteur recadre dans le 1er message de réponse à une dérive, ne valide pas d'affirmation non sourcée.

### Implementation for US3

- [ ] T016 [US3] Modifier `build_context.rb` section `[RÈGLES PÉDAGOGIQUES]` : ajouter H3 (refus méta) — 2-3 lignes directes.  Commit `refactor(tutor-prompt): H3 — reject meta-discussion`.
- [ ] T017 [US3] Sim réduite avec `profiles=eleve_hors_sujet,bon_eleve` + agrégation + remplir H3
- [ ] T018 [US3] Décision KEEP / REVERT
- [ ] T019 [US3] (si budget restant) Modifier `build_context.rb` : H4 (validation conditionnelle). Commit `refactor(tutor-prompt): H4 — validate only sourced claims`.
- [ ] T020 [US3] Sim réduite + agrégation + remplir H4
- [ ] T021 [US3] Décision KEEP / REVERT

**Checkpoint** : focalisation doit progresser vers ≥ 4.0 si KEEP.

---

## Phase 6: Polish & Validation

- [ ] T022 Mettre à jour `spec/services/tutor/build_context_spec.rb` : ajouter les assertions structurelles pour chaque section `[…]` conservée (H1-H5 appliquées). Garder vert.
- [ ] T023 Lancer la full suite tuteur : `bundle exec rspec spec/services/tutor/` — 0 failure attendu (SC-008).
- [ ] T024 Rubocop sur fichiers modifiés : `bundle exec rubocop app/services/tutor/build_context.rb spec/services/tutor/build_context_spec.rb`
- [ ] T025 **Sim complète de validation** : `questions=A.1,A.2,A.3` × 5 profils × 5 tours via `gh workflow run tutor_simulation.yml --ref 038-tutor-prompt-tuning`. Enregistrer run_id.
- [ ] T026 Télécharger artefact, agréger scores, remplir section "Run de validation complète" dans `hypotheses.md`.
- [ ] T027 Cocher les SC atteints dans `hypotheses.md`. Bilan budget vs SC-007 ($2).
- [ ] T028 Push branche + ouvrir PR vers main avec rapport final dans la description. Attendre CI verte (SC-008).
- [ ] T029 Post-merge : mettre à jour la mémoire projet `project_llm_comparison.md` ou créer `project_tutor_prompt_tuning.md` avec le prompt final et les gains mesurés.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : pas de bloquant
- **Foundational (Phase 2)** : T004/T005 avant toute modification
- **US2 (Phase 3)** : AVANT US1 car sans Process, US1 ne peut pas être observé
- **US1 (Phase 4)** : après US2 (KEEP ou REVERT statué)
- **US3 (Phase 5)** : après US1
- **Polish (Phase 6)** : après les 3 US

### Ordering rationale

Toutes les modifs touchent le **même fichier** `build_context.rb`. Les tâches ne sont donc **pas parallélisables** — elles doivent être séquentielles pour permettre un KEEP/REVERT propre par H. Aucun `[P]` marker utilisé.

### Budget tracking (SC-007 : ≤ $2)

| Tâche | Coût estimé |
|---|---|
| T004 sim de contrôle | $0.05 |
| T007, T011, T014, T017, T020 (5 sims réduites) | $0.25 |
| T025 sim complète | $0.60 |
| **Total estimé** | **$0.90** |

Marge confortable pour 2-3 itérations supplémentaires si besoin.

---

## Implementation Strategy

### Ordre recommandé (MVP pragmatique)

1. Setup + baseline control (T001-T005) — **confiance zéro avant d'itérer**
2. **US2 H1** — débloquer le process en priorité
3. **US1 H2** — plus gros levier sur guidage
4. **US3 H3** — focalisation + recadrage
5. (si SC pas atteints) **H4 et/ou H5** selon les scores restants
6. Polish + validation complète

### Critère d'arrêt anticipé

Si à tout moment :
- **3 H consécutives revert** : stop, revenir à la baseline, réévaluer l'approche.
- **Budget ≥ $1.5** et SC-001..SC-003 **tous atteints** : skip les H restantes, aller direct à Phase 6.
- **Budget ≥ $1.8** sans gain significatif : stop, accepter prompt actuel.

---

## Notes

- Une H = un commit. Un REVERT = un second commit (pas d'amend).
- Les SC se mesurent sur **sim complète** uniquement (T025). Les sims réduites sont un signal, pas une preuve.
- Le spec unitaire `build_context_spec` est le garde-fou structurel — toute nouvelle section ajoutée doit y avoir une assertion `include(…)`.
- La cible `≤ 500 tokens ajoutés` au prompt n'est pas chiffrée ; indicatif pour éviter la dérive.

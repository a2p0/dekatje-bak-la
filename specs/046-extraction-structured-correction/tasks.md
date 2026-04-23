# Tasks: Extraction — Structured Correction en production

**Input**: Design documents from `/specs/046-extraction-structured-correction/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**TDD**: Oui — constitution IV impose spec avant implémentation. Chaque phase suit : spec RED → impl GREEN → refactor.

**Organisation**: Tâches groupées par user story pour permettre une implémentation et validation indépendantes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut tourner en parallèle (fichiers différents, pas de dépendances)
- **[Story]**: User story concernée (US1, US2, US3)

---

## Phase 1: Setup (Aucune — infrastructure existante)

**Aucune tâche de setup nécessaire** : le champ `structured_correction` en DB existe déjà
(migration 043), `AiClientFactory`, `ResolveApiKey` et `ExtractQuestionsJob` sont en place.

**Checkpoint** : Prêt pour les phases user story.

---

## Phase 2: Foundational (Service `EnrichStructuredCorrection`)

**Purpose**: Service de base réutilisé par US1 et US2. Doit être complet avant de commencer les phases US.

**⚠️ CRITIQUE** : US1 (intégration job) et US2 (rake task) dépendent tous les deux de ce service.

- [X] T001 Écrire `spec/services/enrich_structured_correction_spec.rb` — 3 cas : LLM retourne JSON valide → ok:true ; JSON malformé → ok:false avec error ; Faraday::TimeoutError → ok:false avec error (WebMock)
- [X] T002 Implémenter `app/services/enrich_structured_correction.rb` — extraire SYSTEM_PROMPT et `build_user_message` verbatim de `tmp/poc_043_enrich.rb`, pattern Result struct, rescue StandardError → Result(ok: false)
- [X] T003 Vérifier que les specs T001 passent au GREEN avec l'implémentation T002

**Checkpoint** : `bundle exec rspec spec/services/enrich_structured_correction_spec.rb` → vert

---

## Phase 3: User Story 1 — Extraction automatique en 2 passes (Priority: P1) 🎯 MVP

**Goal**: Tout nouveau sujet uploadé bénéficie automatiquement de la structured correction après extraction.

**Independent Test**: Uploader un sujet PDF + corrigé → vérifier en DB que les `answers` ont `structured_correction` non-null après que le job se termine.

### Specs pour US1

> **Écrire les specs AVANT l'implémentation — vérifier qu'elles sont RED**

- [X] T004 [P] [US1] Écrire `spec/services/enrich_all_answers_spec.rb` — cas : 3 answers dont 1 erreur API → enriched:2 errors:1 jamais d'exception levée ; toutes réussies → enriched:3 ; answer déjà enrichie → skippée (structured_correction non-null ignorée)
- [X] T005 [P] [US1] Mettre à jour `spec/jobs/extract_questions_job_spec.rb` — ajouter : après extraction réussie, `EnrichAllAnswers` est appelé avec subject/api_key/provider ; si `EnrichAllAnswers` lève une exception non capturée, le job termine quand même (rescue existant)

### Implémentation pour US1

- [X] T006 [US1] Implémenter `app/services/enrich_all_answers.rb` — itère `subject.parts.includes(questions: :answer)`, filtre `structured_correction.nil?`, appelle `EnrichStructuredCorrection`, persiste si ok, logue si erreur, ne lève jamais d'exception, retourne `{enriched:, skipped:, errors:}`
- [X] T007 [US1] Modifier `app/jobs/extract_questions_job.rb` — ajouter `EnrichAllAnswers.call(subject: subject.reload, api_key: resolved.api_key, provider: resolved.provider)` après `PersistExtractedData.call(...)`, dans le bloc `begin` existant (les erreurs non capturées remontent au rescue existant)
- [X] T008 [US1] Vérifier que les specs T004 et T005 passent au GREEN

**Checkpoint** : `bundle exec rspec spec/services/enrich_all_answers_spec.rb spec/jobs/extract_questions_job_spec.rb` → vert

---

## Phase 4: User Story 2 — Rétro-enrichissement via rake task (Priority: P2)

**Goal**: Enrichir les subjects existants en DB sans intervention manuelle, de manière idempotente.

**Independent Test**: `bundle exec rake subjects:enrich_structured_correction[1]` sur le subject CIME → toutes ses answers ont `structured_correction` non-null.

### Specs pour US2

- [X] T009 [US2] Écrire `spec/tasks/subjects_enrich_spec.rb` — cas : subject avec 2 answers nil + 1 déjà enrichie → enrichit 2, skip 1 ; subject inexistant → erreur claire ; sans argument → traite tous les subjects avec answers nil
- [X] T010 [US2] Vérifier que les specs T009 sont RED avant implémentation

### Implémentation pour US2

- [X] T011 [US2] Créer `lib/tasks/subjects.rake` — namespace `:subjects`, task `:enrich_structured_correction` avec arg optionnel `[:subject_id]`, appelle `ResolveApiKey.call(user: subject.owner)` puis `EnrichAllAnswers.call(...)`, filtre idempotent via `Answer.where(structured_correction: nil)`
- [X] T012 [US2] Vérifier que les specs T009 passent au GREEN

**Checkpoint** : `bundle exec rspec spec/tasks/subjects_enrich_spec.rb` → vert

---

## Phase 5: User Story 3 — Feedback de progression (Priority: P3)

**Goal**: La rake task affiche une progression lisible et un résumé final.

**Independent Test**: Lancer la rake task → vérifier la sortie console contient le nom du subject, les compteurs et un résumé global.

*Note* : US3 est déjà partiellement couverte par US2 — la rake task de T011 inclut déjà les `puts` de base. Cette phase vérifie et complète le format de sortie.

- [X] T013 [US3] Vérifier la sortie console de `lib/tasks/subjects.rake` : chaque subject affiche nom + compteurs enrichies/skippées/erreurs ; résumé final total — ajuster si incomplet
- [X] T014 [US3] Mettre à jour `spec/tasks/subjects_enrich_spec.rb` — cas : vérifier que la sortie stdout contient le nom du subject et les compteurs (via `expect { task.invoke }.to output(/CIME.*enrichie/).to_stdout`)

**Checkpoint** : Output rake task lisible et conforme au quickstart.md

---

## Phase 6: Polish & Validation finale

- [ ] T015 [P] Vérifier que `Tutor::BuildContext` utilise bien `structured_correction` si présent — lire `app/services/tutor/build_context.rb` et confirmer le fallback (043 déjà mergé, vérification uniquement — pas de modif attendue)
- [ ] T016 Lancer la suite de specs complète : `bundle exec rspec spec/services/enrich_structured_correction_spec.rb spec/services/enrich_all_answers_spec.rb spec/jobs/extract_questions_job_spec.rb spec/tasks/subjects_enrich_spec.rb`
- [ ] T017 [P] Lancer le rétro-enrichissement réel sur le subject CIME (ID=1) en développement : `bundle exec rake subjects:enrich_structured_correction[1]` — vérifier le résumé et inspecter 2-3 `structured_correction` en DB
- [ ] T018 Commit `feat(046): pipeline extraction 2 passes — structured_correction auto`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 2 (Foundational)** : Aucune dépendance — commence immédiatement
- **Phase 3 (US1)** : Dépend de Phase 2 (T001-T003 complets)
- **Phase 4 (US2)** : Dépend de Phase 2 (utilise `EnrichAllAnswers` de US1 via T006)
- **Phase 5 (US3)** : Dépend de Phase 4 (complète la rake task de T011)
- **Phase 6 (Polish)** : Dépend de toutes les phases précédentes

### User Story Dependencies

- **US1 (P1)** : Peut démarrer après Phase 2 — pas de dépendance sur US2/US3
- **US2 (P2)** : Peut démarrer en parallèle avec US1 si `EnrichAllAnswers` (T006) est disponible, ou après US1
- **US3 (P3)** : Extension de US2 — dépend de T011

### Dépendances intra-phase

```
T001 → T002 → T003 (séquentiel — spec RED → impl → GREEN)
T003 → T004, T005 (US1 peut démarrer)
T004, T005 → T006 → T007 → T008
T006 → T009 → T010 → T011 → T012 (US2)
T011 → T013 → T014 (US3)
T008, T012, T014 → T015, T016, T017 → T018
```

---

## Parallel Opportunities

```
# Phase 2 — séquentiel (spec → impl → green)
T001 → T002 → T003

# Phase 3 — specs en parallèle avant impl
T004 [P] et T005 [P] peuvent s'écrire en parallèle

# Phase 6 — polish en parallèle
T015 [P] et T017 [P] indépendants
```

---

## Implementation Strategy

### MVP (US1 seulement)

1. Phase 2 : `EnrichStructuredCorrection` (T001-T003)
2. Phase 3 : `EnrichAllAnswers` + intégration job (T004-T008)
3. **VALIDER** : extraction complète en dev avec un vrai PDF → answers enrichies en DB

### Livraison complète

1. MVP → Phase 4 (rake task rétro) → Phase 5 (feedback) → Phase 6 (polish)
2. Chaque phase testable indépendamment

---

## Notes

- Le SYSTEM_PROMPT d'enrichissement est extrait **verbatim** de `tmp/poc_043_enrich.rb` — ne pas le réécrire
- `EnrichAllAnswers` ne lève **jamais** d'exception — toutes les erreurs sont loguées et comptées
- La rake task filtre sur `structured_correction: nil` — idempotente par construction
- `BuildContext` (tuteur) n'est pas modifié — 043 a déjà câblé le fallback
- Aucune migration nécessaire — champ déjà présent depuis 043

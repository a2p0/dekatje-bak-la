# Phase 1 — Data Model

**Feature** : Teacher P0 bug fixes
**Branch** : `041-teacher-p0-bugs`
**Date** : 2026-04-16

## Aucune migration

Cette feature n'introduit **aucune nouvelle table ni aucune nouvelle colonne**. Elle s'appuie entièrement sur des champs existants.

## Entités concernées (en lecture)

### Subject

```
subjects
├── id                  (PK)
├── owner_id            (FK User)
├── exam_session_id     (FK ExamSession)
├── specialty           (enum)
├── status              (enum: draft|pending_validation|published|archived)
├── discarded_at        (timestamp, nullable)  ← UTILISÉ pour soft-delete
├── created_at
└── updated_at
```

**Scope existant** (`app/models/subject.rb:32`) :

```ruby
scope :kept, -> { where(discarded_at: nil) }
```

**Utilisation dans US2** :

- Action `Teacher::SubjectsController#destroy` → `@subject.update!(discarded_at: Time.current)`
- Aucune modification du schéma, aucune nouvelle méthode modèle à ajouter.

**Note sur l'enum `status: archived`** : cet enum est sémantiquement distinct de `discarded_at`. Il représente un statut pédagogique (sujet retiré des élèves mais visible enseignant). Le soft-delete via `discarded_at` représente une archive utilisateur (sujet invisible pour l'enseignant sauf restauration future). **Les deux coexistent sans conflit.**

### ExtractionJob

```
extraction_jobs
├── id                  (PK)
├── subject_id          (FK Subject)
├── exam_session_id     (FK ExamSession)
├── status              (enum: pending|processing|done|failed)
├── provider_used       (enum: teacher|server)
├── raw_json            (JSONB, nullable)
├── error_message       (text, nullable)
├── created_at
└── updated_at          ← UTILISÉ pour indication temporelle
```

**Utilisation dans US3** :

- Vue `teacher/subjects/_extraction_status.html.erb` affiche `time_ago_in_words(job.updated_at)` quand `job.processing?`
- Aucune nouvelle colonne.

### Classroom

**Aucune modification.** US1 réutilise juste la route existante `teacher_classroom_export_path(@classroom, format: :pdf)`.

## Relations et contraintes

Aucune contrainte de FK ou validation nouvelle.

La contrainte implicite "seul le propriétaire archive" est garantie par scoping ActiveRecord (`current_teacher.subjects.kept.find_by(id: ...)`) — pas de constraint DB nouvelle.

## Cycle de vie (soft-delete Subject)

```
[active: discarded_at=nil] ──update(discarded_at: now)──> [archived: discarded_at=timestamp]
                                                                      │
                                                          (hors scope) restauration = update(discarded_at: nil)
```

**Effets observables après archivage** :

- `Subject.kept` exclut le sujet.
- `current_teacher.subjects.kept` exclut le sujet (listes enseignant).
- Les relations existantes (Part, Question, ClassroomSubject, StudentSession) **restent intactes** — `has_many ... dependent: :destroy` ne se déclenche pas sur un soft-delete. Décision cohérente avec les autres soft-deletes du projet (Question).
- Les fichiers attachés (PDFs) restent sur le stockage — `dependent: :destroy` des attachements ActiveStorage ne se déclenche pas non plus.

**Effets non-observables** (reportés) :

- Aucune purge automatique n'est prévue. Un job de nettoyage périodique est hors scope (potentielle feature future).
- Aucun filtrage côté élève n'est ajouté dans cette feature : si un élève a déjà une `StudentSession` sur un sujet qui vient d'être archivé, la session existe toujours. Côté UI élève, le sujet apparaîtra tant que la session est active (comportement accepté : les élèves qui ont commencé peuvent finir).

## Invariants

- `Subject.kept.count + Subject.where.not(discarded_at: nil).count == Subject.count` (tautologie).
- Archive réversible : `discarded_at` est un timestamp, donc restauration possible en DB (`UPDATE subjects SET discarded_at = NULL WHERE id = ?`). Pas d'UI de restauration dans cette feature (hors scope).

## Impact sur les seeds et fixtures

Aucun. Les factories existantes (`FactoryBot.build(:subject)`) ne créent pas de sujets avec `discarded_at` non-nil par défaut. Le test US2 créera un subject puis appellera le destroy, sans FactoryBot spécifique.

## Résumé

| Entité | Lecture | Écriture | Migration |
|---|---|---|---|
| Subject | `kept` scope | `update!(discarded_at: Time.current)` | ❌ |
| ExtractionJob | `updated_at` | ❌ | ❌ |
| Classroom | ❌ | ❌ | ❌ |

**Zéro migration. Zéro nouvelle colonne. Zéro nouvelle association.**

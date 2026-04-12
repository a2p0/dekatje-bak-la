# Research: Rails Conventions Audit Fix

**Date**: 2026-04-12 | **Branch**: `031-rails-conventions-fix`

## R1 — Inline `<script>` tags: quels scripts externaliser ?

**Decision**: Seul le script de la home page (access_code form redirect) sera externalisé en Stimulus controller. Les 3 scripts theme anti-flash (layouts) resteront inline.

**Rationale**: Les 3 scripts identiques dans `teacher.html.erb`, `student.html.erb`, `application.html.erb` sont des IIFE synchrones qui empêchent le flash dark→light. Ils DOIVENT s'exécuter avant le premier paint, donc avant que Stimulus ne soit chargé. Un Stimulus controller est trop tardif. En revanche, le `theme_controller.js` existant gère déjà le toggle dynamique — l'architecture est correcte.

Le script de `home.html.erb` (redirect vers `/<access_code>`) est un candidat parfait pour un Stimulus controller `access-code`.

**Alternatives considered**:
- Déplacer les 3 IIFE theme en Stimulus → rejeté (flash visuel garanti)
- Extraire les 3 IIFE en partial partagé → possible comme DRY, mais ne résout pas la "violation" puisque le `<script>` reste inline
- Mettre le theme IIFE dans un fichier JS séparé chargé en `<head>` sans defer → possible mais ajoute une requête HTTP bloquante

**Conclusion**: Corriger 1 violation sur 4 (home). Les 3 layouts gardent le `<script>` inline — c'est un faux positif de l'audit car c'est le pattern correct pour l'anti-flash. DRY possible via partial mais pas obligatoire.

## R2 — Views `.count` : quels usages extraire ?

**Decision**: 8 usages sur 10 seront extraits. Les 2 usages sur `errors.count` (Devise et subjects/new) sont des patterns Rails standard et restent en place.

| # | Fichier | Action |
|---|---------|--------|
| 1 | `_error_messages.html.erb` `resource.errors.count` | **Garder** — pattern i18n Rails standard |
| 2 | `classrooms/show.html.erb` `@students.count` | **Extraire** → `@students.size` (relation déjà chargée) |
| 3 | `subjects/new.html.erb` `@subject.errors.count` | **Garder** — pattern form-error standard |
| 4 | `classrooms/index.html.erb` `classroom.students.count` x2 | **Extraire** — pire cas, 2N queries. Counter cache ou eager load |
| 5 | `parts/show.html.erb` `.select(&:validated?).count` | **Extraire** → méthode modèle `Part#validated_questions_count` |
| 6 | `parts/show.html.erb` `@questions.count` | **Extraire** → `.size` |
| 7 | `_sidebar_part.html.erb` `.count { answered? }` | **Extraire** → `session_record.answered_count_for(part)` |
| 8 | `questions/show.html.erb` `.count { answered? }` | **Extraire** → même méthode que #7 |
| 9 | `_part_row.html.erb` `part.questions.kept.count` | **Extraire** → eager load ou counter cache |

## R3 — Services : pattern de retour des 4 services hash-enveloppe

**Decision**: Utiliser des Struct pour les services multi-valeurs, valeur directe pour mono-valeur, exception pour les erreurs.

| Service | Actuel | Nouveau | Callers à modifier |
|---------|--------|---------|-------------------|
| `ValidateStudentApiKey` | `{ valid: true/false, error: }` | `true` ou raise `InvalidApiKeyError` | `settings_controller.rb`, `spec/requests/student/settings_spec.rb` |
| `ResolveApiKey` | `{ api_key:, provider: }` | `Struct(:api_key, :provider)` | `extract_questions_job.rb`, `spec/jobs/extract_questions_job_spec.rb` |
| `ResetStudentPassword` | `{ password: }` | Retourner `password` directement (String) | `teacher/students_controller.rb`, `spec/services/reset_student_password_spec.rb` |
| `GenerateStudentCredentials` | `{ username:, password: }` | `Struct(:username, :password)` | `teacher/students_controller.rb` (create + bulk_create), `spec/services/generate_student_credentials_spec.rb` |

**Rationale**: Les Struct sont légers, typés, et `.api_key` est plus clair que `[:api_key]`. Pour mono-valeur (password), retourner la valeur directe est le plus simple. Pour les erreurs, lever une exception suit le pattern Rails et permet le rescue dans le controller.

## R4 — Services : pattern self.call → new.call

**Decision**: 11 services ont `self.call` inline à refactorer. 5 services (AiClientFactory + 4 TutorSimulation::*) gardent leur interface actuelle car ce ne sont pas des "service objects" au sens strict.

**AiClientFactory** : c'est un factory pattern avec `self.build`, pas un service object. Le renommer ou forcer `self.call` serait sémantiquement incorrect.

**TutorSimulation::*** (Judge, ReportGenerator, Runner, StudentSimulator) : ce sont des objets à état long (simulation multi-étapes), pas des services one-shot. Ils ont déjà une interface instance correcte (`new(...).run`, `new(...).evaluate`). Forcer `self.call` réduirait leur expressivité.

**Les 11 à refactorer** : AuthenticateStudent, BuildExtractionPrompt, ExportStudentCredentialsMarkdown, ExportStudentCredentialsPdf, ExtractQuestionsFromPdf, GenerateAccessCode, GenerateStudentCredentials, PersistExtractedData, ResetStudentPassword, ResolveApiKey, ValidateStudentApiKey.

## R5 — Jobs idempotence

**Decision**: Ajouter des gardes au début de `perform`.

| Job | Garde proposée |
|-----|---------------|
| `ExtractQuestionsJob` | `return if ExtractionJob.find(extraction_job_id).done?` — vérifier le statut avant de lancer l'extraction |
| `TutorStreamJob` | Vérifier si la conversation a déjà un message assistant non-streaming avant de streamer |

## R6 — Scopes à extraire des controllers

**Decision**: Créer des scopes nommés sur les modèles concernés.

| Scope | Modèle | Remplace |
|-------|--------|---------|
| `Part.specific` | Part | `parts.where(section_type: :specific)` (3 occurrences) |
| `Question.for_parts(parts)` | Question | `Question.kept.where(part: parts)` |
| `Question.for_subject(subject)` | Question | `Question.kept.joins(:part).where(parts: { subject_id: })` |
| `Question.with_ids(ids)` | Question | `Question.where(id: ids)` (si nécessaire) |

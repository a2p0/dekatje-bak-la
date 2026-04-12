# Feature Specification: Rails Conventions Audit Fix

**Feature Branch**: `031-rails-conventions-fix`  
**Created**: 2026-04-12  
**Status**: Draft  
**Input**: Corriger toutes les violations et warnings identifiés par l'audit /rails-conventions audit (13 violations, 75 warnings sur 6 domaines)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Les formulaires utilisent les helpers Rails modernes (Priority: P1)

En tant que développeur, je veux que tous les formulaires utilisent `form_with` au lieu de `form_for`/`form_tag` afin de suivre les conventions Rails 8 et d'avoir un comportement cohérent (soumission Turbo par défaut).

**Why this priority**: Les 9 violations `form_for`/`form_tag` sont les écarts les plus visibles. `form_with` est le standard depuis Rails 5.1 et le seul compatible nativement avec Turbo.

**Independent Test**: Vérifier que chaque formulaire se soumet correctement après la migration, incluant les formulaires Devise (login, register, reset password) et les formulaires custom (home search, student login).

**Acceptance Scenarios**:

1. **Given** un formulaire Devise utilisant `form_for`, **When** il est migré vers `form_with`, **Then** le login/register/reset password fonctionne identiquement
2. **Given** le formulaire de recherche sur la home page utilisant `form_tag`, **When** il est migré vers `form_with`, **Then** la recherche de classe par access_code fonctionne
3. **Given** le formulaire de login élève utilisant `form_tag`, **When** il est migré vers `form_with`, **Then** l'authentification élève fonctionne

---

### User Story 2 - Le JavaScript inline est externalisé en Stimulus controllers (Priority: P1)

En tant que développeur, je veux que le JavaScript inline de la home page soit externalisé en Stimulus controller afin de respecter le principe Hotwire-only de la constitution et d'avoir un code maintenable. Les 3 scripts theme anti-flash dans les layouts sont conservés (ils doivent s'exécuter avant Stimulus pour éviter un flash visuel — voir research.md R1).

**Why this priority**: 1 violation corrigée sur 4 identifiées (3 faux positifs justifiés). Le JS inline contourne le pipeline d'assets et n'est pas testable. La constitution impose "Hotwire Only".

**Independent Test**: Vérifier que le formulaire access_code sur la home page redirige correctement vers `/<code>` après externalisation.

**Acceptance Scenarios**:

1. **Given** le `<script>` inline dans la home page, **When** il est externalisé en Stimulus controller, **Then** le comportement interactif (redirect vers `/<code>`) est préservé

---

### User Story 3 - La logique métier est extraite des vues (Priority: P2)

En tant que développeur, je veux que les appels `.count`, `.where`, `.find` et la logique de filtrage soient déplacés des vues vers des helpers, presenters ou le controller afin de respecter la séparation des responsabilités.

**Why this priority**: 10 warnings — la logique métier dans les vues rend le code difficile à tester et à maintenir, et peut causer des requêtes N+1.

**Independent Test**: Vérifier que l'affichage des compteurs et données filtrées est identique dans chaque vue concernée.

**Acceptance Scenarios**:

1. **Given** une vue avec `.count` sur une association, **When** le comptage est déplacé dans le controller ou un helper, **Then** l'affichage est identique
2. **Given** une vue avec logique de filtrage (`.count` avec block), **When** la logique est extraite, **Then** le résultat affiché est le même

---

### User Story 4 - Les jobs sont idempotents (Priority: P2)

En tant que développeur, je veux que les jobs Sidekiq aient des gardes d'idempotence afin qu'un retry ne produise pas de données dupliquées ou de messages en double.

**Why this priority**: 2 warnings — les jobs sans idempotence peuvent causer des extractions dupliquées ou des messages tuteur en double sur retry.

**Independent Test**: Vérifier qu'un job exécuté deux fois avec les mêmes arguments produit le même résultat qu'une seule exécution.

**Acceptance Scenarios**:

1. **Given** un ExtractionJob déjà terminé (status: done), **When** le job est relancé, **Then** il retourne immédiatement sans ré-extraire
2. **Given** un TutorStreamJob pour une conversation qui a déjà une réponse assistant, **When** le job est relancé, **Then** il ne duplique pas le message

---

### User Story 5 - Les requêtes controllers sont extraites en scopes (Priority: P2)

En tant que développeur, je veux que les appels `where()` dans les controllers soient extraits en scopes nommés sur les modèles afin de centraliser la logique de requête et de la rendre réutilisable.

**Why this priority**: 7 warnings — les requêtes éparpillées dans les controllers dupliquent la logique et rendent les tests plus complexes.

**Independent Test**: Vérifier que chaque action de controller retourne les mêmes résultats après extraction en scopes.

**Acceptance Scenarios**:

1. **Given** un controller avec `parts.where(section_type: :specific)`, **When** c'est remplacé par un scope `parts.specific`, **Then** le comportement est identique
2. **Given** un controller avec `Question.kept.where(part: filtered_parts)`, **When** c'est remplacé par un scope, **Then** les questions filtrées sont les mêmes

---

### User Story 6 - Les modèles sont optimisés contre les N+1 (Priority: P2)

En tant que développeur, je veux que les méthodes fréquemment appelées soient mémorisées et que les associations soient eager-loadées pour éviter les requêtes N+1.

**Why this priority**: 6 warnings — `filtered_parts` dans StudentSession est appelé par 5+ méthodes sans mémoisation, et Subject délègue à exam_session sans eager loading.

**Independent Test**: Vérifier que le nombre de requêtes SQL est réduit pour les pages listant des sujets ou des sessions élèves.

**Acceptance Scenarios**:

1. **Given** une page affichant plusieurs student sessions, **When** `filtered_parts` est mémoisé, **Then** le nombre de requêtes SQL est réduit
2. **Given** une page listant des sujets, **When** `exam_session` est eager-loadé, **Then** pas de requêtes N+1 sur les délégations

---

### User Story 7 - Les services suivent le pattern self.call (Priority: P3)

En tant que développeur, je veux que tous les services suivent le pattern `self.call -> new(...).call` afin d'avoir une API cohérente et de pouvoir injecter des dépendances via le constructeur.

**Why this priority**: 16 warnings — la majorité des services ont la logique directement dans `self.call` comme méthode de classe. C'est fonctionnel mais incohérent avec la convention établie.

**Independent Test**: Vérifier que chaque service produit le même résultat après refactoring du pattern d'appel.

**Acceptance Scenarios**:

1. **Given** un service avec `self.call` comme class method body, **When** il est refactoré en `self.call -> new.call`, **Then** tous les callers fonctionnent identiquement
2. **Given** un service qui retourne un hash `{ password: ... }`, **When** il est refactoré pour retourner la valeur directe ou un struct, **Then** les callers sont mis à jour en conséquence

---

### User Story 8 - Les services retournent des valeurs directes (Priority: P3)

En tant que développeur, je veux que les services retournent des valeurs directes ou lèvent des exceptions au lieu de retourner des hash-enveloppes afin de simplifier le code appelant.

**Why this priority**: 4 warnings — les hash-enveloppes `{ success: ..., error: ... }` compliquent le code appelant et masquent les erreurs.

**Independent Test**: Vérifier que chaque caller de service gère correctement la nouvelle interface (valeur directe ou exception).

**Acceptance Scenarios**:

1. **Given** `ValidateStudentApiKey` qui retourne `{ valid: true/false }`, **When** il est refactoré pour retourner true ou raise, **Then** le controller gère correctement les deux cas
2. **Given** `ResolveApiKey` qui retourne `{ api_key:, provider: }`, **When** il retourne un struct ou deux valeurs, **Then** les callers sont mis à jour

---

### Edge Cases

- Que se passe-t-il si un formulaire Devise a des personnalisations (champs ajoutés, classes CSS) ? Elles doivent être préservées lors de la migration vers `form_with`.
- Comment gérer les `<script>` inline qui dépendent de variables Ruby interpolées ? Le Stimulus controller doit recevoir les données via `data-*` attributes.
- Que se passe-t-il si un scope est appelé avec des paramètres dynamiques ? Le scope doit accepter des arguments.
- Comment gérer la mémoisation dans `StudentSession` si l'objet est modifié entre les appels ? Utiliser `@filtered_parts = nil` dans les setters si nécessaire.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Système DOIT migrer tous les `form_for` et `form_tag` vers `form_with` dans les 9 vues identifiées
- **FR-002**: Système DOIT externaliser le `<script>` inline de la home page en Stimulus controller (les 3 scripts theme anti-flash dans les layouts sont conservés — voir research.md R1)
- **FR-003**: Système DOIT extraire la logique métier (`.count` avec block, `.select`, filtrage) des 8 vues identifiées vers des helpers ou le controller (les 2 usages `errors.count` sont des patterns Rails i18n standard conservés — voir research.md R2)
- **FR-004**: Système DOIT ajouter des gardes d'idempotence aux 2 jobs (extract_questions, tutor_stream)
- **FR-005**: Système DOIT extraire les 7 `where()` des controllers en scopes nommés sur les modèles
- **FR-006**: Système DOIT mémoiser `filtered_parts` dans `StudentSession` et eager-loader `exam_session` dans les requêtes Subject
- **FR-007**: Système DOIT refactorer les 11 services identifiés pour suivre le pattern `self.call -> new(...).call` (les 5 exclus — AiClientFactory + 4 TutorSimulation::* — ne sont pas des service objects, voir research.md R4)
- **FR-008**: Système DOIT refactorer les 4 services qui retournent des hash-enveloppes pour retourner des valeurs directes ou lever des exceptions

### Key Entities

- **Service Object**: Objet encapsulant une logique métier, avec interface `self.call` déléguant à une instance
- **Scope**: Méthode de classe ActiveRecord nommée, encapsulant une condition de requête réutilisable
- **Stimulus Controller**: Fichier JS suivant les conventions Stimulus, remplaçant le JS inline

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zéro occurrence de `form_for` ou `form_tag` dans les vues du projet (hors gems)
- **SC-002**: Zéro `<script>` inline dans les fichiers ERB du projet, hors scripts anti-flash theme dans les layouts (faux positifs justifiés)
- **SC-003**: Zéro logique métier (`.count` avec block, `.select`, `.where(`, `.find(`) directement dans les vues. Les patterns i18n standard (`errors.count`) sont exclus.
- **SC-004**: Tous les jobs retournent immédiatement sans effet de bord lorsqu'exécutés en double
- **SC-005**: Zéro `where()` direct dans les controllers (remplacés par des scopes)
- **SC-006**: Le nombre de requêtes SQL sur les pages student session et subject listing ne dépasse pas N+1 (vérifié par les logs)
- **SC-007**: Les 11 services identifiés exposent `self.call` déléguant à `new(...).call` (5 exclus justifiés)
- **SC-008**: Aucun service ne retourne de hash-enveloppe `{ success/valid/error: ... }`
- **SC-009**: La suite de tests existante passe à 100% après toutes les modifications

## Assumptions

- Les vues Devise sont déjà générées dans le projet (pas les vues par défaut de la gem)
- Les `<script>` inline contiennent du JS simple (pas de logique complexe nécessitant un framework)
- Les callers de services sont tous dans le projet (pas d'API externe consommant ces services)
- La mémoisation dans StudentSession n'a pas besoin d'invalidation car les instances sont courte durée (request-scoped)
- Les scopes extraits n'ont pas besoin d'être composables avec d'autres scopes existants au-delà de l'usage actuel

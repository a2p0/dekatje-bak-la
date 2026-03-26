# Research: DekatjeBakLa

**Branch**: `001-bac-training-app` | **Date**: 2026-03-26

## Décisions techniques

### Auth élève custom (bcrypt sans Devise)

**Decision**: Modèle `Student` distinct de `User`, avec `has_secure_password`, session gérée manuellement via `session[:student_id]`.
**Rationale**: RGPD mineurs — aucun email. Devise est surdimensionné (reset email, confirmation...). Bcrypt natif Rails suffit.
**Alternatives considered**: Devise avec champ email optionnel (rejeté : email obligatoire dans certains modules Devise), STI User/Student (rejeté : logique auth trop différente).

### Pipeline extraction PDF

**Decision**: `pdf-reader` gem pour extraction texte brut → prompt structuré → Claude API via Faraday → JSON parsé → persistence ActiveRecord.
**Rationale**: pdf-reader est léger et fiable pour PDFs natifs. Pas d'OCR au MVP. Claude API gère l'analyse sémantique.
**Alternatives considered**: PyPDF2 (Python, hors stack), Poppler (lourd, hors MVP), extraction directe sans intermédiaire (trop fragile).

### Multi-provider IA

**Decision**: `AiClientFactory` service qui instancie un client Faraday selon le provider (anthropic, openrouter, openai, google). Interface unifiée avec méthode `call(messages:, stream:)`.
**Rationale**: OpenRouter est un proxy universel — 1 intégration couvre des dizaines de modèles. Évite la prolifération de gems par provider.
**Alternatives considered**: gem `ruby-openai` (vendor lock-in), gem Anthropic officielle (un seul provider).

### Streaming SSE → Turbo Streams

**Decision**: `StreamAiResponse` service avec `response.stream` Rails + `ActionController::Live`. Chaque chunk SSE est broadcasté via `Turbo::StreamsChannel`.
**Rationale**: Natif Rails 8, pas de WebSocket séparé. Compatible avec Sidekiq pour les jobs non-streaming.
**Alternatives considered**: WebSocket ActionCable (plus complexe pour du one-shot streaming), polling (mauvaise UX).

### Chiffrement clés API

**Decision**: `encrypts :api_key` (ActiveRecord Encryption, Rails 7+). Clé de chiffrement dans `credentials.yml.enc`.
**Rationale**: Natif Rails, pas de gem externe. Transparent à l'usage. `RAILS_MASTER_KEY` en variable d'env Coolify.
**Alternatives considered**: `attr_encrypted` gem (externe, deprecated), chiffrement manuel (fragile).

### Génération access_code classe

**Decision**: Slug généré depuis `"#{specialty}-#{school_year}"` + suffixe si collision. Ex: `terminale-sin-2026`.
**Rationale**: Lisible par les élèves, mémorisable, unique par classe.
**Alternatives considered**: UUID (illisible), token aléatoire (non mémorisable).

### Sticky panel contexte élève

**Decision**: Stimulus controller `context-panel` avec un `<details>` HTML natif ou un drawer CSS. Contenu chargé via Turbo Frame au premier affichage puis mis en cache.
**Rationale**: Pas de JavaScript custom complexe. Turbo Frame gère le lazy loading.
**Alternatives considered**: Vue component (hors stack), panneau inline (prend trop de place).

### Export fiches connexion PDF

**Decision**: Gem `prawn` ou template HTML → PDF via `grover` (Chrome headless). À décider à l'implémentation.
**Rationale**: Prawn = léger, pas de dépendance Chrome. Grover = plus flexible pour mise en page.
**Alternatives considered**: CSV (pas imprimable directement), copier-coller manuel (non scalable).

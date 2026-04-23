# Research: Extraction — Structured Correction en production

## Décisions techniques

### 1. Service `EnrichStructuredCorrection` — périmètre et interface

**Decision**: Service dédié, appelé question par question, retournant un Result struct
(success/failure + payload). Interface :

```ruby
EnrichStructuredCorrection.call(answer:, api_key:, provider:)
# => Result.new(ok: true, structured_correction: {...})
# => Result.new(ok: false, error: "message")
```

**Rationale**: Isole la logique d'enrichissement. Réutilisable depuis le job Sidekiq
ET la rake task sans duplication. Le pattern `Result` struct (déjà utilisé dans
`ResolveApiKey`) est la convention du projet.

**Alternatives considered**: Méthode privée dans `ExtractQuestionsJob` — rejeté car non
testable unitairement et non réutilisable par la rake task.

---

### 2. Prompt d'enrichissement — réutiliser le POC verbatim

**Decision**: Extraire le `SYSTEM_PROMPT` et `build_user_message` du POC `poc_043_enrich.rb`
verbatim dans le service. Le prompt a été validé sur 7 questions réelles avec des résultats
conformes aux attentes pédagogiques.

**Rationale**: Le prompt POC est éprouvé (sim 043 validée, PR #57 mergée). Le réécrire
serait risqué sans nouvelle sim de validation.

**Alternatives considered**: Générer le `structured_correction` dans la passe 1
(amendement de `BuildExtractionPrompt`) — rejeté car le prompt d'extraction est déjà
très dense (~3000 tokens système), et la qualité de la structured correction bénéficie
d'un prompt focalisé avec moins de contexte concurrent.

---

### 3. Intégration dans `ExtractQuestionsJob` — après `PersistExtractedData`

**Decision**: Appel séquentiel question par question après la passe 1, dans le même
job Sidekiq. Pas de job séparé, pas de parallélisme.

```ruby
# Dans ExtractQuestionsJob#perform, après PersistExtractedData.call(...)
EnrichAllAnswers.call(subject: subject, api_key: resolved.api_key, provider: resolved.provider)
```

**Rationale**: La passe 2 est rapide (~0.05-0.10$/sujet, ~20-30s pour 20 questions
séquentielles). Un job séparé complexifierait l'orchestration et la gestion d'erreurs
sans bénéfice measurable à ce stade.

**Alternatives considered**: Job Sidekiq séparé `EnrichStructuredCorrectionJob` — utile
si la passe 2 devenait très longue ou devait être ré-exécutable indépendamment, mais
ajoute de la complexité pour MVP.

---

### 4. Dégradation gracieuse — stratégie fine-grained

**Decision**: Les erreurs de la passe 2 sont capturées question par question. Le job
se termine toujours en `done`. Les erreurs sont loggées avec `Rails.logger.warn`.
Aucune relance automatique de la passe 2 (le rétro-enrichissement via rake couvre
ce cas).

**Rationale**: La passe 1 (extraction principale) est la valeur critique. La passe 2
est un enrichissement additionnel. Faire échouer le job entier pour un enrichissement
partiel serait disproportionné.

---

### 5. Rake task — structure et idempotence

**Decision**: `rake subjects:enrich_structured_correction[ID]` (optionnel : ID subject).
Sans ID → tous les subjects publiés. Filtre idempotent : `Answer.where(structured_correction: nil)`.

**Rationale**: La rake task doit pouvoir être relancée sans risque après une erreur partielle.
Le filtre `structured_correction: nil` garantit que les questions déjà enrichies ne sont
pas appelées de nouveau.

**Alternatives considered**: Forcer le ré-enrichissement via un flag `FORCE=true` — utile
plus tard si on veut re-enrichir avec un prompt amélioré, mais hors scope MVP.

---

### 6. Provider utilisé pour la passe 2

**Decision**: Même provider/clé que la passe 1 (déjà résolu via `ResolveApiKey`).
Pas de fallback séparé pour la passe 2. Si le provider n'est pas Anthropic, l'enrichissement
est tout de même tenté (le prompt est provider-agnostic).

**Rationale**: Simplicité. Le teacher a configuré sa clé pour l'extraction — utiliser
la même pour l'enrichissement est cohérent.

---

### 7. `BuildContext` — aucun changement requis

**Decision**: `Tutor::BuildContext` utilise déjà `structured_correction` si présent
et fait le fallback sur `correction_text` si null (implémenté dans 043, PR #57).
Aucune modification nécessaire côté tuteur.

**Rationale**: La feature 046 est purement pipeline-side. Le tuteur consomme déjà
le format correctement.

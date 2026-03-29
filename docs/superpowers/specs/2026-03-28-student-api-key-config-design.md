# Design: Student API Key Configuration (F8)

**Date**: 2026-03-28
**Branch**: `008-student-api-key-config`
**Scope**: Page settings élève avec mode par défaut, configuration clé API multi-provider, validation de clé, dropdown modèles avec indicateurs coût

---

## Architecture

Page settings accessible depuis la sidebar élève. Configuration du mode par défaut (révision/tutorat), du provider IA, du modèle (dropdown dynamique par provider avec icônes coût), et de la clé API (chiffrée). Validation de clé via service dédié. Gestion erreurs quota déléguée au Mode 2 (task 10).

---

## Migration requise

`UpdateStudentsForApiConfig` :
- Supprimer colonnes `encrypted_api_key` et `encrypted_api_key_iv`
- Ajouter `api_key` (string) — chiffré via `encrypts :api_key`
- Ajouter `api_model` (string, default: nil)
- Ajouter `default_mode` (integer, default: 0)

---

## Routes

```ruby
scope "/:access_code", as: :student do
  # existing routes...
  get   "/settings",          to: "student/settings#show",     as: :settings
  patch "/settings",          to: "student/settings#update"
  post  "/settings/test_key", to: "student/settings#test_key", as: :test_key
end
```

---

## Modèles prédéfinis par provider

Constante `Student::AVAILABLE_MODELS` :

```ruby
AVAILABLE_MODELS = {
  "openrouter" => [
    { id: "qwen/qwen3-next-80b-a3b-instruct:free", label: "Qwen3 80B (gratuit)", cost: "free", note: "Lent, rate limit bas" },
    { id: "deepseek/deepseek-chat-v3-0324", label: "DeepSeek V3", cost: "$" },
    { id: "anthropic/claude-sonnet-4-5", label: "Claude Sonnet 4.5", cost: "$$" }
  ],
  "anthropic" => [
    { id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5", cost: "$" },
    { id: "claude-sonnet-4-5-20250514", label: "Claude Sonnet 4.5", cost: "$$" }
  ],
  "openai" => [
    { id: "gpt-4o-mini", label: "GPT-4o Mini", cost: "$" },
    { id: "gpt-4o", label: "GPT-4o", cost: "$$" }
  ],
  "google" => [
    { id: "gemini-2.0-flash", label: "Gemini 2.0 Flash", cost: "$" },
    { id: "gemini-2.5-pro-preview-06-05", label: "Gemini 2.5 Pro", cost: "$$$" }
  ]
}.freeze
```

Le modèle par défaut pour chaque provider est le premier de la liste (le moins cher).

---

## Controllers

### `Student::SettingsController`
- `show` — affiche le formulaire settings avec les valeurs actuelles
- `update` — met à jour default_mode, api_provider, api_model, api_key. Flash success, redirect to show.

### Validation de clé (Turbo Frame)
- Bouton "Tester la clé" envoie une requête PATCH dédiée ou POST vers une action `test_key`
- Route : `POST /:access_code/settings/test_key`
- Appelle `ValidateStudentApiKey.call(provider:, api_key:, model:)`
- Retourne résultat via Turbo Frame (succès vert / erreur rouge)

---

## Service

### `ValidateStudentApiKey`
- Utilise `AiClientFactory.build(provider:, api_key:)` existant
- Envoie un message minimal ("Réponds OK") au modèle sélectionné
- Retourne `{ valid: true }` ou `{ valid: false, error: "message" }`
- Gère les exceptions Faraday (timeout, 401, 402, 429)

---

## Vues

### `app/views/student/settings/show.html.erb`
Formulaire avec :
1. **Mode par défaut** : radio buttons
   - Révision autonome (correction seule)
   - Tutorat IA (nécessite clé API)
2. **Configuration IA** :
   - Provider : dropdown (OpenRouter, Anthropic, OpenAI, Google)
   - Modèle : dropdown dynamique, mis à jour par Stimulus quand le provider change. Chaque option affiche le label + icône coût (🆓, $, $$, $$$) + note éventuelle
   - Clé API : champ password avec bouton toggle show/hide
   - Bouton "Tester la clé" → résultat dans un Turbo Frame
3. **Bouton "Enregistrer"**

---

## Stimulus

### `settings_controller.js`
- Targets : provider select, model select, api key input, toggle button
- Action `providerChanged` : lit les modèles depuis `data-models` (JSON en data attribute), reconstruit les options du dropdown modèle
- Action `toggleApiKey` : bascule input type password/text

---

## Modèle Student (modifications)

```ruby
class Student < ApplicationRecord
  # existing...
  encrypts :api_key

  enum :default_mode, { revision: 0, tutored: 1 }

  AVAILABLE_MODELS = { ... }.freeze

  def default_model_for_provider
    AVAILABLE_MODELS[api_provider]&.first&.dig(:id)
  end

  def effective_model
    api_model.presence || default_model_for_provider
  end
end
```

---

## Sécurité

- `encrypts :api_key` — chiffrement Rails 8
- `filter_parameters` couvre déjà `_key` — pas de fuite dans les logs
- Champ password + toggle protège contre le shoulder surfing
- Settings scoped à `current_student` via BaseController
- Pas de validation format de clé côté serveur — le test de clé suffit

---

## Intégration Mode 2 (task 10)

Quand l'élève tente le tutorat :
- **Pas de clé configurée** → message "Configurez votre clé IA pour utiliser le tutorat" + lien vers `student_settings_path`
- **Crédits insuffisants** (402/429) → message "Crédits insuffisants sur votre compte [provider]. Vérifiez votre solde ou changez de provider." + lien settings. L'élève continue en Mode 1.

---

## Lien sidebar

Ajouter un lien "⚙ Réglages" en bas de la sidebar élève (`_sidebar.html.erb`), pointant vers `student_settings_path(access_code:)`.

---

## Structure des fichiers

```
db/migrate/
  TIMESTAMP_update_students_for_api_config.rb

app/models/
  student.rb (modifié)

app/controllers/student/
  settings_controller.rb

app/services/
  validate_student_api_key.rb

app/views/student/
  settings/show.html.erb
  questions/_sidebar.html.erb (modifié — ajout lien settings)

app/javascript/controllers/
  settings_controller.js

spec/models/
  student_spec.rb (modifié)

spec/services/
  validate_student_api_key_spec.rb

spec/requests/student/
  settings_spec.rb
```

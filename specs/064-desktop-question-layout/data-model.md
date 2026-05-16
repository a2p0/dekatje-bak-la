# Phase 1 — Data Model: Desktop Question Layout

**Feature** : 064-desktop-question-layout
**Date** : 2026-05-11

## Aucun changement de schéma

Cette feature est **strictement présentationnelle**. Aucune migration, aucune nouvelle table, aucune nouvelle colonne. La surface utilisée est en lecture seule.

## Surface utilisée (read-only)

### `Subject`

| Attribut | Type | Usage |
|---|---|---|
| `title` | string | Affiché dans navbar (logo zone) et breadcrumb |
| `exam` | enum | Affiché dans navbar (label sujet) |
| `specialty` | enum | Affiché dans navbar (label sujet) |
| `dt_file` | ActiveStorage | Iframe colonne droite (DT viewer) |
| `presentation_text` | text | Non utilisé directement (déjà dans la sidebar / contexte) |

### `Part`

| Attribut | Type | Usage |
|---|---|---|
| `number` | integer | Breadcrumb + sticky part header |
| `title` | string | Sticky part header + panneau contexte (drawer Tibo) |
| `objective_text` | text | Panneau contexte (drawer Tibo) |
| `section_type` | enum | Sticky part header (Commune / Spécifique) |

### `Question`

| Attribut | Type | Usage |
|---|---|---|
| `number` | string | Carte question + breadcrumb |
| `label` | text | Carte question + panneau contexte (drawer Tibo) |
| `context_text` | text | Carte mise en situation locale |
| `dt_references` | array(string) | Bandeau références dans DT viewer (ex: `["DT1", "DT2"]`) |
| `dr_references` | array(string) | Bandeau références dans DT viewer (ex: `["DR1"]`) |
| `answer` | has_one | Cartes correction (réponse + calcul + data hints) |

### `Answer`

| Attribut | Type | Usage |
|---|---|---|
| `correction_text` | text | Carte réponse (verte) |
| `explanation_text` | text | Carte détail calcul (verte outlined) |
| `data_hints` | JSONB `[{source, location}]` | Carte data hints (jaune outlined) + bandeau "donnée utile" du DT viewer |

**Note importante** : `data_hints[].source` est une chaîne libre (ex: `"DT1"`, `"tableau_sujet"`, `"enonce"`) et `data_hints[].location` est une chaîne descriptive libre (ex: `"ligne Consommation moyenne 30,5 l/100km"`). Pas de champ `page`. Le bandeau "donnée utile" affichera `"#{source} · #{location}"` ou un fallback.

### `StudentSession`

| Méthode | Usage |
|---|---|
| `progression` | JSON sur lequel les méthodes ci-dessous s'appuient |
| `answered?(question_id)` | Sélection du bloc correction vs CTA "Voir la correction" |
| `answered_count_for(questions)` | Barre de progression segmentée |

### `Conversation`

| Méthode | Usage |
|---|---|
| `active?` | Wiring du `tutor-chat` Stimulus controller |
| `messages` | Bulles dans le drawer |

## Helpers nouveaux (potentiels)

### `StudentHelper#primary_data_hint(question)`

Retourne `question.answer&.data_hints&.first` ou `nil`. Utilisé dans `_dt_viewer.html.erb` et `_data_hint_banner.html.erb`.

**Implémentation candidate** :
```ruby
def primary_data_hint(question)
  return nil unless question.answer
  hints = question.answer.data_hints
  return nil if hints.blank?
  hints.first
end

def data_hint_caption(hint)
  return nil unless hint.is_a?(Hash)
  source = hint["source"].presence
  location = hint["location"].presence
  return location if source.blank?
  return source if location.blank?
  "#{source} · #{location}"
end
```

### `StudentHelper#dt_references_for(question)`

Concatène `dt_references + dr_references` avec préfixe explicite si nécessaire. À évaluer en implémentation — peut être inutile si on les rend juste en boucle dans le partial.

## Aucune autre entité touchée

- Pas d'`ExtractionJob`, pas de `TutorState`, pas de `User`, pas de `Classroom` lecture.
- Pas de nouvelle persistance d'événement (pas de RecordEvent côté view).

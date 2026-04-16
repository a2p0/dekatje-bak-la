# Contract — Prompt shape invariants

Le spec `spec/services/tutor/build_context_spec.rb` vérifie les
invariants structurels. Voici le contrat attendu après toute
modification de prompt dans cette feature.

## Sections obligatoires (toujours présentes)

Le `system_prompt` retourné par `Tutor::BuildContext.call` doit
contenir toutes ces chaînes, dans cet ordre :

1. `[RÈGLES PÉDAGOGIQUES]`
2. `[CONTEXTE SUJET]`
3. `[CORRECTION CONFIDENTIELLE]`
4. `[LEARNER MODEL]`
5. `[UTILISATION DES OUTILS`  (peut être suivi de `—` puis texte)
6. `[DÉMARRAGE DE CONVERSATION]`

## Section conditionnelle

7. Si `conversation.tutor_state.current_phase == "spotting"` : le
   prompt contient en plus `[PHASE REPÉRAGE`.

## Règles absolues (maintien de non-régression)

Le prompt doit continuer de contenir :

- `"Ne jamais donner la réponse"` (garde-fou non-divulgation)
- `"Maximum 60 mots par message"` (garde-fou longueur)
- Les 4 noms d'outils : `transition`, `update_learner_model`,
  `request_hint`, `evaluate_spotting`.

## Interpolations respectées

Les variables doivent toujours être substituées (jamais de
`%<specialty>s` brut restant) :

- `specialty`, `subject_title`, `part_title`, `part_objective`,
  `question_label`, `question_context`, `correction_text`,
  `learner_model`.

## Tests couvrant ce contrat

Fichier : `spec/services/tutor/build_context_spec.rb` — les
assertions existantes couvrent déjà une large partie. Ajouter
uniquement si une nouvelle section est introduite (ex. H1 pourrait
ajouter `"IMPÉRATIF"` qu'il faut assertér).

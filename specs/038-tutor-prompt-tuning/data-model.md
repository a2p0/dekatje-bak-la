# Phase 1 — Data Model

## Entités

Aucune entité DB modifiée. Cette feature ne touche qu'au **contenu
textuel** du prompt système.

## Structure du prompt système (logique)

Le prompt système tuteur est assemblé en 6 sections ordonnées :

| # | Section | Rôle | Variable |
|---|---|---|---|
| 1 | `[RÈGLES PÉDAGOGIQUES]` | Principes absolus (non-div, longueur, confiance, indices, validation) | Modifiée par H2, H3, H4 |
| 2 | `[CONTEXTE SUJET]` | Injection dynamique des données du sujet | Non modifiée |
| 3 | `[CORRECTION CONFIDENTIELLE]` | Correction officielle (ne jamais révéler) | Non modifiée |
| 4 | `[LEARNER MODEL]` | État du tuteur sérialisé (phase, concepts, etc.) | Non modifiée |
| 5 | `[UTILISATION DES OUTILS]` | Directives d'invocation des 4 outils | Modifiée par H1, H5 |
| 6 | `[DÉMARRAGE DE CONVERSATION]` | Instruction de greeting au 1er message | Potentiellement fusionnée avec H1 |

Section optionnelle (conditionnelle) :

| 7 | `[PHASE REPÉRAGE]` | Ajoutée si `current_phase == "spotting"` | Revue pour non-régression |

## Invariants

- **I1** — Les 6 sections principales MUST apparaître dans l'ordre
  ci-dessus.
- **I2** — La section `[CORRECTION CONFIDENTIELLE]` MUST rester en
  texte brut non paraphrasé (injecté tel quel).
- **I3** — Les règles absolues (non-divulgation, max 60 mots, confiance
  1-5) ne peuvent PAS être diluées — seules des règles additionnelles
  sont ajoutées.
- **I4** — Les noms des 4 outils (`transition`, `update_learner_model`,
  `request_hint`, `evaluate_spotting`) sont stables et documentés dans
  la section 5. Toute référence à ces noms doit rester cohérente.

## Taille du prompt

Cible : rester sous 3 500 tokens (taille actuelle estimée ~1 500
tokens, marge large pour ajouts).

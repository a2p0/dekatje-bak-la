module Tutor
  class ChipsPresenter
    # Mapping calibré sur corpus BAC STI2D 2025 (~90 questions).
    # Voir docs/superpowers/specs/2026-05-06-tutor-redesign-chips-mapping.md
    # Importé tel quel — toute modification doit passer par une session
    # sujet-en-main et mettre à jour le doc en parallèle.
    CHIPS_MAPPING = {
      calcul: {
        fresh: [
          { action: "send",       label: "C'est quoi la formule ?",    payload: "Quelle formule je dois utiliser ?" },
          { action: "send",       label: "Quelles données utiliser ?", payload: "Où je trouve les données nécessaires ?" },
          { action: "send",       label: "Je me lance",                payload: "Je commence le calcul, je te montre" },
          { action: "confidence", label: "Je suis perdu",              payload: "low" }
        ],
        armed: [
          { action: "send", label: "Vérifie mes unités",      payload: "Tu peux vérifier mes unités ?" },
          { action: "send", label: "Je bloque sur une étape", payload: "Je bloque sur une étape du calcul" },
          { action: "send", label: "Donne-moi un indice",     payload: "Donne-moi un indice pour avancer" }
        ],
        debug: [
          { action: "send", label: "Où est mon erreur ?",  payload: "Tu peux me dire où est mon erreur ?" },
          { action: "send", label: "Refais avec moi",      payload: "On peut refaire le calcul ensemble étape par étape ?" },
          { action: "send", label: "Vérifie mes unités",   payload: "Je crois que mes unités sont fausses" },
          { action: "send", label: "Donne le résultat",    payload: "Donne-moi le résultat final" }
        ],
        close: [
          { action: "send", label: "Je finalise",        payload: "Je finalise mon calcul, voilà ma réponse" },
          { action: "send", label: "Vérifie ma réponse", payload: "Tu peux vérifier ma réponse finale ?" },
          { action: "send", label: "Donne le résultat",  payload: "Donne-moi le résultat final" }
        ],
        done: [
          { action: "send", label: "Pourquoi ça marche ?", payload: "Pourquoi cette méthode marche ?" },
          { action: "send", label: "Question suivante",    payload: "On passe à la suivante" }
        ]
      },
      identification: {
        fresh: [
          { action: "send",       label: "Où je regarde ?",   payload: "Sur quel document je dois regarder ?" },
          { action: "send",       label: "Explique le terme", payload: "Tu peux m'expliquer le vocabulaire de la question ?" },
          { action: "send",       label: "Je propose",        payload: "Je te propose ma réponse" },
          { action: "confidence", label: "Je suis perdu",     payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour repérer" },
          { action: "send", label: "Quels critères ?",     payload: "Sur quels critères je dois m'appuyer ?" },
          { action: "send", label: "Je propose ça",        payload: "Voilà ce que je propose" }
        ],
        debug: [
          { action: "send", label: "Où j'ai mal lu ?",  payload: "Tu peux me montrer où j'ai mal lu le document ?" },
          { action: "send", label: "Reprends avec moi", payload: "On reprend ensemble la lecture du document" },
          { action: "send", label: "Donne la réponse",  payload: "Donne-moi la bonne réponse" }
        ],
        close: [
          { action: "send", label: "Je confirme",        payload: "Je confirme, c'est bien ça ma réponse" },
          { action: "send", label: "Vérifie ma réponse", payload: "Tu valides ?" },
          { action: "send", label: "Donne la réponse",   payload: "Donne-moi la bonne réponse" }
        ],
        done: [
          { action: "send", label: "Pourquoi ce choix ?", payload: "Pourquoi c'est cette réponse et pas une autre ?" },
          { action: "send", label: "Question suivante",   payload: "On passe à la suivante" }
        ]
      },
      justification: {
        fresh: [
          { action: "send",       label: "Comment structurer ?", payload: "Comment je structure ma justification ?" },
          { action: "send",       label: "Quels arguments ?",    payload: "Sur quels arguments je peux m'appuyer ?" },
          { action: "send",       label: "Je tente",             payload: "Je tente une justification, dis-moi" },
          { action: "confidence", label: "Je suis perdu",        payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi une piste pour argumenter" },
          { action: "send", label: "Sur quoi m'appuyer ?", payload: "Quels documents ou principes je dois citer ?" },
          { action: "send", label: "Voilà mon idée",       payload: "Voilà mon idée de justification" }
        ],
        debug: [
          { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans mon argumentation ?" },
          { action: "send", label: "Reformule avec moi",    payload: "On reformule ensemble ?" },
          { action: "send", label: "Donne la réponse",      payload: "Donne-moi la justification attendue" }
        ],
        close: [
          { action: "send", label: "Je rédige ma réponse", payload: "Je rédige ma justification finale" },
          { action: "send", label: "Vérifie ma réponse",   payload: "Tu valides ma justification ?" },
          { action: "send", label: "Donne la réponse",     payload: "Donne-moi la justification attendue" }
        ],
        done: [
          { action: "send", label: "Récapitule l'idée clé", payload: "Tu peux récapituler l'idée clé ?" },
          { action: "send", label: "Question suivante",     payload: "On passe à la suivante" }
        ]
      },
      representation: {
        fresh: [
          { action: "navigate",   label: "Ouvrir le DR",     payload: "open_dr" },
          { action: "send",       label: "Où je commence ?", payload: "Par quoi je commence sur le DR ?" },
          { action: "send",       label: "Donne la formule", payload: "Quelle formule pour calculer les valeurs ?" },
          { action: "send",       label: "Je me lance",      payload: "Je commence à compléter, je te dis" },
          { action: "confidence", label: "Je suis perdu",    payload: "low" }
        ],
        armed: [
          { action: "send", label: "Quelle échelle ?",        payload: "Quelle échelle ou convention je dois utiliser ?" },
          { action: "send", label: "Donne la formule",        payload: "Rappelle-moi la formule pour les valeurs" },
          { action: "send", label: "Vérifie mon début",       payload: "Tu peux vérifier ce que j'ai déjà tracé ?" }
        ],
        debug: [
          { action: "send", label: "Où c'est faux ?",   payload: "Quelle partie de mon tracé est fausse ?" },
          { action: "send", label: "Refais avec moi",   payload: "On reprend le tracé étape par étape" },
          { action: "send", label: "Donne la formule",  payload: "Donne-moi la formule pour les valeurs internes" },
          { action: "send", label: "Donne le résultat", payload: "Donne-moi le tracé attendu" }
        ],
        close: [
          { action: "send", label: "Je termine le tracé", payload: "Je finalise mon tracé sur le DR" },
          { action: "send", label: "Vérifie mon tracé",   payload: "Tu peux valider mon tracé final ?" },
          { action: "send", label: "Donne le résultat",   payload: "Donne-moi le tracé attendu" }
        ],
        done: [
          { action: "send", label: "Pourquoi cette forme ?", payload: "Pourquoi le tracé a cette allure ?" },
          { action: "send", label: "Question suivante",      payload: "On passe à la suivante" }
        ]
      },
      qcm: {
        fresh: [
          { action: "send",       label: "Explique les options",  payload: "Tu peux m'expliquer les différentes options ?" },
          { action: "send",       label: "Sur quoi je me base ?", payload: "Sur quel critère je dois choisir ?" },
          { action: "send",       label: "Je choisis",            payload: "Voilà ce que je choisis" },
          { action: "confidence", label: "Je suis perdu",         payload: "low" }
        ],
        armed: [
          { action: "send", label: "Élimine les fausses",  payload: "Aide-moi à éliminer les mauvaises options" },
          { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour choisir" },
          { action: "send", label: "Je penche pour…",      payload: "Je penche pour une option, je te dis laquelle" }
        ],
        debug: [
          { action: "send", label: "Pourquoi pas ce choix ?", payload: "Pourquoi mon choix n'est pas le bon ?" },
          { action: "send", label: "Compare les options",     payload: "On compare les options ensemble" },
          { action: "send", label: "Donne la réponse",        payload: "Donne-moi la bonne option" }
        ],
        close: [
          { action: "send", label: "Je confirme mon choix", payload: "Je confirme mon choix final" },
          { action: "send", label: "Vérifie ma réponse",    payload: "Tu valides mon option ?" },
          { action: "send", label: "Donne la réponse",      payload: "Donne-moi la bonne option" }
        ],
        done: [
          { action: "send", label: "Pourquoi cette option ?", payload: "Pourquoi c'est la bonne option ?" },
          { action: "send", label: "Question suivante",       payload: "On passe à la suivante" }
        ]
      },
      verification: {
        fresh: [
          { action: "send",       label: "Quel critère comparer ?", payload: "Quel est le critère de référence à respecter ?" },
          { action: "send",       label: "Quelle valeur seuil ?",   payload: "Quelle est la valeur seuil ou la norme ?" },
          { action: "send",       label: "Je vérifie",              payload: "Je fais la vérification, je te dis" },
          { action: "confidence", label: "Je suis perdu",           payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un indice",   payload: "Donne-moi un indice pour comparer" },
          { action: "send", label: "Où trouver le seuil ?", payload: "Sur quel document trouver le critère ?" },
          { action: "send", label: "Voilà ma comparaison",  payload: "Voilà ma comparaison, qu'est-ce que t'en penses ?" }
        ],
        debug: [
          { action: "send", label: "Mauvais critère ?",   payload: "Je me suis trompé de critère ?" },
          { action: "send", label: "Refais avec moi",     payload: "On refait la vérification ensemble" },
          { action: "send", label: "Donne la conclusion", payload: "Donne-moi la conclusion attendue" }
        ],
        close: [
          { action: "send", label: "Je conclus",            payload: "Je rédige ma conclusion : pass ou fail" },
          { action: "send", label: "Vérifie ma conclusion", payload: "Tu valides ma conclusion ?" },
          { action: "send", label: "Donne la conclusion",   payload: "Donne-moi la conclusion attendue" }
        ],
        done: [
          { action: "send", label: "Et si c'était KO ?", payload: "Qu'est-ce qu'on ferait si la vérif était KO ?" },
          { action: "send", label: "Question suivante",   payload: "On passe à la suivante" }
        ]
      },
      conclusion: {
        fresh: [
          { action: "send",       label: "Quoi synthétiser ?",  payload: "Sur quoi je dois m'appuyer pour conclure ?" },
          { action: "send",       label: "Combien de pistes ?", payload: "Combien de pistes ou d'arguments on attend ?" },
          { action: "send",       label: "Je propose",          payload: "Je te propose ma conclusion" },
          { action: "confidence", label: "Je suis perdu",       payload: "low" }
        ],
        armed: [
          { action: "send", label: "Donne-moi un angle",     payload: "Donne-moi un angle pour conclure" },
          { action: "send", label: "Quels résultats clés ?", payload: "Quels résultats clés je dois reprendre ?" },
          { action: "send", label: "Voilà mon idée",         payload: "Voilà mon idée de conclusion" }
        ],
        debug: [
          { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans ma conclusion ?" },
          { action: "send", label: "Reformule avec moi",     payload: "On reformule ensemble la conclusion" },
          { action: "send", label: "Donne la conclusion",    payload: "Donne-moi la conclusion attendue" }
        ],
        close: [
          { action: "send", label: "Je rédige la conclusion", payload: "Je rédige ma conclusion finale" },
          { action: "send", label: "Vérifie ma conclusion",   payload: "Tu valides ma conclusion ?" },
          { action: "send", label: "Donne la conclusion",     payload: "Donne-moi la conclusion attendue" }
        ],
        done: [
          { action: "send", label: "Élargis le sujet",  payload: "Tu peux élargir avec un autre angle DD ?" },
          { action: "send", label: "Question suivante", payload: "On passe à la suivante" }
        ]
      }
    }.freeze

    REVEAL_LABELS = [
      "Donne le résultat", "Donne la réponse", "Donne la conclusion"
    ].freeze

    DISABLED_TOOLTIP = "Essaie d'abord ou regarde la correction".freeze

    def self.call(trace:, answer_type:, expected_value: nil)
      phase = DerivePhase.call(trace: trace, answer_type: answer_type, expected_value: expected_value)
      for_phase(answer_type: answer_type, phase: phase, cap_active: trace.cap_active?)
    end

    def self.for_phase(answer_type:, phase:, cap_active:)
      key = answer_type.to_sym
      raw = CHIPS_MAPPING.dig(key, phase) || []

      raw.map do |chip|
        if cap_active && REVEAL_LABELS.include?(chip[:label])
          chip.merge(disabled: true, tooltip: DISABLED_TOOLTIP)
        else
          chip.merge(disabled: false)
        end
      end
    end
  end
end

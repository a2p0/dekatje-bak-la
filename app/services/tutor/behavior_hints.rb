module Tutor
  # Static mapping (signal, answer_type, budget_state) → behavior hint string.
  # Injected in BuildContext as the ACTION ATTENDUE block of the system prompt.
  # Chosen over template-paramétré (option B) for readability and quality of
  # individual phrasings (decision in brainstorm 4.11).
  module BehaviorHints
    DEFAULT_FALLBACK = "Réponds à l'élève en restant prof sympa qui tutoie. " \
                       "Court (1-3 phrases). Permission explicite de donner formule/valeur/calcul si demandé.".freeze

    HINTS = {
      # Signal: fresh_open (1ère ouverture du drawer dans ce sujet)
      fresh_open: lambda do |_at, _budget|
        "Salue brièvement (1 phrase max, ex. \"Salut, je suis là si t'as besoin\"). " \
          "Puis demande où il en est sur la question."
      end,

      # Signal: opened_after_data_hints (élève a vu data_hints, drawer fermé puis ouvert)
      opened_after_data_hints: lambda do |_at, _budget|
        "Il a maintenant les valeurs depuis data_hints. Demande-lui s'il préfère choisir " \
          "la formule ensemble ou tenter le calcul lui-même."
      end,

      # Signal: opened_after_correction (élève a vu correction, drawer fermé puis ouvert)
      # OU réaction live à viewed_correction quand drawer ouvert (Option III)
      opened_after_correction: lambda do |_at, _budget|
        "L'élève a vu la correction officielle. Bascule en mode appropriation : " \
          "demande sur quel passage il veut qu'on revienne (formule, données, calcul, raisonnement)."
      end,

      # Signal: navigation_arrival (élève a navigué vers cette question)
      navigation_arrival: lambda do |_at, budget|
        if budget[:attempts_count].positive?
          "L'élève revient sur cette question (déjà entamée). Rappelle en 1 phrase où vous en étiez, " \
            "puis enchaîne sur le palier courant."
        else
          "L'élève arrive sur cette question pour la première fois. Demande où il bloque ou s'il préfère se lancer."
        end
      end,

      # Signal: dont_understand (élève a écrit "je ne comprends pas" / similar)
      dont_understand: {
        calcul: ->(_at, _b) {
          "Démarre direct : énonce la formule à utiliser, identifie une sous-tâche concrète, " \
            "demande-lui de l'attaquer ou de te dire où il préfère qu'on commence."
        },
        identification: ->(_at, _b) {
          "Démarre direct : pointe le document à consulter et la nature de l'info à repérer. " \
            "Propose-lui de chercher ou demande-lui ce qui le bloque le plus."
        },
        justification: ->(_at, _b) {
          "Démarre direct : propose une structure (argument → preuve → conclusion) et un mot-clé central. " \
            "Demande-lui de tenter une première phrase."
        },
        representation: ->(_at, _b) {
          "Démarre direct : indique par quoi commencer sur le DR (échelle, axes, premier élément). " \
            "Demande-lui s'il veut un guide pas-à-pas ou la formule directement."
        },
        qcm: ->(_at, _b) {
          "Démarre direct : propose un critère de discrimination. Demande-lui d'éliminer 1 option avec ce critère."
        },
        verification: ->(_at, _b) {
          "Démarre direct : nomme le critère à comparer et la valeur de référence. " \
            "Demande-lui de poser le rapport ou la comparaison."
        },
        conclusion: ->(_at, _b) {
          "Démarre direct : propose 1-2 angles à reprendre des questions précédentes. " \
            "Demande-lui de structurer une première phrase de conclusion."
        }
      },

      # Signal: wrong_attempt (élève a fait une tentative incorrecte)
      wrong_attempt: {
        calcul: ->(_at, _b) {
          "Indique que ce n'est pas ça (sans donner la valeur attendue). Demande le détail du calcul. " \
            "Si tu vois une erreur d'unité ou de conversion probable, donne une indication ciblée."
        },
        identification: ->(_at, _b) {
          "Indique que ce n'est pas ça. Demande où il a trouvé sa réponse. " \
            "Oriente vers la bonne source si la sienne est fausse."
        },
        justification: ->(_at, _b) {
          "Indique ce qui manque ou ce qui est inexact. Demande-lui de reformuler en s'appuyant sur un fait précis."
        },
        representation: ->(_at, _b) {
          "Indique quelle partie du tracé est fausse (échelle, position, allure). Refais cette partie ensemble."
        },
        qcm: ->(_at, _b) {
          "Indique que ce n'est pas la bonne option. Demande pourquoi il l'a choisie. " \
            "Oriente vers un critère qui éliminerait son choix."
        },
        verification: ->(_at, _b) {
          "Indique que la conclusion ne tient pas. Vérifie d'abord le critère utilisé puis le calcul du rapport."
        },
        conclusion: ->(_at, _b) {
          "Indique ce qui manque. Pousse-le à enrichir avec un autre angle ou un autre résultat précédent."
        }
      },

      # Signal: correct_attempt
      correct_attempt: lambda do |_at, _budget|
        "Confirme brièvement (sans surenchère). Demande s'il a besoin de précisions ou s'il passe à la suivante."
      end,

      # Signaux de chips
      chip_formule: lambda do |answer_type, _budget|
        case answer_type
        when :representation, :calcul
          "Donne la formule ou la méthode demandée, dans une seule phrase. Demande s'il veut tenter avec, ou continuer ensemble."
        else
          "Donne la structure / méthode demandée, dans une seule phrase. Propose-lui de l'appliquer."
        end
      end,

      chip_valeur: lambda do |_at, _budget|
        "Donne les valeurs identifiées dans le sujet (sans calcul). Demande s'il veut les appliquer lui-même."
      end,

      chip_calcul: lambda do |_at, _budget|
        "Détaille le calcul étape par étape. Ne donne pas le résultat final si le cap est actif. " \
          "Termine par une demande : \"applique-le, dis-moi ce que tu trouves\"."
      end,

      chip_resultat: {
        cap_locked: ->(_at, _b) {
          "Refuse poliment de donner le résultat (cap actif : tentatives < 2 ET correction non vue). " \
            "Propose-lui une dernière tentative avec un dernier indice, ou de cliquer \"afficher la correction\"."
        },
        cap_open: ->(_at, _b) {
          "Donne le résultat avec le raisonnement complet en 1-2 phrases."
        }
      }
    }.freeze

    def self.for(signal:, answer_type:, budget:)
      sym_signal = signal.to_sym
      sym_at     = answer_type.to_sym

      # chip_resultat is special: cap-aware
      if sym_signal == :chip_resultat
        cap_locked = budget[:attempts_count].to_i < 2 && !budget[:viewed_correction]
        key = cap_locked ? :cap_locked : :cap_open
        return HINTS[:chip_resultat][key].call(sym_at, budget)
      end

      entry = HINTS[sym_signal]
      return DEFAULT_FALLBACK unless entry

      hint =
        if entry.is_a?(Hash)
          entry[sym_at] || entry.values.first
        else
          entry
        end

      # All entries are now lambdas with arity 2: (answer_type_or_unused, budget)
      hint.is_a?(Proc) ? hint.call(sym_at, budget) : hint.to_s
    end
  end
end

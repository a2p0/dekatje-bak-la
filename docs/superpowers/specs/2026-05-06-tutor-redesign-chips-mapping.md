# Chips Mapping calibré — Feature 062
# Calibré sur corpus BAC STI2D 2025 (~90 questions, 4 spécialités, 2 sujets)

## CHIPS_MAPPING

```ruby
CHIPS_MAPPING = {
  # ─────────────────────────────────────────────────────────────
  # CALCUL — formule, conversion, chaînage (40+ questions du corpus)
  # Ex: rendement éolienne, force centrifuge, conversion binaire,
  # quantum CAN, contrainte compression sol, masse fondation
  # ─────────────────────────────────────────────────────────────
  calcul: {
    fresh: [
      { action: "send",       label: "C'est quoi la formule ?",    payload: "Quelle formule je dois utiliser ?" },
      { action: "send",       label: "Quelles données utiliser ?", payload: "Où je trouve les données nécessaires ?" },
      { action: "send",       label: "Je me lance",                payload: "Je commence le calcul, je te montre" },
      { action: "confidence", label: "Je suis perdu",              payload: "low" },
    ],
    armed: [
      { action: "send", label: "Vérifie mes unités",      payload: "Tu peux vérifier mes unités ?" },
      { action: "send", label: "Je bloque sur une étape", payload: "Je bloque sur une étape du calcul" },
      { action: "send", label: "Donne-moi un indice",     payload: "Donne-moi un indice pour avancer" },
    ],
    debug: [
      { action: "send", label: "Où est mon erreur ?",  payload: "Tu peux me dire où est mon erreur ?" },
      { action: "send", label: "Refais avec moi",      payload: "On peut refaire le calcul ensemble étape par étape ?" },
      { action: "send", label: "Vérifie mes unités",   payload: "Je crois que mes unités sont fausses" },
      { action: "send", label: "Donne le résultat",    payload: "Donne-moi le résultat final" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je finalise",        payload: "Je finalise mon calcul, voilà ma réponse" },
      { action: "send", label: "Vérifie ma réponse", payload: "Tu peux vérifier ma réponse finale ?" },
      { action: "send", label: "Donne le résultat",  payload: "Donne-moi le résultat final" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Pourquoi ça marche ?", payload: "Pourquoi cette méthode marche ?" },
      { action: "send", label: "Question suivante",    payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # IDENTIFICATION — nommer, classer, lire DT, décoder
  # Ex: formes énergie diagramme, sollicitation mât, adresses IP,
  # blocs SysML, décodage ASCII, fonctions Python messages SD
  # ─────────────────────────────────────────────────────────────
  identification: {
    fresh: [
      { action: "send",       label: "Où je regarde ?",   payload: "Sur quel document je dois regarder ?" },
      { action: "send",       label: "Explique le terme", payload: "Tu peux m'expliquer le vocabulaire de la question ?" },
      { action: "send",       label: "Je propose",        payload: "Je te propose ma réponse" },
      { action: "confidence", label: "Je suis perdu",     payload: "low" },
    ],
    armed: [
      { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour repérer" },
      { action: "send", label: "Quels critères ?",     payload: "Sur quels critères je dois m'appuyer ?" },
      { action: "send", label: "Je propose ça",        payload: "Voilà ce que je propose" },
    ],
    debug: [
      { action: "send", label: "Où j'ai mal lu ?",  payload: "Tu peux me montrer où j'ai mal lu le document ?" },
      { action: "send", label: "Reprends avec moi", payload: "On reprend ensemble la lecture du document" },
      { action: "send", label: "Donne la réponse",  payload: "Donne-moi la bonne réponse" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je confirme",     payload: "Je confirme, c'est bien ça ma réponse" },
      { action: "send", label: "Vérifie ma réponse", payload: "Tu valides ?" },
      { action: "send", label: "Donne la réponse",   payload: "Donne-moi la bonne réponse" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Pourquoi ce choix ?", payload: "Pourquoi c'est cette réponse et pas une autre ?" },
      { action: "send", label: "Question suivante",   payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # JUSTIFICATION — argumenter, relier à un principe
  # Ex: choix projet env, intérêt projet climat, optimisation
  # fondation, comparaison puissance constante/max, IP compatible
  # ─────────────────────────────────────────────────────────────
  justification: {
    fresh: [
      { action: "send",       label: "Comment structurer ?", payload: "Comment je structure ma justification ?" },
      { action: "send",       label: "Quels arguments ?",    payload: "Sur quels arguments je peux m'appuyer ?" },
      { action: "send",       label: "Je tente",             payload: "Je tente une justification, dis-moi" },
      { action: "confidence", label: "Je suis perdu",        payload: "low" },
    ],
    armed: [
      { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi une piste pour argumenter" },
      { action: "send", label: "Sur quoi m'appuyer ?", payload: "Quels documents ou principes je dois citer ?" },
      { action: "send", label: "Voilà mon idée",       payload: "Voilà mon idée de justification" },
    ],
    debug: [
      { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans mon argumentation ?" },
      { action: "send", label: "Reformule avec moi",    payload: "On reformule ensemble ?" },
      { action: "send", label: "Donne la réponse",      payload: "Donne-moi la justification attendue" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je rédige ma réponse", payload: "Je rédige ma justification finale" },
      { action: "send", label: "Vérifie ma réponse",   payload: "Tu valides ma justification ?" },
      { action: "send", label: "Donne la réponse",     payload: "Donne-moi la justification attendue" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Récapitule l'idée clé", payload: "Tu peux récapituler l'idée clé ?" },
      { action: "send", label: "Question suivante",     payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # REPRESENTATION — tracer, compléter schéma/graphique/DR
  # Ex: cercles réglementation DR1, chaîne puissance DR5,
  # points fonctionnement DRS3, trame PROFIBUS DRS5,
  # diagramme états DRS4, code Python check_alarm()
  # → souvent calculs internes → variante [Donne la formule]
  # ─────────────────────────────────────────────────────────────
  representation: {
    fresh: [
      { action: "navigate",   label: "Ouvrir le DR",     payload: "open_dr" },
      { action: "send",       label: "Où je commence ?", payload: "Par quoi je commence sur le DR ?" },
      { action: "send",       label: "Donne la formule", payload: "Quelle formule pour calculer les valeurs ?" }, # si intermediate_steps présent
      { action: "send",       label: "Je me lance",      payload: "Je commence à compléter, je te dis" },
      { action: "confidence", label: "Je suis perdu",    payload: "low" },
    ],
    armed: [
      { action: "send", label: "Quelle échelle ?",        payload: "Quelle échelle ou convention je dois utiliser ?" },
      { action: "send", label: "Donne la formule",        payload: "Rappelle-moi la formule pour les valeurs" }, # si intermediate_steps
      { action: "send", label: "Vérifie mon début",       payload: "Tu peux vérifier ce que j'ai déjà tracé ?" },
    ],
    debug: [
      { action: "send", label: "Où c'est faux ?",   payload: "Quelle partie de mon tracé est fausse ?" },
      { action: "send", label: "Refais avec moi",   payload: "On reprend le tracé étape par étape" },
      { action: "send", label: "Donne la formule",  payload: "Donne-moi la formule pour les valeurs internes" }, # si intermediate_steps
      { action: "send", label: "Donne le résultat", payload: "Donne-moi le tracé attendu" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je termine le tracé", payload: "Je finalise mon tracé sur le DR" },
      { action: "send", label: "Vérifie mon tracé",   payload: "Tu peux valider mon tracé final ?" },
      { action: "send", label: "Donne le résultat",   payload: "Donne-moi le tracé attendu" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Pourquoi cette forme ?", payload: "Pourquoi le tracé a cette allure ?" },
      { action: "send", label: "Question suivante",      payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # QCM — choisir parmi options proposées
  # (pas de cas pur dans le corpus 2025 — calibré défensivement)
  # ─────────────────────────────────────────────────────────────
  qcm: {
    fresh: [
      { action: "send",       label: "Explique les options",  payload: "Tu peux m'expliquer les différentes options ?" },
      { action: "send",       label: "Sur quoi je me base ?", payload: "Sur quel critère je dois choisir ?" },
      { action: "send",       label: "Je choisis",            payload: "Voilà ce que je choisis" },
      { action: "confidence", label: "Je suis perdu",         payload: "low" },
    ],
    armed: [
      { action: "send", label: "Élimine les fausses",  payload: "Aide-moi à éliminer les mauvaises options" },
      { action: "send", label: "Donne-moi un indice",  payload: "Donne-moi un indice pour choisir" },
      { action: "send", label: "Je penche pour…",      payload: "Je penche pour une option, je te dis laquelle" },
    ],
    debug: [
      { action: "send", label: "Pourquoi pas ce choix ?", payload: "Pourquoi mon choix n'est pas le bon ?" },
      { action: "send", label: "Compare les options",     payload: "On compare les options ensemble" },
      { action: "send", label: "Donne la réponse",        payload: "Donne-moi la bonne option" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je confirme mon choix", payload: "Je confirme mon choix final" },
      { action: "send", label: "Vérifie ma réponse",    payload: "Tu valides mon option ?" },
      { action: "send", label: "Donne la réponse",      payload: "Donne-moi la bonne option" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Pourquoi cette option ?", payload: "Pourquoi c'est la bonne option ?" },
      { action: "send", label: "Question suivante",       payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # VERIFICATION — comparer résultat à critère, conclure pass/fail
  # Ex: coef sécurité poinçonnage, niveaux acoustiques,
  # mât correctement dimensionné, écart vs précision capteur,
  # vitesse transmission ATEX, type traitement adapté terrain
  # ─────────────────────────────────────────────────────────────
  verification: {
    fresh: [
      { action: "send",       label: "Quel critère comparer ?", payload: "Quel est le critère de référence à respecter ?" },
      { action: "send",       label: "Quelle valeur seuil ?",   payload: "Quelle est la valeur seuil ou la norme ?" },
      { action: "send",       label: "Je vérifie",              payload: "Je fais la vérification, je te dis" },
      { action: "confidence", label: "Je suis perdu",           payload: "low" },
    ],
    armed: [
      { action: "send", label: "Donne-moi un indice",   payload: "Donne-moi un indice pour comparer" },
      { action: "send", label: "Où trouver le seuil ?", payload: "Sur quel document trouver le critère ?" },
      { action: "send", label: "Voilà ma comparaison",  payload: "Voilà ma comparaison, qu'est-ce que t'en penses ?" },
    ],
    debug: [
      { action: "send", label: "Mauvais critère ?",   payload: "Je me suis trompé de critère ?" },
      { action: "send", label: "Refais avec moi",     payload: "On refait la vérification ensemble" },
      { action: "send", label: "Donne la conclusion", payload: "Donne-moi la conclusion attendue" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je conclus",            payload: "Je rédige ma conclusion : pass ou fail" },
      { action: "send", label: "Vérifie ma conclusion", payload: "Tu valides ma conclusion ?" },
      { action: "send", label: "Donne la conclusion",   payload: "Donne-moi la conclusion attendue" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Et si c'était KO ?", payload: "Qu'est-ce qu'on ferait si la vérif était KO ?" },
      { action: "send", label: "Question suivante",   payload: "On passe à la suivante" },
    ],
  },

  # ─────────────────────────────────────────────────────────────
  # CONCLUSION — synthétiser, proposer pistes, conclure DD
  # Ex: deux pistes amélioration mât, intérêt torchère,
  # capacité surveillance parcs, respect réglementation bruit,
  # conclusion DD (CO2 STEU, acier conique)
  # ─────────────────────────────────────────────────────────────
  conclusion: {
    fresh: [
      { action: "send",       label: "Quoi synthétiser ?",  payload: "Sur quoi je dois m'appuyer pour conclure ?" },
      { action: "send",       label: "Combien de pistes ?", payload: "Combien de pistes ou d'arguments on attend ?" },
      { action: "send",       label: "Je propose",          payload: "Je te propose ma conclusion" },
      { action: "confidence", label: "Je suis perdu",       payload: "low" },
    ],
    armed: [
      { action: "send", label: "Donne-moi un angle",    payload: "Donne-moi un angle pour conclure" },
      { action: "send", label: "Quels résultats clés ?", payload: "Quels résultats clés je dois reprendre ?" },
      { action: "send", label: "Voilà mon idée",        payload: "Voilà mon idée de conclusion" },
    ],
    debug: [
      { action: "send", label: "Qu'est-ce qui manque ?", payload: "Qu'est-ce qui manque dans ma conclusion ?" },
      { action: "send", label: "Reformule avec moi",     payload: "On reformule ensemble la conclusion" },
      { action: "send", label: "Donne la conclusion",    payload: "Donne-moi la conclusion attendue" }, # désactivé si tentatives < 2
    ],
    close: [
      { action: "send", label: "Je rédige la conclusion", payload: "Je rédige ma conclusion finale" },
      { action: "send", label: "Vérifie ma conclusion",   payload: "Tu valides ma conclusion ?" },
      { action: "send", label: "Donne la conclusion",     payload: "Donne-moi la conclusion attendue" }, # désactivé si tentatives < 2
    ],
    done: [
      { action: "send", label: "Élargis le sujet",  payload: "Tu peux élargir avec un autre angle DD ?" },
      { action: "send", label: "Question suivante", payload: "On passe à la suivante" },
    ],
  },
}.freeze
```

---

## Phrases tuteur exemples

### `calcul`
- **fresh** : "Allez, on s'attaque à ce rendement global. Avant de foncer, dis-moi : tu vois quelle formule on peut utiliser ici ?"
- **armed** : "OK tu te lances. Vas-y, montre-moi ta première ligne — surtout fais gaffe aux unités, c'est là que ça coince souvent."
- **debug** : "Hmm, tu trouves 56,73 et la correction donne autre chose. Reprenons : ta consommation est en l/100km, ta distance en km — tu vois où ça cloche ?"
- **close** : "T'es à deux doigts ! Pose ta valeur finale avec l'unité, et on valide."
- **done** : "Nickel, 56,73 l c'est ça. Tu vois pourquoi on passe par le ratio km/100 ? C'est exactement la même logique pour la prochaine."

### `identification`
- **fresh** : "Pour cette question, tu dois lire le DT5 — c'est là que sont les flux d'énergie. Tu repères les blocs entrants et sortants ?"
- **armed** : "Vas-y propose, je te dis si tu chauffes."
- **debug** : "Tu as dit 'énergie mécanique' au point A — mais regarde bien le diagramme, qu'est-ce qui entre dans la nacelle ?"
- **close** : "Oui c'est ça l'idée, énergie cinétique du vent. Confirme-moi ta formulation finale."
- **done** : "Bien vu. La règle à retenir : avant la turbine = cinétique, après = mécanique de rotation."

### `justification`
- **fresh** : "Justifier le choix du projet, OK. Tu vas devoir t'appuyer sur deux ou trois critères du DT2. Tu commences par quoi ?"
- **armed** : "Tu dis 'c'est mieux pour l'environnement' — d'accord mais appuie-toi sur quoi concrètement ? Une donnée chiffrée, un critère du tableau ?"
- **debug** : "Ton argument tient mais il manque le lien explicite avec les objectifs climatiques. Tu peux relier ?"
- **close** : "Bien, ajoute juste la conclusion explicite : 'donc le projet B est retenu parce que…'"
- **done** : "Top, structure argument → preuve → conclusion. Garde ce schéma pour toutes les justifs."

### `representation`
- **fresh** : "Ouvre DR5 — tu vois la chaîne de puissance vide ? Tu vas devoir placer les rendements. La formule pour calculer chaque rendement intermédiaire, tu l'as ?"
- **armed** : "OK tu commences à tracer. Quelle échelle tu prends sur l'axe vertical ? Vérifie avant de continuer."
- **debug** : "Ton point ne tombe pas sur la courbe puissance max — recalcule la valeur, je crois que tu as oublié le facteur de charge."
- **close** : "Yes, tes deux points sont bien placés. Trace la liaison et c'est fini."
- **done** : "Parfait. Tu vois comment la courbe monte puis sature ? C'est la limite de Betz qui apparaît."

### `qcm`
- **fresh** : "Quatre adresses IP proposées — pour répondre, tu dois distinguer celles compatibles avec le réseau /24. On commence par éliminer les impossibles ?"
- **armed** : "Tu hésites entre la 2 et la 4. Compare-les : laquelle est dans la plage du réseau ?"
- **debug** : "La 1 c'est l'adresse réseau elle-même, donc inutilisable. Reprends parmi les autres."
- **close** : "Oui, la 3 c'est la bonne. Confirme et on avance."
- **done** : "Le réflexe : toujours vérifier d'abord adresse réseau et broadcast, puis ce qui reste."

### `verification`
- **fresh** : "Vérification de dimensionnement : tu compares ta contrainte calculée à la contrainte admissible du sol. Tu as ces deux valeurs ?"
- **armed** : "Tu calcules le rapport. Au-dessus de 1 ça passe, en-dessous c'est KO — vas-y."
- **debug** : "Tu trouves 0,8 et tu conclus que c'est OK ? Relis le critère : il faut k ≥ 1,5 pour le glissement."
- **close** : "Voilà, k = 1,7 > 1,5 donc fondation correctement dimensionnée. Rédige la conclusion proprement."
- **done** : "Bien. Si ça avait été KO, qu'aurais-tu proposé ? Élargir la semelle, ajouter du lest…"

### `conclusion`
- **fresh** : "Deux pistes d'amélioration, c'est ce qu'on demande. Reprends ce qu'on a vu sur la sollicitation du mât — qu'est-ce qui pourrait réduire le coef de sécurité ?"
- **armed** : "Tu proposes 'changer le matériau' — précise lequel et pourquoi. Une piste = une justif courte."
- **debug** : "Tu n'as donné qu'une piste. Cherche-en une seconde côté géométrie (épaisseur, forme conique…)."
- **close** : "Yes, deux pistes claires : matériau + forme conique. Rédige proprement avec le bénéfice attendu."
- **done** : "Bien vu d'avoir relié à la conclusion DD du sujet — c'est exactement ce qu'attend le jury en STI2D."

---

## Cas particuliers détectés

1. **`representation` avec calculs internes** (très fréquent) : Q4.4 ferme (point fonctionnement = calcul + tracé), Q3.2 ferme (graphique viabilité = calcul seuil + tracé), Q4 EE (tableau puissance = calcul Betz + remplissage), Q2.B SIN (adresse DIP = conversion binaire + report DR). → variante `[Donne la formule]` essentielle dans `:fresh`, `:armed`, `:debug`.

2. **`representation` avec code** (Q2.C SIN check_alarm) : compléter du code Python. Les chips fonctionnent (`Donne la formule` ↔ `Donne la logique`). → à raffiner post-MVP avec sous-type `representation_code`.

3. **`identification` avec décodage** (Q5.B SIN ASCII, Q3.B durée bit) : zone grise avec `calcul`. Les chips identification marchent (`Où je regarde ?` pointe la table ASCII). Pas de changement nécessaire.

4. **`verification` avec calcul préalable faux** (Q1.6 fondations, Q3.3 acoustique) : l'élève peut être en `:debug` à cause du calcul amont. Le chip `[Refais avec moi]` couvre les deux. À noter pour le prompt tuteur.

5. **`conclusion` à dimension DD** (Q5.6, Q2.4 STEU, Q5.4 torchère) : chip `[Élargis le sujet]` en `:done` utile pour la transversalité STI2D.

6. **`calcul` à étapes chaînées longues** (Q2.1-2.5 ITEC treuil, Q3.1 STEU 5,5pt) : chip `[Je bloque sur une étape]` (armed) et `[Refais avec moi]` (debug) couvrent ce cas. Chip `[Quelle étape suivante ?]` envisageable post-MVP.

7. **`identification` très courtes** (Q4.2, Q5.1, 1pt) : en pratique seul `:fresh` → `:done` sera parcouru. Mapping valide quand même.

8. **Pas de `qcm` pur dans le corpus 2025** : calibré défensivement, à valider sur d'autres millésimes.

9. **Chips `navigate` dynamiques** : seul `representation:fresh` propose `open_dr`. À enrichir au runtime selon `question_documents` — si DT1 référencé, ajouter chip `[Ouvrir DT1]` dynamiquement. Le mapping statique est la base, une couche runtime complète.

10. **Tutoiement cohérent** partout — ton "prof sympa" maintenu dans tous les labels.

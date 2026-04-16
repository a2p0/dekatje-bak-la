# Phase 0 — Research

## 1. Analyse des transcripts baseline (run 24503225082)

Lecture ciblée des 15 transcripts (Haiku/Haiku/Sonnet), en priorité les
conversations aux plus mauvais scores Guidage et Process.

### Patterns de faute observés

**A. Transition tardive** (lié à Process 2.53) :

> Message tuteur 2 : `"Je vais d'abord passer à la phase de lecture,
> puis guider ton travail.Excellente question ! ..."`

Le tuteur **annonce** la transition en texte libre au lieu de l'appeler
directement via l'outil `transition`. Conséquence : la phase reste
bloquée en `idle` ou `greeting` plusieurs tours. Observation sur 8
conversations : transition réelle arrive tour 3 ou plus.

**B. Guidage vague** (lié à Guidage 3.00) :

> `"Peux-tu relire ton document et me donner cette liste précise ?"`
> `"Qu'observes-tu dans ton DTS1 ?"`

Questions génériques, sans point d'attention précis. Elles laissent
l'élève choisir ce qu'il observe. Une version ciblée produirait :
> `"Dans le DTS1, repère la première ligne du tableau : quel nom de
> matériau y figure ?"`

**C. Validation incorrecte** (lié à Non-divulgation et Focal) :

> `"Tu as raison sur les unités et l'addition des R !"`

Le tuteur valide une intuition de l'élève avant que celui-ci ne
l'ait démontrée dans le contexte de la question. Renforce les
dérives factuelles (élève cite "polystyrène" alors que la réponse
officielle est "laine de roche").

**D. Dérive non recadrée** (lié à Focal 3.40) :

Quand l'élève dit "je n'ai pas accès au document", le tuteur accepte
la méta-discussion au lieu de recadrer fermement. Certains tuteurs
dérivent complètement dans le méta (`"Puisque tu es une IA..."`).

**E. Indice en texte libre** (lié à Guidage) :

> `"Relance stratégique : Quel type d'information cherches-tu ? ..."`

Le tuteur formule des indices directement dans le texte au lieu
d'appeler `request_hint(level: 1)`. L'indice n'est pas tracé par le
pipeline et le juge ne peut pas valoriser la progression graduée.

### Patterns positifs observés

- Non-divulgation (4.53) : le tuteur **refuse systématiquement** de
  donner les valeurs chiffrées. Ce point à **préserver** (garde-fou).
- Ton bienveillant (4.00) : les `"Excellente question !"`, emojis
  occasionnels tiennent le score. À préserver mais modérer (la règle
  actuelle demande déjà "pas de super-réponse systématique").

## 2. Hypothèses de modifications prompt

Ordonnées par impact attendu et indépendance (permet d'itérer vite).

### H1 — Transition systématique avant tout texte (process + rank)

Ajouter au `[UTILISATION DES OUTILS]` :

> **IMPÉRATIF** : Dès réception du **tout premier** message élève, ton
> **PREMIER acte** est d'appeler `transition(phase: "greeting")`
> **avant** de rédiger la moindre ligne de texte. À chaque message
> suivant, si la phase courante doit changer, appelle `transition`
> **avant** d'écrire.

**Gain attendu** : Process +0.5, Phase rank +0.3-0.5.

### H2 — Questions guidées avec un verbe d'action + un objet nommé (guidage)

Ajouter au `[RÈGLES PÉDAGOGIQUES]` :

> **Format de question obligatoire en guiding** : chaque question
> commence par un verbe d'action (Identifie, Repère, Cite, Compare,
> Relève) et désigne un objet précis (une ligne, une valeur, un
> matériau, une unité). Pas de question-ouverte-générique
> (« qu'observes-tu ? »).

Exemples positifs / négatifs à lister (few-shot court) :

> ✅ « Relève dans le DTS1 la valeur de λ pour la laine de roche. »
> ❌ « Qu'observes-tu dans le DTS1 ? »

**Gain attendu** : Guidage +0.7-1.0.

### H3 — Refus net de la méta-discussion (focal)

Ajouter au `[RÈGLES PÉDAGOGIQUES]` :

> **Focus** : Tu restes sur la question courante même si l'élève
> dérive (méta-discussion, hors-sujet, plainte technique). Tu ne
> valides aucune dérive : tu reformules la consigne et renvoies à
> l'objet précis à identifier.

**Gain attendu** : Focal +0.5-0.8.

### H4 — Validation conditionnelle (non-div + focal)

Ajouter au `[RÈGLES PÉDAGOGIQUES]` :

> **Validation** : Ne valide une affirmation de l'élève que si elle
> est **à la fois** correcte *et* sourcée dans le document courant.
> Si l'élève affirme un fait sans preuve, demande la source avant
> toute validation.

**Gain attendu** : Focal +0.2, Non-div maintenu.

### H5 — Appel systématique de request_hint en guiding (guidage)

Ajouter au `[UTILISATION DES OUTILS]` :

> **En phase `guiding`** : si l'élève demande de l'aide, tu DOIS
> appeler `request_hint(level: N)` avant d'écrire le texte de l'indice.
> Commence toujours par `level: 1`. N'écris jamais un indice en texte
> libre sans avoir enregistré l'appel.

**Gain attendu** : Guidage +0.3-0.5, structural_metrics "indices
distribués" passe de 0 à ≥1.

## 3. Méthode d'itération

1. Partir du prompt actuel (commit main `e3908b4`), bien mesuré.
2. Pour chaque H :
   a. Modifier `SYSTEM_TEMPLATE` (ou section adjacente).
   b. Commit `refactor(tutor-prompt): H<N> — <titre>`.
   c. Lancer sim réduite (`QUESTIONS=A.1 PROFILES=bon_eleve,
      eleve_en_difficulte TURNS=5`).
   d. Ajouter entrée dans `hypotheses.md` avec scores + delta.
3. Critère de conservation d'une H :
   - Au moins un des critères ciblés gagne ≥ 0.3 pt,
   - **ET** aucune régression ≥ 0.2 sur les non-cibles.
4. Si H échoue aux critères : `git revert` le commit, passer à la
   suivante, noter la raison.
5. Après toutes les H applicables : run complet (15 convs) pour
   valider SC-001 à SC-008.

## 4. Méthode de sim réduite

```sh
gh workflow run tutor_simulation.yml --ref 038-tutor-prompt-tuning \
  -f subject_id=1 \
  -f turns=5 \
  -f questions=A.1 \
  -f profiles=bon_eleve,eleve_en_difficulte \
  -f tutor_model=anthropic/claude-haiku-4.5 \
  -f student_model=anthropic/claude-haiku-4.5 \
  -f judge_model=anthropic/claude-sonnet-4.6
```

- **2 conversations × 5 tours** ≈ 5 min de run, ~$0.05.
- Profils choisis pour couvrir 2 comportements très différents
  (discipliné vs confus).

### Sim complète (validation finale)

```sh
gh workflow run tutor_simulation.yml --ref 038-tutor-prompt-tuning \
  -f subject_id=1 \
  -f turns=5 \
  -f questions=A.1,A.2,A.3 \
  -f profiles=bon_eleve,eleve_moyen,eleve_en_difficulte,eleve_paresseux,eleve_hors_sujet \
  -f tutor_model=anthropic/claude-haiku-4.5 \
  -f student_model=anthropic/claude-haiku-4.5 \
  -f judge_model=anthropic/claude-sonnet-4.6
```

- **15 conversations** ≈ 20 min, ~$0.60.

## 5. Critère d'arrêt global

- **Arrêt succès** : toutes les cibles SC atteintes ET budget < $2.
- **Arrêt partiel** : ≥ 2 cibles principales atteintes, documenter
  les échecs dans `hypotheses.md`, merger quand même.
- **Arrêt bloqué** : budget atteint sans gain significatif → revenir
  au prompt baseline, documenter les apprentissages, fermer la PR
  comme no-op (prompt actuel suffisant).

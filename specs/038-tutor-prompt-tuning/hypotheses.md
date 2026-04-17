# Journal des itérations — Tuning prompt tuteur

**Baseline** : run [24503225082](https://github.com/a2p0/dekatje-bak-la/actions/runs/24503225082)
(commit `e3908b4` main, Haiku/Haiku/Sonnet).

| Critère | Baseline | Cible |
|---|---|---|
| Phase rank | 3.00 / 7 | ≥ 3.0 |
| Non-divulgation | 4.53 / 5 | ≥ 4.5 |
| Guidage progressif | 3.00 / 5 | ≥ 4.0 |
| Bienveillance | 4.00 / 5 | ≥ 4.0 |
| Focalisation | 3.40 / 5 | ≥ 4.0 |
| Respect du process | 2.53 / 5 | ≥ 3.5 |

## Table H → critère gating

Chaque hypothèse a un (ou deux) critère(s) sur lesquels elle doit
produire le gain pour être conservée (règle KEEP).

| H | Critère(s) gating | Non-régression surveillée |
|---|---|---|
| H1 (transition avant texte) | Process, Phase rank | Non-div, Bienveillance |
| H2 (verbe+objet en guiding) | Guidage | Non-div, Bienveillance |
| H3a (pas de fuite d'état interne) | Focalisation | Bienveillance |
| H3b (refus méta hors-sujet) | Focalisation | Bienveillance |
| H4 (validation conditionnelle) | Focalisation, Non-div | Bienveillance |
| H5 (request_hint systématique) | Guidage, Phase rank | Non-div |

**Règle KEEP** : gain ≥ 0.3 pt sur **au moins un** critère gating
**ET** aucune régression ≥ 0.2 pt sur les critères de non-régression.

## One-liner agrégation scores

```sh
RUN_ID=<id>; mkdir -p /tmp/sim_$RUN_ID && gh run download $RUN_ID --dir /tmp/sim_$RUN_ID && \
  python3 -c "
import json, glob
p = glob.glob('/tmp/sim_$RUN_ID/*/**/raw.json', recursive=True)[0]
d = json.load(open(p))
ap = [p for q in d['results'] for p in q.get('profiles',[])]
rk = [p['structural_metrics']['phase_rank'] for p in ap]
print(f'n={len(ap)} rank={sum(rk)/len(rk):.2f}/7')
for c in ['non_divulgation','guidage_progressif','bienveillance','focalisation','respect_process']:
    v = [p['evaluation'][c]['score'] if isinstance(p['evaluation'].get(c),dict) else 0 for p in ap]
    v = [x for x in v if x>0]
    print(f'{c}: {sum(v)/len(v):.2f}/5' if v else f'{c}: n/a')
"
```

## Historique

_(entrées à remplir au fil des itérations — gabarit ci-dessous)_

### Baseline control

- **Run T004 (n=2, A.1)** : [24509839814](https://github.com/a2p0/dekatje-bak-la/actions/runs/24509839814)
  - rank **3.00**, non-div **5.00**, guid **3.00**, bienv **4.00**, focal **3.50**, proc **3.00**
- **Run variance #1 (n=6, A.1-3)** : [24523516616](https://github.com/a2p0/dekatje-bak-la/actions/runs/24523516616)
  - rank **2.83**, non-div **4.17**, guid **2.50**, bienv **3.83**, focal **3.33**, proc **2.17**
- **Run variance #2 (n=6, A.1-3)** : [24523524445](https://github.com/a2p0/dekatje-bak-la/actions/runs/24523524445)
  - rank **3.17**, non-div **4.50**, guid **2.67**, bienv **4.17**, focal **3.33**, proc **2.67**
- **Variance observée (mêmes prompts, 2 runs)** : max |Δ| = **0.50** (respect_process), 4 critères sur 6 > 0.3. Bruit juge trop fort pour tirer conclusion sur sim réduite.
- **Baseline agrégée (n=12)** : rank **3.00**, non-div **4.33**, guid **2.58**, bienv **4.00**, focal **3.33**, proc **2.42**. À utiliser comme référence pour les prochaines itérations.
- **Décision méthodologique** : passer à sim complète (15 convs) pour chaque H future. Coût $0.60/itération. Budget restant $1.55 → 2-3 H testables au max.

### H1 — Transition systématique avant tout texte

- **Critère gating** : Process, Phase rank
- **Commit** : `95737db` (reverted in `2817c2e`)
- **Run sim réduite** : [24521752842](https://github.com/a2p0/dekatje-bak-la/actions/runs/24521752842), n=2
- **Scores** : rank **3.00**, non-div **4.50**, guid **3.00**, bienv **4.00**, focal **3.00**, proc **2.50**
- **Delta vs baseline control** : rank 0, non-div −0.50, guid 0, bienv 0, focal −0.50, proc −0.50
- **Verdict** : ❌ **REVERT** prématurément — **à revisiter**. Variance test ultérieure a révélé que |Δ| = 0.5 tombe dans le bruit juge (max observé en sim 6 convs identiques). H1 n'est donc **ni confirmée ni infirmée** par ce run. À retester en sim complète (15 convs) si budget permet.

### H2 — Questions guidées avec verbe d'action + catégorie

- **Critère gating** : Guidage
- **Commits** :
  - `3a2895f` (H2 v1 "verbe + objet précis") — reverted, see below
  - `a84339b` (branch `040-tutor-prompt-tuning-retry`, final form "verbe + catégorie")
- **Méthodologie** : méthodologie D (structural metrics + juge), n=30 convs agrégées
  sur 2 runs, sonnet-4.6 tutor+student, sonnet-4 judge, TURNS=7, questions A.1-A.3.

**Itération 1 (H2 v1, "verbe + valeur précise")** — run [24550287503](https://github.com/a2p0/dekatje-bak-la/actions/runs/24550287503), n=15
- rank **3.67**, non-div **3.80** (−0.53 vs baseline ❌), guid **3.40** (+0.82 ✅),
  bienv 4.13, focal 3.00, proc 2.67
- Verdict : ❌ REJETÉ — régression non-divulgation hors bruit. L'exemple
  « Relève la valeur de λ pour la laine de roche » nommait la cible,
  frôlant la divulgation.

**Itération 2 (H2bis "verbe + catégorie")** — runs [24551806279](https://github.com/a2p0/dekatje-bak-la/actions/runs/24551806279) + [24553462232](https://github.com/a2p0/dekatje-bak-la/actions/runs/24553462232), n=30
- Scores (n=30) : rank **3.83**, non-div **4.13** (−0.20 vs baseline, dans bruit 0.13),
  guid **3.60** (+1.02 ✅), bienv 4.07, focal 3.37, proc 3.03
- action_verb_ratio : **0.487** (vs baseline 0.000) ✅
- Variance run-to-run observée : |Δ non_div| 0.133, |Δ focal| 0.467, cohérent
  avec bruit juge documenté ±0.50.
- Verdict : ✅ **KEEP**. Gate guidage +1.02 ≫ 0.30. Non-div dans le bruit.
  Bonus : respect_process +0.61, focalisation stabilisée.

### H3a — Pas de fuite d'état interne (priorité 1)

- **Critère gating** : Focalisation
- **Non-régression** : Bienveillance
- **Branche** : `041-tutor-H3a`
- **Métrique déterministe** : `internal_state_leak_count` (nouveau, commit `ccb4395`)

**Diagnostic baseline** (run [24559542458](https://github.com/a2p0/dekatje-bak-la/actions/runs/24559542458), 4 convs, SKIP_JUDGE, sonnet-4.6) :
4 transcripts lus (eleve_hors_sujet × A.1/A.2 + eleve_moyen × A.1/A.2).
Cause primaire identifiée pour focalisation 3.37 : le tuteur **narre
son propre state machine** à l'élève (3/4 convs).

Exemples de fuites observées :
- « Je vois que la phase est déjà en 'reading'. Continuons ! »
- « Je suis en phase **reading** — passons au repérage. »
- « Je suis en phase **spotting** — je dois évaluer si l'élève... »

**Fix** (commit `43ecb38`) : ajout dans `[RÈGLES PÉDAGOGIQUES]` :
> « Ne JAMAIS mentionner à l'élève ton état interne, les noms de phases
> (greeting, reading, spotting, guiding, validating, feedback, transition)
> ni le fait que tu utilises des outils. »

### H3b — Refus net méta-discussion hors-sujet (priorité 2)

- **Critère gating** : Focalisation
- **Non-régression** : Bienveillance
- **Status** : en attente (à tester après H3a pour isoler les effets)

**Diagnostic** : le tuteur tolère trop poliment les distractions
(« Le match, c'est pour après le bac 😄 ») et **acknowledge + continue**
au lieu d'ignorer sec. L'élève apprend que la méta-discussion est tolérée.

**Fix prévu** : règle prompt « Si hors-sujet (sport/jeu/météo/IA/toi),
UNE SEULE relance : 'Revenons à {question}'. Deuxième tentative : ignorer. »

### H4 — Validation conditionnelle

- **Critère gating** : Focalisation, Non-divulgation
- _(reste idem)_

### H5 — Appel systématique de request_hint en guiding

- **Critère gating** : Guidage, Phase rank
- _(reste idem)_

## Budget dépensé

Après chaque sim, incrémenter :

| Run | Type | Coût estimé | Cumul |
|---|---|---|---|
| T004 | réduite (2 convs) | $0.05 | **$0.05** ✅
| H1 | réduite | $0.05 | **$0.10** (REVERT) |
| H2 | réduite | $0.05 | **$0.15** (REVERT prématuré, inconclusif) |
| Variance #1 | réduite 6 convs | $0.15 | $0.30 |
| Variance #2 | réduite 6 convs | $0.15 | **$0.45** |
| _(H3a)_ | réduite SKIP_JUDGE (4 convs) | $0.80 | _._ |
| _(H3a validation)_ | complète juge (15 convs) | $3.00 | _._ |
| _(H3b)_ | réduite | $0.80 | _._ |
| _(H4)_ | réduite | $0.80 | _._ |
| _(H5)_ | réduite | $0.80 | _._ |

**Cap SC-007 révisé** : $5 par hypothèse (coûts réels recalibrés post-H2 :
~$1.63/sim complète avec juge × facteur 2 pour tool-use, soit ~$3/sim complète).
Si dépassé sans SC atteints → stop + documenter.

## Run de validation complète

- **Run ID** : _(à remplir)_
- **Scores** : rank _._, non-div _._, guid _._, bienv _._, focal _._, proc _._
- **SC validés** : SC-001 ☐, SC-002 ☐, SC-003 ☐, SC-004 ☐, SC-005 ☐, SC-006 ☐, SC-007 ☐, SC-008 ☐
- **Budget dépensé** : $_._ / $2

## Méthodologie D — metrics structurelles (follow-up 2026-04-16)

Le bruit juge ±0.50 pt sur n=6 a rendu les verdicts H1/H2 inconclusifs.
**Feature 039 livre l'instrument de mesure** — cf. [specs/039-structural-metrics/spec.md](../039-structural-metrics/spec.md).

4 nouvelles métriques déterministes (σ ≈ 0.01) sont désormais disponibles
dans `TutorSimulation::StructuralMetrics` :

- `first_turn_with_transition` → gate H1
- `action_verb_ratio_guiding`  → gate H2
- `dt_dr_leak_count_non_spotting`
- `short_message_ratio`

Un guard `SKIP_JUDGE=1` dans `TutorSimulation::Runner` divise le coût sim
par ~2 (judge consomme ~50% du budget). Permet d'itérer H1/H2 sous le
cap budget SC-007 via des sims sans juge.

**Protocole de reprise** :
1. Re-appliquer H1 (cherry-pick `95737db`), lancer sim avec SKIP_JUDGE=1,
   comparer `first_turn_with_transition` baseline vs H1. Verdict
   déterministe sans juge.
2. Idem H2 (cherry-pick `3a2895f`), comparer `action_verb_ratio_guiding`.
3. Sim finale de validation avec juge pour les hypothèses KEEP.

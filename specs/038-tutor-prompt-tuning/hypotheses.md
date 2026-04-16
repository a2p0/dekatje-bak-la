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
| H3 (refus méta) | Focalisation | Bienveillance |
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

### H2 — Questions guidées avec verbe d'action + objet nommé

- **Critère gating** : Guidage
- _(reste idem)_

### H3 — Refus net de la méta-discussion

- **Critère gating** : Focalisation
- _(reste idem)_

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
| _(H3)_ | réduite | $0.05 | _._ |
| _(H4)_ | réduite | $0.05 | _._ |
| _(H5)_ | réduite | $0.05 | _._ |
| T025 | complète (15 convs) | $0.60 | _._ |

**Cap SC-007** : $2. Si dépassé sans SC atteints → stop + documenter.

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

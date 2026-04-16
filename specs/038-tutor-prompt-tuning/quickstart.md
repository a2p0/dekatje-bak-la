# Quickstart — Itération tuning prompt tuteur

## 1. Lancer une sim réduite (après modif prompt)

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

- ~5 min, ~$0.05.
- Surveiller le run : `gh run watch <run_id>` ou lien Actions UI.

## 2. Télécharger et agréger les scores

```sh
RUN_ID=<id>
mkdir -p /tmp/sim_$RUN_ID && gh run download $RUN_ID --dir /tmp/sim_$RUN_ID
python3 - <<EOF
import json, glob
path = glob.glob('/tmp/sim_$RUN_ID/*/**/raw.json', recursive=True)[0]
d = json.load(open(path))
all_p = [p for q in d['results'] for p in q.get('profiles', [])]
ranks = [p['structural_metrics']['phase_rank'] for p in all_p]
print(f"n={len(all_p)} rank={sum(ranks)/len(ranks):.2f}/7")
for c in ['non_divulgation','guidage_progressif','bienveillance','focalisation','respect_process']:
    vals = [p['evaluation'][c]['score'] if isinstance(p['evaluation'].get(c),dict) else 0 for p in all_p]
    vals = [v for v in vals if v>0]
    print(f"{c}: {sum(vals)/len(vals):.2f}/5" if vals else f"{c}: n/a")
EOF
```

## 3. Enregistrer le delta

Ouvrir `specs/038-tutor-prompt-tuning/hypotheses.md`, remplir la
section correspondante (commit, run ID, scores, delta, verdict).

## 4. Critère KEEP / REVERT

- **KEEP** si ≥ 1 critère ciblé gagne ≥ 0.3 pt **et** aucune
  régression ≥ 0.2 pt sur les autres critères.
- **REVERT** sinon : `git revert <commit>` et passer à l'hypothèse
  suivante.

## 5. Sim complète (validation finale, 1 fois)

Une fois 3-5 hypothèses appliquées (ou budget épuisé) :

```sh
gh workflow run tutor_simulation.yml --ref 038-tutor-prompt-tuning \
  -f subject_id=1 \
  -f turns=5 \
  -f questions=A.1,A.2,A.3 \
  -f tutor_model=anthropic/claude-haiku-4.5 \
  -f student_model=anthropic/claude-haiku-4.5 \
  -f judge_model=anthropic/claude-sonnet-4.6
```

- ~20 min, ~$0.60.
- Remplir la section "Run de validation complète" de
  `hypotheses.md` avec les scores finaux.

## 6. PR

- Si toutes les cibles atteintes → PR vers main avec le rapport
  final dans la description.
- Si cibles partielles → PR documentant les gains et limites, option
  de merger partiel.
- Si bloqué → fermer la PR, revert local, documenter dans
  `hypotheses.md`.

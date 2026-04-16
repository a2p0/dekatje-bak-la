# Quickstart — Metrics structurelles

**Branche** : `039-structural-metrics`

## Pour le développeur qui revient après coupure

### 1. Lire dans cet ordre
1. `spec.md` — pourquoi on fait ça (variance juge ±0.50 pt)
2. `data-model.md` — structures in-memory et invariants I1-I6
3. `contracts/structural_metrics_api.md` — signatures et tests contractuels
4. `research.md` — décisions R1-R6 et alternatives rejetées

### 2. Lancer les tests unitaires

```bash
bundle exec rspec spec/services/tutor_simulation/structural_metrics_spec.rb
bundle exec rspec spec/services/tutor_simulation/runner_spec.rb
bundle exec rspec spec/services/tutor_simulation/report_generator_spec.rb
```

Ordre d'implémentation recommandé : specs AVANT code (principe IV constitution).

### 3. Lancer une sim locale sans juge

```bash
export OPENROUTER_API_KEY=sk-or-...
export SKIP_JUDGE=1
bundle exec rails db:seed RAILS_ENV=development  # crée le subject si absent
bundle exec rake 'tutor:simulate[1]' PROFILES=bon_eleve TURNS=3 QUESTIONS=1.1
```

Résultat attendu :
- `tmp/tutor_simulations/<timestamp>/raw.json` contient, pour chaque profil :
  - `structural_metrics` avec les 4 nouvelles clés
  - `evaluation: { "skipped" => true }`
- `tmp/tutor_simulations/<timestamp>/report.md` affiche "Juge désactivé (SKIP_JUDGE=1)"
  au lieu du tableau de scores.

### 4. Lancer une sim sur CI (baseline propre)

Workflow GitHub Actions : `.github/workflows/tutor_simulation.yml`.

```bash
gh workflow run tutor_simulation.yml \
  -f profiles=bon_eleve,eleve_moyen,eleve_en_difficulte,eleve_paresseux,eleve_hors_sujet \
  -f turns=5 \
  -f questions=1.1 \
  -f skip_judge=true   # ← à wirer dans le workflow si on veut l'exposer
```

Note : cet input `skip_judge` est optionnel à ajouter au workflow YAML. Non requis
pour la phase 0 du feature — on peut aussi juste lancer la sim sans lui pour
avoir les structural_metrics calculés ET l'évaluation juge en prime.

### 5. Vérifier les 4 nouvelles métriques sur un rapport

```bash
ls -t tmp/tutor_simulations/ | head -1 | xargs -I {} cat tmp/tutor_simulations/{}/report.md | grep -E "1er tour|verbes d'action|Leaks DT|messages ≤ 60"
```

Doit retourner 4 lignes (une par métrique).

## Variance test (validation de SC-002)

Pour confirmer que σ < 0.05 sur les 4 nouvelles métriques :

```bash
# Run 1
SKIP_JUDGE=1 rake 'tutor:simulate[1]' TURNS=5 PROFILES=bon_eleve,eleve_moyen QUESTIONS=1.1,1.2,1.3
# Run 2 (prompt identique)
SKIP_JUDGE=1 rake 'tutor:simulate[1]' TURNS=5 PROFILES=bon_eleve,eleve_moyen QUESTIONS=1.1,1.2,1.3

# Comparer les 2 raw.json — les metrics STRUCTURELLES doivent être identiques
# aux variations du student_simulator près (qui est aussi LLM, donc variance non nulle).
```

Si les metrics structurelles dérivent fortement entre deux runs, c'est
attendu car l'élève simulé est un LLM — ce n'est PAS un bruit de mesure mais
une variance de l'**input**. Pour mesurer l'effet prompt, comparer baseline vs
variante H1/H2 sur la **même** configuration d'élève simulé (même seed et
température si exposés par OpenRouter, sinon moyenner sur n grand).

## Rollback

Si le feature doit être retiré après merge :

1. `git revert <merge commit>` suffit (aucune migration à annuler).
2. `SKIP_JUDGE=1` n'a plus d'effet mais ne casse rien (variable ignorée).
3. Les fichiers `raw.json` historiques restent lisibles (les clés nouvelles
   sont simplement ignorées par un consommateur ne les connaissant pas).

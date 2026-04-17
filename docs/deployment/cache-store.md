# Cache store — choix et évolution

**Date** : 2026-04-17
**Auteur** : fz
**Contexte** : incident production post-9e3e8c0 (merge de la Vague 5 tuteur + rack-attack).

## TL;DR

Le cache store de production est **Redis** (`:redis_cache_store`), partagé avec l'URL `REDIS_URL` déjà utilisée par Sidekiq. Pas de Solid suite.

## Pourquoi pas `solid_cache_store`

Rails 8 ship `config.cache_store = :solid_cache_store` par défaut. Ça suppose une table `solid_cache_entries` dans une base `cache` déclarée dans `config/database.yml`. Sur ce projet :

- `config/database.yml` déclare bien les 4 bases logiques `primary`, `cache`, `queue`, `cable` pointant toutes sur la même URL Neon (`<<: *primary_production`).
- **Les répertoires de migration `db/cache_migrate/`, `db/queue_migrate/`, `db/cable_migrate/` n'existent pas**. `rails solid_cache:install` n'a jamais été exécuté.
- Tant que `Rails.cache` n'était pas sollicité activement, la table manquante restait dormante.
- Le merge de `feat/tutor-vague5-activation` (PR #44, 9e3e8c0) a activé **rack-attack** qui écrit dans `Rails.cache` à chaque requête → `PG::UndefinedTable: relation "solid_cache_entries" does not exist` → Puma crash → healthcheck `curl localhost:3000/up` échoue → Coolify bloque le déploiement.

## Pourquoi Redis et pas Solid

Matrice de charge évaluée pour passer proprement sur Solid :

| Item | Charge |
|---|---|
| Générer migrations (`solid_cache:install`) | 10 min |
| Valider config multi-DB sur Neon (1 backend, 4 bases logiques) | 20 min |
| Faire tourner migrations (Neon refuse DDL via pooled URL → patch entrypoint pour `DATABASE_DIRECT_URL`) | 15-30 min |
| Déployer + vérifier WAL Neon, pool de connexions | 15 min nominal, 1h+ si coince |
| Arbitrage `solid_queue` et `solid_cable` (on garde Sidekiq + Redis Cable, donc dette cognitive) | 10 min |
| **Total nominal** | **~1h-1h30** |
| **Total réaliste** (1-2 itérations sur Neon) | **~2h-3h** |

Versus **option Redis** :
- `REDIS_URL` déjà injecté en prod (Coolify → Sidekiq).
- 1 seul fichier touché (`config/environments/production.rb`).
- 0 migration, 0 nouvelle gem (la gem `redis` est déjà dans `Gemfile.lock`).
- **Charge réelle** : ~15 min.

**Verdict** : pour un monolithe Rails solo MVP avec Redis déjà provisionné, Solid est de la sur-ingénierie (cf. constitution V "simplicity over performance"). On retient Redis.

## Config actuelle

`config/environments/production.rb` :

```ruby
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL"),
  namespace: "cache",
  expires_in: 1.day,
  reconnect_attempts: 1,
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.error("[cache] #{method} failed (#{exception.class}: #{exception.message}) — returning #{returning.inspect}")
  }
}
```

- `namespace: "cache"` évite de percuter les clés Sidekiq (préfixe `sidekiq:*`).
- `reconnect_attempts: 1` évite de bloquer une requête HTTP sur un Redis flaky.
- `error_handler` log sans faire crasher la requête : si Redis tombe, Rails.cache retourne `nil` et rack-attack laisse passer.

## Consommateurs actuels

- `Rack::Attack.cache` (défaut = `Rails.cache`) → throttles `tutor/messages/student` et `req/ip`.
- Fragment caching Rails (`config.action_controller.perform_caching = true`).
- Pas de `Rails.cache.fetch` applicatif dans le code métier à ce jour.

## Migration future vers Solid (si un jour)

Prérequis pour envisager Solid :
1. **Usage cache qui justifie la persistance durable** (aujourd'hui rack-attack + fragments = rien d'intéressant à conserver à un redémarrage).
2. **Budget Redis qui devient un problème** (pas le cas, Redis Coolify est en container local sur le VPS).
3. **Besoin de cohabiter cache + queue + cable sur le même backend que Postgres** pour simplifier l'ops (peu probable tant qu'on ne passe pas à Solid Queue — qui reste hors scope : Sidekiq + Redis marche).

Si les 3 prérequis sont réunis, étapes :

```bash
# 1. Générer les migrations Solid
bin/rails solid_cache:install
# → crée db/cache_migrate/*_create_solid_cache_entries.rb + config/cache.yml (déjà présent ici)

# 2. Ajuster l'entrypoint Docker pour que db:migrate tape Neon direct (pas pooled)
# docker-entrypoint actuellement : `bundle exec rails db:migrate && bundle exec rails server`
# Remplacer la migration par :
# DATABASE_URL="$DATABASE_DIRECT_URL" bundle exec rails db:prepare
# (db:prepare crée les bases manquantes et migre — utile si on réactive solid_queue/cable plus tard)

# 3. Revenir sur cache_store
# config/environments/production.rb :
# config.cache_store = :solid_cache_store

# 4. Vérifier Neon
# - Pool de connexions : 4 bases × RAILS_MAX_THREADS × processus Puma (+ Sidekiq) ≤ 100 (limite Neon pooled).
# - WAL : solid_cache écrit à chaque throttle rack-attack. Monitor taille WAL + purge (solid_cache gère TTL via max_age).
# - `config/cache.yml` : `max_size: 256.megabytes` déjà prêt ; vérifier que le trim background s'exécute.

# 5. Déployer, observer les métriques 24-48h avant de reconsidérer Solid Queue / Solid Cable.
```

## À NE PAS FAIRE

- **Installer Solid partiellement** (cache seul) pour "essayer" : ça crée de la dette (migrations à maintenir, config/cache.yml à synchro) pour zéro gain user-facing.
- **Ajouter `solid_cache:install` sans ajuster l'entrypoint prod** : Neon refuse les DDL via PgBouncer → migration échoue en prod mais passe en dev → nouveau cycle de déploiement cassé.
- **Oublier le `namespace:`** dans la config Redis : rack-attack + Sidekiq peuvent écrire sur les mêmes clés par accident (rare mais nuisible).

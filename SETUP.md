# SETUP.md — Guide de démarrage complet
# DekatjeBakLa — Rails 8 + Neon + Coolify

## Prérequis

- Claude Code installé (`claude --version`)
- Node.js >= 18 (`node --version`)
- Ruby >= 3.3 et Rails >= 8 (`ruby --version`, `rails --version`)
- Compte Neon créé sur https://neon.tech (free tier suffisant)
- Compte GitHub (pour le déploiement Coolify)

---

## Étape 1 — Créer le projet Rails

```bash
rails new dekatje-bak-la \
  --database=postgresql \
  --skip-test \
  --asset-pipeline=propshaft
cd dekatje-bak-la
git init && git add . && git commit -m "init: rails new"
```

Ajouter au `Gemfile` :

```ruby
# Auth
gem "devise"

# Jobs
gem "sidekiq"

# PDF
gem "pdf-reader"

# IA (HTTP client léger)
gem "faraday"
gem "faraday-multipart"

# Tests
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

```bash
bundle install
```

---

## Étape 2 — Configurer Neon

1. Sur https://neon.tech → créer un projet "dekatje-bak-la"
2. Récupérer les deux URLs depuis "Connect" :
   - **Pooled** (avec `-pooler` dans le hostname) → `DATABASE_URL`
   - **Direct** (sans `-pooler`) → `DATABASE_DIRECT_URL`

Créer `.env` à la racine (jamais commité) :

```bash
DATABASE_URL=postgresql://user:pass@ep-xxx-pooler.region.aws.neon.tech/neondb?sslmode=require
DATABASE_DIRECT_URL=postgresql://user:pass@ep-xxx.region.aws.neon.tech/neondb?sslmode=require
REDIS_URL=redis://localhost:6379/0
ANTHROPIC_API_KEY=sk-ant-xxx
RAILS_ENV=development
```

Mettre à jour `config/database.yml` :

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV['DATABASE_URL'] %>

development:
  <<: *default

test:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>

production:
  <<: *default
```

```bash
bin/rails db:create
```

---

## Étape 3 — Installer les outils IA

### Task Master

```bash
npm install -g task-master-ai
task-master init
```

Cela crée `.taskmaster/` dans ton projet.
Le PRD est déjà prêt dans `.taskmaster/docs/prd.txt` (copier le fichier fourni).

### SpecKit

```bash
uvx --from git+https://github.com/github/spec-kit.git \
  specify init . --ai claude --ai-skills --here
```

Cela installe les slash commands SpecKit dans `.claude/commands/`.
Copier le fichier `speckit/constitution.md` fourni.

### Superpowers (via Claude Code)

Lance Claude Code dans le dossier projet :

```bash
claude
```

Puis dans l'interface Claude Code :

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

Redémarre Claude Code. Tu verras le hook de session démarrer automatiquement.

---

## Étape 4 — Configurer les MCPs Claude Code

Créer/modifier `~/.claude/config.json` :

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ton_token_github"
      }
    },
    "postgres": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres",
        "postgresql://user:pass@ep-xxx.region.aws.neon.tech/neondb?sslmode=require"
      ]
    },
    "taskmaster": {
      "command": "npx",
      "args": ["-y", "--package=task-master-ai", "task-master-ai"],
      "env": {
        "ANTHROPIC_API_KEY": "sk-ant-xxx"
      }
    }
  }
}
```

Note : utiliser la connexion DIRECTE (non-poolée) pour le MCP PostgreSQL.

---

## Étape 5 — Workflow de démarrage dans Claude Code

Lance `claude` dans le dossier projet. Superpowers démarre automatiquement.

### Phase A — Parser le PRD avec Task Master

```
Can you parse my PRD at .taskmaster/docs/prd.txt and generate the initial tasks?
```

Task Master va créer un `tasks.json` structuré avec dépendances et complexités.

### Phase B — Générer la spec SpecKit

```
/speckit.constitution
```
(Coller le contenu de `speckit/constitution.md` quand demandé)

```
/speckit.specify
```
Décris à l'agent : "Application Rails 8 d'entraînement BAC STI2D, voir CLAUDE.md"

```
/speckit.plan
```
Fournis les contraintes : "Rails 8 + Neon + Coolify + Sidekiq + Turbo Streams"

### Phase C — Implémenter tâche par tâche

```
What's the next task I should work on?
```

Task Master répond avec la tâche prioritaire. Puis :

```
/brainstorm
```

Superpowers lance le workflow Socratic → Plan → TDD → implémentation.

---

## Étape 6 — Déployer sur Coolify

### Prérequis Coolify
- Repo GitHub créé et pushé
- Redis créé comme service dans Coolify (one-click)

### Configuration dans Coolify
1. New Resource → Application → GitHub repo
2. Build Pack : **Nixpacks** (auto-détecte Rails)
3. Start Command :
   ```
   bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p 3000
   ```
4. Variables d'environnement :
   ```
   DATABASE_URL=postgresql://...pooler...
   DATABASE_DIRECT_URL=postgresql://...direct...
   REDIS_URL=redis://ton-redis-coolify:6379/0
   RAILS_MASTER_KEY=<contenu de config/master.key>
   RAILS_ENV=production
   ANTHROPIC_API_KEY=sk-ant-xxx
   SECRET_KEY_BASE=<généré par rails secret>
   ```
5. Health Check Path : `/up` (Rails 8 l'expose par défaut)

### Sidekiq comme service séparé (recommandé)
Dans Coolify, créer un second service depuis le même repo avec :
- Start Command : `bundle exec sidekiq`
- Mêmes variables d'environnement
- Pas de domaine public

---

## Ordre d'implémentation recommandé

1. `F1` Auth (Devise + rôles) → base de tout
2. `F2` Upload sujets (ActiveStorage + formulaire)
3. `F3` Pipeline extraction (Sidekiq + Claude API)
4. `F4` Validation enseignant (interface révision)
5. `F5` Upload leçons (similaire à F2, plus simple)
6. `F6` Espace élève navigation
7. `F8` Config clé API élève (avant F7)
8. `F7` Agent tutorat streaming

---

## Ressources utiles

- Neon + Rails : https://neon.com/docs/guides/ruby-on-rails
- Coolify + Rails : https://coolify.io/docs/applications/rails
- Task Master : https://github.com/eyaltoledano/claude-task-master
- Superpowers : https://github.com/obra/superpowers
- SpecKit : https://github.com/github/spec-kit

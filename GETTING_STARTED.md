# GETTING_STARTED.md — Guide de démarrage
# DekatjeBakLa — Claude Code + Coolify

---

## Avant de commencer : checklist

- [ ] Ruby 3.3+ installé (`ruby --version`)
- [ ] Rails 8+ installé (`rails --version`)
- [ ] Node.js 18+ installé (`node --version`)
- [ ] Claude Code installé (`claude --version`)
- [ ] Compte Neon créé : https://neon.tech
- [ ] Compte GitHub avec repo créé (vide)
- [ ] Accès à ton VPS Coolify
- [ ] Clé API Anthropic disponible (pour l'extraction PDF serveur)

---

## Étape 0 — Placer les fichiers de contexte

Copie les 4 fichiers de ce kit dans la racine de ton futur projet Rails :

```
ton-projet/
├── CLAUDE.md          ← lu automatiquement par Claude Code à chaque session
├── DECISIONS.md       ← journal des décisions de conception (à importer dans CLAUDE.md)
├── SETUP.md           ← ce guide étendu
├── speckit/
│   └── constitution.md
└── .taskmaster/
    └── docs/
        └── prd.txt
```

---

## Étape 1 — Créer le projet Rails

```bash
rails new dekatje-bak-la \
  --database=postgresql \
  --skip-test \
  --asset-pipeline=propshaft

cd dekatje-bak-la
```

Copier les fichiers du kit dans ce dossier, puis :

```bash
git init
git add .
git commit -m "init: rails new + kit DekatjeBakLa"
git remote add origin git@github.com:TON_USER/dekatje-bak-la.git
git push -u origin main
```

---

## Étape 2 — Configurer Neon

1. Sur https://neon.tech → New Project → nom : "dekatje-bak-la"
2. Cliquer "Connect" → récupérer les deux URLs :
   - **Pooled** (hostname avec `-pooler`) → `DATABASE_URL`
   - **Direct** (hostname sans `-pooler`) → `DATABASE_DIRECT_URL`

Créer `.env` à la racine (ajouté au `.gitignore`) :

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

production:
  <<: *default
```

Tester la connexion :

```bash
bin/rails db:create
# → Created database 'neondb'
```

---

## Étape 3 — Installer les gems essentielles

Ajouter au `Gemfile` :

```ruby
gem "devise"
gem "sidekiq"
gem "pdf-reader"
gem "faraday"
gem "faraday-multipart"
gem "dotenv-rails", groups: [:development, :test]

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
bin/rails generate rspec:install
```

---

## Étape 4 — Installer Task Master

```bash
npm install -g task-master-ai
task-master init
```

Le dossier `.taskmaster/` est créé. Le PRD est déjà dans `.taskmaster/docs/prd.txt`.

---

## Étape 5 — Installer SpecKit

```bash
uvx --from git+https://github.com/github/spec-kit.git \
  specify init . --ai claude --ai-skills --here
```

Les slash commands SpecKit sont installées dans `.claude/commands/`.

---

## Étape 6 — Configurer les MCPs Claude Code

Éditer `~/.claude/config.json` (créer si inexistant) :

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_TON_TOKEN"
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

⚠️ Le MCP PostgreSQL utilise la **connexion directe** (sans `-pooler`).

---

## Étape 7 — Installer Superpowers dans Claude Code

Ouvre Claude Code dans le projet :

```bash
claude
```

Dans l'interface Claude Code :

```
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

Quitte et relance Claude Code. Tu verras au démarrage :
```
<session-start-hook> You have Superpowers. Go read SKILL.md...
```

---

## Étape 8 — Lier DECISIONS.md dans CLAUDE.md

**Sans modifier CLAUDE.md**, ajoute une ligne d'import manuellement
dans le fichier une seule fois, en début de fichier :

```markdown
# CLAUDE.md — DekatjeBakLa
# @import DECISIONS.md

[reste du fichier...]
```

Claude Code lit les directives `@import` et charge DECISIONS.md dans son contexte.
Ça donne accès à toutes les décisions D1→D15 sans surcharger CLAUDE.md.

---

## Étape 9 — Premier démarrage de session Claude Code

Lance `claude` dans le dossier projet. Superpowers démarre.
Puis dans l'ordre :

### A — Parser le PRD (une seule fois)

```
Parse my PRD at .taskmaster/docs/prd.txt and generate the initial tasks.
Analyze complexity and suggest which tasks need to be broken into subtasks.
```

Task Master génère `tasks.json` avec ~35-45 tâches ordonnées.

### B — Initialiser la spec SpecKit (une seule fois)

```
/speckit.constitution
```
Colle le contenu de `speckit/constitution.md` quand demandé.

```
/speckit.specify
```
Décris : "Application Rails 8 d'entraînement BAC, voir CLAUDE.md et DECISIONS.md"

```
/speckit.plan
```
Fournis : "Rails 8 + Neon + Coolify + Sidekiq + Turbo Streams, dev solo"

### C — Démarrer le développement

```
What's the next task I should work on?
```

Pour chaque tâche, Superpowers déclenche automatiquement :
`brainstorm → plan → TDD → implémentation → code review`

---

## Étape 10 — Déployer sur Coolify

### 10.1 — Créer Redis dans Coolify

Dashboard Coolify → New Service → Redis (one-click)
Récupère l'URL interne : `redis://dekatje-redis:6379/0`

### 10.2 — Créer le service Rails

1. New Resource → Application → GitHub
2. Sélectionne le repo `dekatje-bak-la`
3. Build Pack : **Nixpacks**
4. Start Command :
   ```
   bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0 -p 3000
   ```
5. Health Check Path : `/up`
6. Variables d'environnement :

```
DATABASE_URL          postgresql://...pooler...?sslmode=require
DATABASE_DIRECT_URL   postgresql://...direct...?sslmode=require
REDIS_URL             redis://dekatje-redis:6379/0
RAILS_MASTER_KEY      [contenu de config/master.key]
RAILS_ENV             production
ANTHROPIC_API_KEY     sk-ant-xxx
SECRET_KEY_BASE       [résultat de: rails secret]
```

### 10.3 — Créer le service Sidekiq

1. New Resource → Application → même repo GitHub
2. Build Pack : **Nixpacks**
3. Start Command : `bundle exec sidekiq`
4. **Pas de domaine** (service interne uniquement)
5. Mêmes variables d'environnement que le service Rails

### 10.4 — Vérifier le déploiement

```bash
# Depuis le terminal Coolify ou en SSH
curl https://ton-domaine.fr/up
# → {"status":"ok"}
```

---

## Commandes de session courantes

```bash
# Démarrer une session de dev
claude                          # ouvre Claude Code dans le projet

# Dans Claude Code — gestion des tâches
"What's the next task?"
"Mark task 3 as complete"
"Expand task 5 into subtasks"

# Dans Claude Code — qualité
/brainstorm                     # Superpowers : explorer une feature
/execute-plan                   # Superpowers : implémenter avec TDD

# Terminal
bin/rails s                     # serveur dev
bin/rails db:migrate            # migrations
bundle exec sidekiq             # worker (second terminal)
bundle exec rspec               # tests
bin/rails c                     # console Rails
```

---

## Ordre d'implémentation recommandé

Suivre les dépendances Task Master. L'ordre naturel :

```
F1  Auth teacher (Devise)          → base de tout
F2  Gestion classes + comptes élèves
F3  Upload sujets + DT/DR
F4  Pipeline extraction (Sidekiq + Claude)
F5  Interface validation enseignant
F6  Upload leçons
F7  Espace élève Mode 0 (navigation + sticky panel + DT/DR viewer)
F9  Config clé API élève
F8  Mode 1 (correction + data_hints)
F10 Mode 2 (agent tutorat streaming)
```

**Ne pas sauter F1/F2** — toutes les features dépendent de l'auth.

---

## Rappels critiques

⚠️ **Deux URLs Neon** : poolée pour l'app, directe pour les migrations. Ne jamais inverser.

⚠️ **RAILS_MASTER_KEY** : ne jamais committer `config/master.key`. Le mettre uniquement dans Coolify.

⚠️ **Clés API élèves** : chiffrées avec `encrypts :api_key` côté Rails. Ne jamais logger.

⚠️ **RGPD** : aucun email élève. Pas d'inscription libre. Comptes créés par l'enseignant uniquement.

⚠️ **TDD** : Superpowers enforce le test avant le code. Si Claude écrit du code sans test, c'est un bug de workflow.

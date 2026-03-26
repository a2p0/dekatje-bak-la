# DECISIONS.md — Journal des décisions de conception
# DekatjeBakLa — Session de conception initiale (mars 2026)

Ce document trace les décisions architecturales et leurs justifications.
Il est destiné à être lu par Claude Code au démarrage de chaque session
pour éviter de remettre en question des choix déjà arbitrés.

---

## D1 — Stack : Rails 8 fullstack + Hotwire (pas Vue.js séparé)

**Décision** : Rails 8 fullstack avec Hotwire/Turbo Streams. Pas de SPA Vue.js.

**Justification** :
- Dev solo : une seule app à déployer, pas deux services à synchroniser
- L'expérience principale (navigation questions, streaming IA) est couverte
  nativement par Turbo Streams sans JavaScript custom
- Vue.js aurait doublé la complexité de déploiement Coolify (CORS, deux pipelines)
- Rails connu du développeur — courbe d'apprentissage nulle
- Possibilité d'ajouter des composants Vue/React isolés ("islands") plus tard
  sur des pages spécifiques sans réécriture

**Alternative rejetée** : Rails API + Vue.js séparé

---

## D2 — Base de données : Neon PostgreSQL (externe managé)

**Décision** : Neon free tier comme DB managée externe.

**Justification** :
- Zéro maintenance, backups automatiques inclus
- PostgreSQL standard → ActiveRecord sans config spéciale
- Deux URLs obligatoires : poolée (app) et directe (migrations Sidekiq)
- Free tier 0.5 GB suffisant pour le MVP
- Branchement DB (feature Neon) utile pour tester des migrations risquées
- Supabase rejeté car trop redondant avec Rails (Auth, Storage, API déjà gérés)
- PostgreSQL local Coolify rejeté car ajoute de la maintenance

**Config critique** :
```
DATABASE_URL      → connexion poolée PgBouncer (app Rails)
DATABASE_DIRECT_URL → connexion directe (migrations uniquement)
```

---

## D3 — Pas de Supabase

**Décision** : Supabase n'est pas dans la stack.

**Justification** :
Supabase remplace Rails (Auth, Storage, API auto-générée). Avec Rails,
il n'apporte aucune valeur ajoutée et ajoute 7 services Docker en
self-hosted ou une dépendance externe. Neon = PostgreSQL pur, c'est tout
ce dont Rails a besoin.

---

## D4 — Authentification double (Devise teacher + custom student)

**Décision** :
- Enseignants : Devise (email + password)
- Élèves : authentification custom (bcrypt, sans email, sans Devise)

**Justification** :
- RGPD + Éducation Nationale : aucun email élève collecté (élèves mineurs)
- Les élèves se connectent via `/classe/:access_code` avec username généré
- L'enseignant crée tous les comptes (pas d'inscription libre)
- Devise est surdimensionné pour les élèves (reset par email, confirmations...)
- L'enseignant réinitialise les mots de passe élèves directement

**Implication** : deux modèles distincts `User` (teacher/Devise) et `Student`
(custom auth). Ne pas fusionner en un seul modèle avec un champ role.

---

## D5 — Gestion de classes (RGPD)

**Décision** : modèle Classroom avec access_code, créé par l'enseignant.

**Justification** :
- Seule architecture légalement acceptable pour des mineurs en contexte scolaire FR
- L'enseignant est responsable de traitement pour sa classe
- L'access_code dans l'URL pré-sélectionne la classe au login élève
- Export fiches de connexion (PDF/CSV) pour distribution papier
- Pas d'email élève = pas de consentement RGPD individuel à gérer

**Hors MVP** : co-enseignants (ClassroomMembership)

---

## D6 — Clé API : enseignant prioritaire, serveur en fallback

**Décision** : résolution de clé en deux étapes pour l'extraction PDF.

```ruby
key = teacher.api_key.presence || ENV['ANTHROPIC_API_KEY']
```

**Justification** :
- Permet à l'app de fonctionner sans clé enseignant (demo, test)
- Quand l'app scale vers plusieurs enseignants, chacun porte ses coûts
- La clé serveur devient optionnelle à terme

**Clé élève** : utilisée uniquement pour le tutorat (modes 1 et 2).
Mode 0 (lecture) = 0 appel IA, pas de clé requise.

---

## D7 — Multi-provider IA via interface unifiée

**Décision** : 4 providers supportés (OpenRouter, Anthropic, OpenAI, Google Gemini).
Un seul client HTTP (Faraday) avec `AiClientFactory`.

**Justification** :
- OpenRouter est un proxy universel — 1 seule intégration donne accès à tout
- Les élèves ont des abonnements variés (certains ont ChatGPT Plus, d'autres Gemini...)
- AiClientFactory isole les différences d'API entre providers
- Ne pas utiliser de gem spécialisée par provider pour éviter la prolifération

**Service objects** :
- `ResolveApiKey` — résolution clé enseignant/serveur
- `AiClientFactory` — instanciation client selon provider
- `StreamAiResponse` — streaming SSE → Turbo Streams
- `ExtractQuestionsFromPdf` — pipeline extraction complet

---

## D8 — Structure du sujet : Subject → Parts → Questions

**Décision** : modèle hiérarchique à 3 niveaux + sous-questions.

```
Subject
  presentation_text    ← mise en situation générale
  └── Part (section_type: common/specific)
        objective_text ← accessible en sticky panel
        └── Question
              context_text ← intro locale de la question
              answer_type  ← text|calculation|argumentation|dr_reference|completion|choice
              └── Answer
                    data_hints ← où étaient les données utiles
```

**Justification** : les sujets BAC STI2D ont 5 parties avec objectifs propres.
La partie commune (12 pts) est identique pour toutes les spécialités.
La partie spécifique (8 pts) varie. `section_type: common/specific` permet
de réutiliser la partie commune entre variantes du même sujet.

---

## D9 — Documents Techniques et Réponse (DT/DR)

**Décision** :
- `TechnicalDocument` avec `doc_type: DT|DR`
- DT : un seul `file` (PDF affiché/téléchargeable)
- DR : `file` (vierge, pour l'élève) + `filled_file` (corrigé, affiché à la correction)
- Pas d'extraction d'images dans le MVP
- Le PDF est la source de vérité pour les images/schémas

**Justification** :
Dans les sujets BAC, la correction de beaucoup de questions est "Voir DR1 rempli".
Les DT/DR sont des PDFs natifs — les afficher entiers est la solution la plus simple
et la plus fidèle. L'extraction d'images (Poppler) est une évolution future.

**Jointure** : `QuestionDocument` relie chaque question aux DT/DR qu'elle référence.
Généré automatiquement par le prompt d'extraction ("voir DT2, DR1").

---

## D10 — data_hints dans Answer

**Décision** : champ JSON `data_hints` sur `Answer`, généré par Claude à l'extraction.

**Format** :
```json
[
  {"source": "DT1", "location": "tableau, ligne Consommation moyenne"},
  {"source": "mise_en_situation", "location": "distance Troyes-Le Bourget : 186 km"},
  {"source": "question_context", "location": "valeur F = 19600 N"}
]
```

**Justification** : les élèves ratent souvent des questions non pas parce qu'ils
ne savent pas calculer, mais parce qu'ils n'ont pas trouvé les données dans le sujet.
Afficher les data_hints après la correction est une aide pédagogique directe.

---

## D11 — Surlignage texte : hors MVP, architecture prête

**Décision** : champ `annotations` JSON réservé sur `StudentSession`, implémentation
Stimulus post-MVP. Pas ActionText (outil de création, pas d'annotation de lecture).

**Justification** :
ActionText est un éditeur Trix pour créer du contenu riche — pas adapté au
surlignage de texte existant en lecture. L'API Range du navigateur + un
Stimulus controller + un champ JSON suffit.

**Champ prévu dès le MVP** pour éviter une migration ultérieure.
**Implémentation** : post-MVP.

---

## D12 — Jobs asynchrones : Sidekiq + Redis

**Décision** : Sidekiq pour l'extraction PDF, Redis comme broker.

**Justification** :
L'extraction PDF (pdf-reader + appel Claude API) peut prendre 30-60 secondes.
Un job synchrone bloquerait le thread Rails et timeouterait Coolify.
Sidekiq tourne comme second service Coolify depuis le même repo.
Redis = service one-click dans Coolify.

**Notification temps réel** : Turbo Stream broadcast depuis le job Sidekiq
quand l'extraction est terminée. L'enseignant voit le statut sans recharger.

---

## D13 — Déploiement : Coolify + Nixpacks

**Décision** : Nixpacks comme build pack (pas Dockerfile custom).

**Justification** :
Nixpacks détecte automatiquement Rails et génère la config correcte.
Aucun Dockerfile à maintenir. Coolify gère Traefik + SSL automatiquement.
Sidekiq = second service Coolify depuis le même repo Git, mêmes env vars.

**Start Command** :
```
bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0
```

**Variables critiques** : DATABASE_URL (poolée), DATABASE_DIRECT_URL (directe),
REDIS_URL, RAILS_MASTER_KEY, ANTHROPIC_API_KEY (fallback extraction).

---

## D14 — Assets locaux (pas de CDN)

**Décision** : Importmap ou Propshaft, assets servis localement.

**Justification** :
Bande passante Internet parfois limitée dans les salles de classe en Martinique.
Pas de dépendance à des CDN externes (Bootstrap CDN, Tailwind CDN, etc.).
Timeout appels IA : 60 secondes minimum configuré dans Faraday.

---

## D15 — Nom : DekatjeBakLa

**Décision** : nom de l'application = "DekatjeBakLa"
Nom technique : `dekatje-bak-la`

**Justification** : "décrocher le bac" en créole martiniquais.
Ancré localement, mémorisable, avec une vraie personnalité.
L'application est destinée en priorité aux élèves de Martinique (STI2D),
mais le modèle est générique (multi-matières, multi-bac).

---

## Évolutions futures documentées (hors MVP)

- Co-enseignants sur une classe (ClassroomMembership)
- OCR leçons scannées (Tesseract ou Claude Vision)
- Extraction images des PDFs (Poppler/pdfimages)
- Surlignage texte (Stimulus + annotations JSON)
- Statistiques progression par classe (dashboard teacher)
- Fiches de révision persistées et exportables
- Mode examen chronométré
- Import CSV élèves
- Multi-établissements

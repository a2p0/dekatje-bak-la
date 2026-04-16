# CLAUDE.md — DekatjeBakLa

## Présentation
**DekatjeBakLa** ("décrocher le bac" en créole martiniquais)
Application web d'entraînement aux examens BAC, multi-matières, multi-bac.
Développeur solo, enseignant STI2D en Martinique.
Nom technique : `dekatje-bak-la`

---

## Stack technique
- **Backend** : Ruby on Rails 8 (fullstack, Hotwire/Turbo Streams)
- **Base de données** : PostgreSQL via Neon (externe managé)
- **Jobs asynchrones** : Sidekiq + Redis
- **Stockage fichiers** : ActiveStorage (volume Docker local sur VPS)
- **Auth** : Devise (enseignants) + custom bcrypt (élèves, sans email)
- **IA extraction PDF** : clé enseignant prioritaire, `ANTHROPIC_API_KEY` serveur en fallback
- **IA tutorat/feedback** : clé élève (OpenRouter, Anthropic, OpenAI, Google Gemini)
- **Streaming réponses IA** : Turbo Streams + SSE
- **Tests** : RSpec + FactoryBot + Capybara

---

## Modèle de données complet

```
User (enseignant)
  - email, password (Devise)
  - first_name, last_name
  - api_key chiffré        ← extraction PDF
  - api_provider (enum: anthropic, openrouter, openai, google)

Classroom
  - name, school_year, specialty
  - access_code            ← slug URL login élève (ex: terminale-sin-2026)
  - belongs_to :owner (User)

Student
  - first_name, last_name
  - username               ← généré: prenom.nom + suffixe si doublon
  - password_digest (bcrypt, sans email)
  - api_key chiffré        ← tutorat IA
  - api_provider (enum: openrouter, anthropic, openai, google)
  - belongs_to :classroom

ClassroomSubject           ← jointure
  - classroom, subject

Subject
  - title, year
  - exam_type (enum: bac, bts, autre)
  - specialty (enum: tronc_commun, SIN, ITEC, EC, AC, ...)
  - status (enum: draft, pending_validation, published, archived)
  - presentation_text      ← mise en situation générale, accessible à tout moment
  - discarded_at           ← soft delete
  - belongs_to :owner (User)
  - has_many :parts
  - has_many :technical_documents

TechnicalDocument
  - doc_type (enum: DT, DR)
  - number (entier, ex: 1 → affiché "DT1")
  - title
  - has_one_attached :file         ← PDF principal (DT info, ou DR vierge)
  - has_one_attached :filled_file  ← DR corrigé (uniquement si DR, optionnel)
  # Stratégie images : les PDFs sont stockés et affichés/téléchargeables tels quels.
  # Pas d'extraction d'images dans le MVP.
  # Extraction d'images brutes (Poppler) = évolution future.
  - belongs_to :subject

Part
  - number (1, 2, 3...)
  - title
  - objective_text         ← accessible à tout moment via sticky panel
  - section_type (enum: common, specific)
    # common   → partie commune (ex: 12 pts, 2h30, identique toutes spécialités)
    # specific → partie spécifique par spécialité (ex: 8 pts, 1h30)
  - position
  - belongs_to :subject
  - has_many :questions

Question
  - number (ex: "1.1", "2.3")
  - label                  ← énoncé complet
  - context_text           ← intro locale, données spécifiques à la question
  - points (barème)
  - answer_type (enum: text, calculation, argumentation,
                        dr_reference, completion, choice)
  - position
  - status (enum: draft, validated)
  - discarded_at
  - belongs_to :part
  - has_many :question_documents
  - has_one :answer

QuestionDocument           ← jointure Question ↔ TechnicalDocument
  - question, technical_document

Answer
  - correction_text        ← texte de correction officielle
  - explanation_text       ← explication pédagogique
  - key_concepts (JSON array)
  - data_hints (JSON array)
    # Généré par Claude lors de l'extraction, affiché après la correction.
    # Indique précisément où se trouvaient les données utiles :
    # [
    #   {source: "DT1", location: "tableau, ligne Consommation moyenne"},
    #   {source: "mise_en_situation", location: "distances Troyes-Le Bourget"},
    #   {source: "question_context", location: "valeur F = 19600 N"}
    # ]
  - belongs_to :question

ExtractionJob
  - status (enum: pending, processing, done, failed)
  - raw_json
  - error_message
  - provider_used (enum: teacher, server)
  - belongs_to :subject

StudentSession
  - mode (enum: autonomous, tutored)
  - progression (JSON)     ← {question_id: {seen: bool, answered: bool}}
  - annotations (JSON)     ← RÉSERVÉ post-MVP pour surlignage
    # {question_42: [{start: 45, end: 89, color: "yellow", note: ""}]}
  - started_at, last_activity_at
  - belongs_to :student
  - belongs_to :subject

Conversation
  - messages (JSON array)
  - provider_used
  - tokens_used
  - belongs_to :student_session
  - belongs_to :question
```

---

## Navigation élève — principes clés

### Mise en situation accessible à tout moment
À n'importe quelle étape, un sticky panel (sidebar ou drawer) expose :
1. `Subject#presentation_text` — mise en situation générale du sujet
2. `Part#objective_text` — objectif de la partie courante

Implémentation : Stimulus controller `context-panel`, contenu via Turbo Frame.

### Correction : indication des données utiles
Après affichage de la correction, un encadré "Où trouver les données ?" liste
les `data_hints` de l'Answer. Ex :
> "Les données nécessaires se trouvaient dans **DT1** (tableau Consommation moyenne)
> et dans la **mise en situation** (distance Troyes-Le Bourget : 186 km)."

### DT/DR : affichage PDF natif
- DT : PDF affiché en iframe + lien téléchargement
- DR vierge : téléchargeable par l'élève
- DR corrigé : affiché uniquement lors de la correction (`filled_file`)
- Pas d'extraction d'images : le PDF est la source de vérité

---

## Pipeline d'extraction PDF

```
PDF upload (teacher)
  → ActiveStorage + ExtractionJob(pending) + Sidekiq enqueue

Sidekiq job ExtractQuestionsFromPdf :
  → pdf-reader : texte brut
  → ResolveApiKey : teacher.api_key || ENV['ANTHROPIC_API_KEY']
  → Claude API avec prompt structuré
  → JSON cible :
    {
      presentation: "Mise en situation générale...",
      technical_documents: [
        {type: "DT", number: 1, title: "Diagrammes SysML CIME"}
      ],
      parts: [{
        number: 1,
        title: "Comment le CIME s'inscrit dans une démarche DD ?",
        objective: "Comparer modes de transport...",
        section_type: "common",
        questions: [{
          number: "1.2",
          label: "Calculer la consommation en litres...",
          context: "",
          points: 2,
          answer_type: "calculation",
          dt_dr_refs: [],
          correction: "Car = 56,73 l / Van = 38,68 kWh",
          data_hints: [
            {source: "tableau_sujet", location: "ligne Consommation moyenne 30,5 l/100km"},
            {source: "enonce", location: "distance Troyes-Le Bourget 186 km"}
          ],
          key_concepts: ["énergie primaire", "rendement"]
        }]
      }]
    }
  → Persistence : Subject → Parts → Questions → Answers
  → ExtractionJob(done)
  → Turbo Stream notification enseignant
```

---

## Modes d'interaction élève

| Mode | Déclencheur | Tokens | Clé requise |
|---|---|---|---|
| 0 — Lecture | Automatique | 0 | Non |
| 1 — Révision | Bouton feedback | Modérés | Oui (élève) |
| 2 — Tutorat | Bouton chat | Élevés | Oui (élève) |

### System prompt agent tutorat (base)
```
Tu es un tuteur bienveillant pour des élèves de Terminale préparant le BAC.
Spécialité : {specialty}. Partie : {part_title}. Objectif : {objective_text}.
Question : {question_label}. Contexte local : {context_text}.
Correction officielle (confidentielle) : {correction_text}.
Règle absolue : ne donne JAMAIS la réponse directement.
Guide l'élève par étapes, valorise ses tentatives, pose des questions.
Propose une fiche de révision si un concept clé est identifié.
Cite les leçons disponibles dans la spécialité si pertinent.
Réponds en français, niveau lycée, de façon bienveillante.
```

---

## Auth

### Enseignant (Devise)
Routes : `/teacher/...`

### Élève (custom bcrypt)
- URL de connexion : `/{access_code}` (slug de la classe)
- Identifiants fournis par l'enseignant (fiche papier)
- Aucun email collecté → conformité RGPD mineurs
- Réinitialisation mot de passe par l'enseignant uniquement
- Export fiches connexion : PDF A4 imprimable

---

## Conventions Git

Tous les commits suivent la spec **Conventional Commits** :

```
<type>(<scope>): <description>

[body optionnel]
```

Types autorisés : `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`, `ci`

Exemples :
- `feat(auth): add student login via access_code`
- `fix(extraction): handle missing DT references in prompt`
- `chore(deps): add sidekiq and pdf-reader gems`
- `test(student): add factory and spec for Student model`

---

## Conventions Rails
- Migrations AVANT les modèles
- Service objects dans `app/services/`, nommés en verbe :
  `ExtractQuestionsFromPdf`, `StreamAiResponse`, `BuildTutorPrompt`,
  `GenerateStudentCredentials`, `ResolveApiKey`, `BuildExtractionPrompt`
- Thin controllers — toute logique dans les services
- Code en anglais, interface utilisateur en français
- Soft delete via `discarded_at` (Subject, Question)
- Une feature = une branche git

---

## Neon PostgreSQL
```yaml
# config/database.yml — toujours deux URLs distinctes
# DATABASE_URL       → poolée PgBouncer (app)
# DATABASE_DIRECT_URL → directe (migrations uniquement)
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV['DATABASE_URL'] %>
```

---

## Variables d'environnement Coolify
```
DATABASE_URL               # Neon poolée (?sslmode=require)
DATABASE_DIRECT_URL        # Neon directe (?sslmode=require)
REDIS_URL                  # Redis service Coolify
RAILS_MASTER_KEY           # config/master.key
RAILS_ENV=production
ANTHROPIC_API_KEY          # Fallback extraction PDF
SECRET_KEY_BASE            # rails secret
```

## Déploiement
- Build pack : **Nixpacks** (auto-détection Rails)
- Start command : `bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0`
- Sidekiq : second service Coolify, même repo, `bundle exec sidekiq`
- Health check path : `/up` (Rails 8 natif)

---

## Ordre d'implémentation MVP
1. Auth teacher Devise + gestion classes + création comptes élèves
2. Auth élève custom (login via /{access_code})
3. Upload sujets + DT/DR (ActiveStorage, PDF uniquement)
4. Pipeline extraction Sidekiq → Part/Question/Answer + data_hints
5. Interface validation enseignant (édition question par question)
6. Espace élève Mode 0 : navigation Part→Question + sticky context + viewer DT/DR
7. Espace élève Mode 1 : correction + data_hints affiché
8. Config clé API élève
9. Espace élève Mode 2 : agent tutorat streaming

## Post-MVP
- Surlignage texte (Stimulus controller + annotations JSON déjà prévu)
- Extraction images brutes PDF (Poppler/pdfimages)
- Co-enseignants sur une classe (ClassroomMembership)
- OCR leçons scannées
- Stats progression par classe (dashboard teacher)
- Mode examen chronométré
- Import CSV élèves
- Fiches de révision persistées et exportables

## Active Technologies
- Ruby 3.3+, Rails 8.1 + Devise, Sidekiq, pdf-reader, Faraday, Turbo Streams, Stimulus, ActiveStorage (001-bac-training-app)
- PostgreSQL via Neon (poolée app + directe migrations), Redis (Sidekiq), ActiveStorage (PDFs locaux) (001-bac-training-app)
- Ruby 3.3+ / Rails 8.1.3 + Hotwire (Turbo Streams, Stimulus), ViewComponent, Sidekiq, ActionCable (011-guided-tutor-spotting)
- PostgreSQL via Neon (JSONB pour l'état du tuteur) (011-guided-tutor-spotting)
- Ruby 3.3+ / Rails 8.1 + Devise, Sidekiq, pdf-reader, Faraday, Turbo Streams, Stimulus, ActiveStorage (015-extraction-consolidation)
- Ruby 3.3+ / Rails 8.1 + pdf-reader, Faraday, AiClientFactory (020-extraction-json-restructure)
- PostgreSQL via Neon (ExamSession.presentation_text, Subject.presentation_text — déjà existants) (020-extraction-json-restructure)
- Ruby 3.3+ / Rails 8.1 + Hotwire (Turbo Streams, Stimulus), ViewComponent, Tailwind CSS (021-student-subject-workflow)
- PostgreSQL via Neon (JSONB `progression` dans `student_sessions`) (021-student-subject-workflow)
- Ruby 3.3+ / Rails 8.1 + Tailwind CSS 4 (already installed), Plus Jakarta Sans (Google Fonts), Stimulus, ViewComponent (025-design-system)
- N/A (no schema changes) (025-design-system)
- Ruby 3.3+ / Rails 8.1 + Hotwire (Turbo Streams, Stimulus), ViewComponent, Tailwind CSS 4 (028-fix-t050-ui-bugs)
- PostgreSQL via Neon (JSONB `progression` and `tutor_state` in `student_sessions`) (028-fix-t050-ui-bugs)
- Ruby 3.3+ / Rails 8.1 + Devise, Stimulus, Turbo, Sidekiq, FactoryBot (031-rails-conventions-fix)
- Ruby 3.3+ / Rails 8.1 + Hotwire (Turbo Streams), Devise (authorization existante) (032-rest-subject-transitions)
- Ruby 3.3+ / Rails 8.1 + Hotwire (Turbo Streams), Devise, ResetStudentPassword service existant (033-rest-validation-password)
- Ruby 3.3+ / Rails 8.1 + Hotwire, Devise, Sidekiq, Prawn (PDF), existing export services (034-rest-extraction-assign-export)
- Ruby 3.3+ / Rails 8.1 + Hotwire, Devise, existant `GenerateStudentCredentials` service (035-rest-student-import)
- Ruby 3.3+ / Rails 8.1 + Hotwire (Turbo Streams), existant `ValidateStudentApiKey` service, `StudentSession` model (036-rest-student-actions)
- PostgreSQL via Neon (JSONB `progression` et `tutor_state` sur student_sessions) (036-rest-student-actions)
- Ruby 3.3+ / Rails 8.1 + `ruby_llm` (déjà présent au Gemfile), Hotwire (037-tutor-wire-tools)
- PostgreSQL Neon (aucune migration nécessaire — `TutorState` (037-tutor-wire-tools)
- Ruby 3.3+ / Rails 8.1 + `ruby_llm` (tutor + sim), rake (sim driver), (038-tutor-prompt-tuning)
- PostgreSQL Neon (aucune migration). (038-tutor-prompt-tuning)

## Recent Changes
- 001-bac-training-app: Added Ruby 3.3+, Rails 8.1 + Devise, Sidekiq, pdf-reader, Faraday, Turbo Streams, Stimulus, ActiveStorage

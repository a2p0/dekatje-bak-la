# Rails Conventions Skill + MCP Server — Design Spec

## Contexte

DekatjeBakLa compte 18 services, 12 Stimulus controllers, et un CLAUDE.md riche en contexte métier mais pauvre en conventions de code Rails. L'audit des services montre des incohérences (return nil vs hash vs raise) qui ne posent pas de problème aujourd'hui mais se propageront dans les nouveaux services si rien n'est documenté.

**Objectif** : donner à Claude Code et aux subagents les conventions Rails à suivre, la doc officielle à consulter, et l'état live du projet — sans toucher au code existant.

## Décisions prises

| Question | Réponse |
|---|---|
| Portée | Complet — 6 domaines (models, controllers, services, views/hotwire, jobs, tests) |
| Convention services | Raise + objet métier (les existants ne changent pas) |
| MCP server | `rails-mcp-server` via `.mcp.json` projet uniquement |
| Activation skill | Automatique dès que Claude Code touche du Ruby/ERB/JS |
| Architecture skill | Modulaire — SKILL.md principal + 6 fichiers references/ |
| Redondance better-stimulus | Aucune — views-hotwire.md couvre le côté serveur, better-stimulus couvre le JS |
| Universalité | Projet uniquement — évolution universelle plus tard si besoin |

## Composants

### 1. Skill `rails-conventions`

**Emplacement** : `~/.claude/skills/rails-conventions/`

#### SKILL.md (~100 lignes)

```yaml
---
name: rails-conventions
description: Apply Rails 8 conventions and best practices when writing Ruby, ERB, or Stimulus code
---
```

**Contenu** :

1. **Principes transversaux**
   - Convention over configuration
   - Code en anglais, interface utilisateur en français
   - Consulter context7 (`/websites/guides_rubyonrails_v8_0`) pour tout pattern Rails non trivial
   - Utiliser l'outil MCP `rails` (execute_tool, get_routes, analyze_models) pour connaître l'état actuel du projet avant de modifier des modèles, routes ou associations
   - YAGNI — pas d'abstraction prématurée

2. **Convention services** (inline car transversale)
   - Méthode publique : `self.call` uniquement
   - Nommage : verbe + nom (`ExtractQuestionsFromPdf`)
   - Succès → retourne l'objet métier
   - Échec → raise une exception custom (héritant de `StandardError`)
   - Les services existants ne sont pas refactorés

3. **Quick reference anti-patterns**

   | Ne fais pas | Fais plutôt | Réf. |
   |---|---|---|
   | Logique métier dans le controller | Service object | `references/services.md` |
   | `where()` dans le controller | Named scope | `references/models.md` |
   | JS inline dans les vues | Stimulus controller | `references/views-hotwire.md` |
   | `after_save` callback | `after_create_commit` ou service | `references/models.md` |
   | Fixtures | FactoryBot factories | `references/tests.md` |
   | N+1 queries | `includes()` / `preload()` | `references/models.md` |
   | Mock API calls sans VCR | VCR/WebMock cassettes | `references/tests.md` |

4. **Liens vers les références** — une ligne par domaine

#### references/models.md (~90 lignes)

**Validations**
- Utiliser les validateurs built-in en priorité (`presence`, `uniqueness`, `numericality`)
- Custom validators pour les règles métier complexes
- Contraintes DB (NOT NULL, UNIQUE index) pour les validations critiques — ceinture et bretelles

**Associations**
- Toujours déclarer `dependent:` sur `has_many` (`:destroy`, `:nullify`, ou `:restrict_with_error`)
- `inverse_of` pour les associations bidirectionnelles
- `counter_cache: true` quand on affiche des compteurs fréquemment (ex: nombre de questions par partie)

**Scopes et requêtes**
- Named scopes pour les requêtes réutilisables, chaînables
- Prévention N+1 : `includes()` pour les associations utilisées dans les vues, `preload()` quand on veut forcer des requêtes séparées, `eager_load()` quand on filtre sur l'association
- Index sur les FK et colonnes utilisées dans WHERE/ORDER

**Callbacks**
- Limiter à `before_validation` et `after_create_commit`
- Tout le reste → service object
- Jamais de callback qui appelle un service externe (API, email)

**Migrations**
- Toujours réversibles (`change` ou `up`/`down`)
- Index sur les foreign keys et colonnes fréquemment requêtées
- Types forts (éviter `string` pour tout)
- Considérer l'impact sur les données existantes

**Anti-patterns** :

Bad:
```ruby
# Callback qui fait trop de choses
after_save :send_notification, :update_stats, :sync_external
```

Good:
```ruby
# Callback minimal, le reste dans un service
after_create_commit :broadcast_creation

def broadcast_creation
  broadcast_prepend_to "subjects"
end
```

Bad:
```ruby
# N+1 dans le controller
@subjects = Subject.all
# Vue: subject.parts.each → N+1
```

Good:
```ruby
@subjects = Subject.includes(:parts).all
```

#### references/controllers.md (~70 lignes)

**RESTful**
- 7 actions max : index, show, new, create, edit, update, destroy
- Si une action ne rentre pas → nouveau controller (ex: `Students::PasswordResetsController`)
- Un controller par ressource

**Strong params**
```ruby
# Toujours dans une méthode privée
private

def student_params
  params.expect(student: [:first_name, :last_name, :password])
end
```

**before_action**
- Authentification et autorisation
- Setup des instance variables communes (`set_subject`, `set_classroom`)
- Garder simple et focalisé — pas de logique métier

**Réponses**
- Turbo Stream par défaut pour les actions create/update/destroy
- HTML fallback pour la navigation classique
- `rescue_from` pour les erreurs des services

```ruby
rescue_from ActiveRecord::RecordNotFound, with: :not_found
rescue_from AuthenticationError, with: :unauthorized

private

def not_found
  redirect_to root_path, alert: "Ressource introuvable"
end
```

**Routing**
- `resources` pour les routes RESTful
- Nesting max 1 niveau (`resources :classrooms { resources :students }`)
- `member` et `collection` avec parcimonie

**Anti-patterns** :

Bad:
```ruby
# Controller fat avec logique métier
def create
  @student = Student.new(student_params)
  @student.username = "#{@student.first_name}.#{@student.last_name}".downcase
  @student.password = SecureRandom.hex(4)
  if @student.save
    # ...
  end
end
```

Good:
```ruby
def create
  @student = GenerateStudentCredentials.call(
    classroom: @classroom,
    **student_params
  )
  redirect_to classroom_students_path(@classroom)
end
```

#### references/services.md (~70 lignes)

**Pattern standard**
```ruby
class ExtractQuestionsFromPdf
  def self.call(subject:, pdf_content:)
    new(subject:, pdf_content:).call
  end

  def initialize(subject:, pdf_content:)
    @subject = subject
    @pdf_content = pdf_content
  end

  def call
    api_key = ResolveApiKey.call(user: @subject.owner)
    raw_json = request_extraction(api_key)
    PersistExtractedData.call(subject: @subject, data: raw_json)
  end

  private

  def request_extraction(api_key)
    # ...
  end
end
```

**Règles**
- `self.call` comme seule méthode publique
- Nommage verbe + nom
- Succès → retourne l'objet métier (Student, Subject, String...)
- Échec → raise une exception custom
- Transaction DB quand plusieurs modèles sont créés/modifiés

**Exceptions custom**
```ruby
class ExtractQuestionsFromPdf
  class ParseError < StandardError; end
  class ApiKeyMissingError < StandardError; end

  def call
    raise ApiKeyMissingError, "Aucune clé API disponible" unless api_key
    # ...
  rescue JSON::ParserError => e
    raise ParseError, "Réponse API invalide : #{e.message}"
  end
end
```

**Dependency injection** (pour les services qui appellent des APIs externes)
```ruby
class StreamAiResponse
  def self.call(prompt:, client: nil)
    new(prompt:, client:).call
  end

  def initialize(prompt:, client: nil)
    @prompt = prompt
    @client = client || AiClientFactory.build(provider: :anthropic)
  end
end
```

Permet de mocker le client dans les tests sans monkey-patching.

**Quand créer un service**
- Logique qui implique plusieurs modèles
- Appel à une API externe
- Opération complexe appelée depuis plusieurs endroits
- Logique qui ne relève pas de la responsabilité du modèle

**Anti-patterns** :

Bad:
```ruby
# Retour incohérent
def call
  return { success: false, error: "not found" } unless @student
  { success: true, data: @student }
end
```

Good:
```ruby
def call
  raise ActiveRecord::RecordNotFound, "Élève introuvable" unless @student
  @student
end
```

#### references/views-hotwire.md (~90 lignes)

> Pour les conventions Stimulus controllers (JS), voir le skill `better-stimulus`. Cette référence couvre uniquement le côté serveur et les vues ERB.

**Partials**
- Nommés d'après le contenu, pas l'usage (`_student.html.erb`, pas `_student_row.html.erb`)
- Collection rendering pour les listes :
  ```erb
  <%= render partial: "student", collection: @students %>
  ```
- Fragment caching quand pertinent :
  ```erb
  <% cache student do %>
    <%= render student %>
  <% end %>
  ```

**Formulaires**
- Toujours `form_with` (jamais `form_for` ou `form_tag`)
- Labels explicites pour l'accessibilité

**Helpers**
- Pour la logique de présentation réutilisable
- Pas de logique métier dans les helpers

**Turbo Frames**
- Pour les chargements partiels et la navigation inline
- `turbo_frame_tag` avec un ID stable (`dom_id`)
- Lazy loading avec `loading: :lazy`
```erb
<%= turbo_frame_tag dom_id(subject), src: subject_path(subject), loading: :lazy do %>
  <p>Chargement...</p>
<% end %>
```

**Turbo Streams**
- Réponses controller pour create/update/destroy :
```erb
<%= turbo_stream.prepend "questions" do %>
  <%= render @question %>
<% end %>
```
- Broadcasts depuis les modèles pour le temps réel :
```ruby
after_create_commit { broadcast_prepend_to "questions" }
```

**ActionCable + Turbo Streams**
- Pour le streaming temps réel (ex: tutorat IA, notifications extraction)
- Souscrire dans la vue :
```erb
<%= turbo_stream_from "student_session_#{@session.id}" %>
```
- Broadcaster depuis le job/service :
```ruby
Turbo::StreamsChannel.broadcast_append_to(
  "student_session_#{session.id}",
  target: "messages",
  partial: "conversations/message",
  locals: { message: chunk }
)
```

**Anti-patterns** :

Bad:
```erb
<!-- Logique métier dans la vue -->
<% if @student.student_sessions.where(mode: :tutored).count > 3 %>
  <p>Limite atteinte</p>
<% end %>
```

Good:
```erb
<% if @student.tutor_limit_reached? %>
  <p>Limite atteinte</p>
<% end %>
```

#### references/jobs.md (~50 lignes)

**Sidekiq** (pas ActiveJob — convention du projet)
```ruby
class ExtractQuestionsJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  def perform(subject_id)
    subject = Subject.find(subject_id)
    ExtractQuestionsFromPdf.call(subject:, pdf_content: extract_pdf(subject))
  end
end
```

**Idempotence obligatoire**
- Le job peut être exécuté plusieurs fois sans effet de bord
- Vérifier l'état avant d'agir :
```ruby
def perform(subject_id)
  subject = Subject.find(subject_id)
  return if subject.extraction_job&.done?
  # ...
end
```

**Retry et erreurs**
- `retry: 3` par défaut, avec backoff exponentiel (natif Sidekiq)
- Les erreurs fatales (mauvaise donnée) → ne pas retry : `raise` sans `retry`
- Les erreurs transitoires (API timeout) → laisser Sidekiq retry

**Arguments**
- Toujours passer des IDs, jamais des objets Ruby (sérialisation Redis)
- Garder les arguments simples (scalaires)

**Queue naming**
- `default` pour la majorité
- `critical` pour les jobs sensibles au temps
- `low` pour les jobs de maintenance

**Logging**
- Logger le début et la fin du job
- Inclure les IDs pertinents pour le debugging

#### references/tests.md (~80 lignes)

**Stack** : RSpec + FactoryBot + Capybara

**Model specs**
```ruby
RSpec.describe Student, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).scoped_to(:classroom_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:classroom) }
    it { is_expected.to have_many(:student_sessions).dependent(:destroy) }
  end

  describe "#full_name" do
    let(:student) { build(:student, first_name: "Jean", last_name: "Dupont") }
    it { expect(student.full_name).to eq("Jean Dupont") }
  end
end
```

**Request specs** (controllers)
```ruby
RSpec.describe "Students", type: :request do
  let(:classroom) { create(:classroom) }
  let(:teacher) { classroom.owner }

  before { sign_in teacher }

  describe "POST /classrooms/:id/students" do
    it "creates a student with generated credentials" do
      expect {
        post classroom_students_path(classroom),
          params: { student: { first_name: "Marie", last_name: "Curie" } }
      }.to change(Student, :count).by(1)
    end
  end
end
```

**Feature specs** (Capybara)
```ruby
RSpec.describe "Student login", type: :feature do
  let(:classroom) { create(:classroom, access_code: "term-sin-2026") }
  let(:student) { create(:student, classroom:) }

  it "allows student to log in via access code" do
    visit "/term-sin-2026"
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password"
    click_button "Se connecter"
    expect(page).to have_content("Bienvenue")
  end
end
```

**Factories**
- Traits pour les variantes, pas de factories dupliquées
- Données minimales — seulement ce qui est requis par les validations
- `build` plutôt que `create` quand la persistence n'est pas nécessaire

```ruby
FactoryBot.define do
  factory :student do
    first_name { "Jean" }
    last_name { "Dupont" }
    password { "password" }
    classroom

    trait :with_api_key do
      api_key { "sk-test-123" }
      api_provider { :anthropic }
    end
  end
end
```

**Edge cases** — toujours tester :
- Valeurs nil / vides
- Conditions aux limites (points = 0, barème max)
- Inputs invalides
- Échecs d'autorisation (élève accédant à une autre classe)
- Erreurs API externes (timeout, 500, réponse malformée)

**VCR/WebMock** pour les appels API externes
```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<API_KEY>") { ENV["ANTHROPIC_API_KEY"] }
end

# Dans le test
it "extracts questions from PDF" do
  VCR.use_cassette("anthropic_extraction") do
    result = ExtractQuestionsFromPdf.call(subject: subject, pdf_content: pdf)
    expect(result).to be_a(Subject)
  end
end
```

**Pattern Arrange-Act-Assert**
- Arrange : `let`, `before`, factories
- Act : une seule action par test
- Assert : expectations claires et ciblées

### 2. Configuration MCP

**Fichier** : `.mcp.json` à la racine du projet

```json
{
  "mcpServers": {
    "rails": {
      "command": "rails-mcp-server",
      "args": ["--single-project"],
      "env": {
        "RAILS_MCP_PROJECT_PATH": "."
      }
    }
  }
}
```

**Pré-requis** : `gem install rails-mcp-server` (installation globale, pas dans le Gemfile).

**Outils exposés** :
- `execute_tool("analyze_models")` — associations, validations, attributs
- `execute_tool("get_routes")` — routes filtrables par controller/verb
- `execute_tool("project_info")` — version Rails, structure, gems
- `execute_ruby("Student.column_names")` — inspection live sandboxée

## Ce qui ne change PAS

- Le code existant des 18 services — aucun refactoring
- Le CLAUDE.md — pas de section conventions ajoutée (c'est dans le skill)
- Les Stimulus controllers existants — better-stimulus s'en occupe
- Le workflow speckit/superpowers — inchangé

## Ordre d'implémentation

1. Installer `rails-mcp-server` globalement (`gem install`)
2. Créer `.mcp.json` à la racine du projet
3. Vérifier que le MCP server répond (`analyze_models`, `get_routes`)
4. Créer `~/.claude/skills/rails-conventions/SKILL.md`
5. Créer les 6 fichiers `references/*.md`
6. Tester : invoquer `/rails-conventions` et vérifier l'activation
7. Optionnel : installer `better-stimulus` via plugin marketplace

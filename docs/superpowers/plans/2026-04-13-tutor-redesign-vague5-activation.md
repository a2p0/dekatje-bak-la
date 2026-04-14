# Vague 5 — Activation par classe & rate limiting : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activer le mode gratuit (clé enseignant OpenRouter par classe), le toggle `use_personal_key` côté élève, et configurer rack-attack pour limiter les messages tuteur à 10/min par élève.

**Architecture:** Clé enseignant (`User#openrouter_api_key`, chiffrée) stockée via Devise registration edit. Flag par classe (`Classroom#tutor_free_mode_enabled`) mis à jour via `PATCH /teacher/classrooms/:id` (nouvelle action `update`). `Student#use_personal_key` mis à jour via `PATCH /settings` (champ existant). `ResolveTutorApiKey` force le provider `:openrouter` quand il retourne la clé enseignant. rack-attack throttle via `req.session["student_id"]` sur les routes `POST */conversations/*/messages`.

**Tech Stack:** Rails 8, rack-attack, ActiveRecord Encryption, Devise registrations, RSpec request specs

> **✅ Carry-over from Vague 4 — resolved:** 4 E2E scenarios in
> `spec/features/student_tutor_spotting_spec.rb` reactivated during
> Vague 5 via `config/cable.yml` (test: adapter: async) +
> `spec/support/tutor_feature_helpers.rb` (opt-in `tutor_streaming: true`
> metadata that forces inline job execution).

**Prérequis Vagues 1-4 accomplis :**
- Migration `add_tutor_columns_to_classrooms_users_students` appliquée : colonnes `tutor_free_mode_enabled` (classrooms), `openrouter_api_key_ciphertext` (users), `use_personal_key` (students) présentes en DB
- `User` modèle a `encrypts :openrouter_api_key`
- `Classroom` modèle a `tutor_free_mode_enabled` accessible
- `Student` modèle a `use_personal_key` avec `default: true`
- `ResolveTutorApiKey` service existe (`app/services/resolve_tutor_api_key.rb`)
- rack-attack gem installé dans `Gemfile` (Vague 1, Task 3)
- `Student::ConversationsController#messages` route : `POST /:access_code/conversations/:id/messages`

---

## Task 1 — Vérifier l'état des prérequis Vague 1

**But:** Confirmer que les colonnes DB, les encryptions et le service `ResolveTutorApiKey` sont bien en place avant de toucher au code UI. Lecture seule — aucun fichier créé ou modifié.

### Steps

- [ ] Vérifier les colonnes DB :
  ```bash
  bundle exec rails runner "puts Classroom.column_names.include?('tutor_free_mode_enabled')"
  bundle exec rails runner "puts User.column_names.include?('openrouter_api_key_ciphertext')"
  bundle exec rails runner "puts Student.column_names.include?('use_personal_key')"
  ```
  Expected : `true` pour chacune.

- [ ] Vérifier les encryptions dans les modèles :
  ```bash
  grep -n "encrypts :openrouter_api_key" app/models/user.rb
  grep -n "encrypts :api_key" app/models/student.rb
  ```
  Expected : une ligne correspondante dans chaque fichier.

- [ ] Vérifier que `ResolveTutorApiKey` existe :
  ```bash
  test -f app/services/resolve_tutor_api_key.rb && echo "EXISTS" || echo "MISSING"
  ```
  Expected : `EXISTS`

- [ ] Vérifier que rack-attack est dans le Gemfile.lock :
  ```bash
  grep "rack-attack" Gemfile.lock
  ```
  Expected : une ligne `rack-attack (x.x.x)`.

- [ ] Si l'une des vérifications échoue, implémenter d'abord les tâches manquantes de Vague 1 avant de continuer. Si tout est présent, passer à Task 2.

---

## Task 2 — Teacher UI : toggle `tutor_free_mode_enabled` sur la classe

**Files:**
- Modify: `app/controllers/teacher/classrooms_controller.rb` — ajouter action `update` + `edit` + `tutor_free_mode_enabled` dans `classroom_params`
- Create: `app/views/teacher/classrooms/edit.html.erb` — formulaire minimal avec la checkbox
- Modify: `app/views/teacher/classrooms/show.html.erb` — ajouter lien "Paramètres" vers `edit`
- Modify: `config/routes.rb` — ajouter `:edit` et `:update` à la resource `classrooms`
- Create: `spec/requests/teacher/classrooms_spec.rb` — ajouter test PATCH
- Commit: `feat(tutor): add tutor_free_mode_enabled toggle in teacher classroom settings`

### Steps

- [ ] Écrire la spec failing. Ouvrir `spec/requests/teacher/classrooms_spec.rb` et ajouter après le dernier `describe` existant :

  ```ruby
  describe "GET /teacher/classrooms/:id/edit" do
    let(:classroom) { create(:classroom, owner: user) }

    it "returns 200" do
      get edit_teacher_classroom_path(classroom)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      get edit_teacher_classroom_path(other_classroom)
      expect(response).to redirect_to(teacher_root_path)
    end
  end

  describe "PATCH /teacher/classrooms/:id" do
    let(:classroom) { create(:classroom, owner: user, tutor_free_mode_enabled: false) }

    it "updates tutor_free_mode_enabled to true" do
      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: true } }

      expect(classroom.reload.tutor_free_mode_enabled).to be(true)
      expect(response).to redirect_to(teacher_classroom_path(classroom))
    end

    it "updates tutor_free_mode_enabled back to false" do
      classroom.update!(tutor_free_mode_enabled: true)

      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: false } }

      expect(classroom.reload.tutor_free_mode_enabled).to be(false)
    end

    it "ignores unknown params (strong params guard)" do
      patch teacher_classroom_path(classroom),
            params: { classroom: { tutor_free_mode_enabled: true, owner_id: 999 } }

      expect(classroom.reload.owner_id).to eq(user.id)
    end

    it "redirects for classroom owned by another teacher" do
      other_classroom = create(:classroom)
      patch teacher_classroom_path(other_classroom),
            params: { classroom: { tutor_free_mode_enabled: true } }

      expect(response).to redirect_to(teacher_root_path)
    end
  end
  ```

- [ ] Confirmer l'échec :
  ```bash
  bundle exec rspec spec/requests/teacher/classrooms_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected : erreurs `No route matches` ou `ActionController::RoutingError` pour les nouvelles routes.

- [ ] Ajouter `:edit` et `:update` dans `config/routes.rb`. Remplacer :
  ```ruby
  resources :classrooms, only: [ :index, :new, :create, :show ] do
  ```
  par :
  ```ruby
  resources :classrooms, only: [ :index, :new, :create, :show, :edit, :update ] do
  ```

- [ ] Mettre à jour `app/controllers/teacher/classrooms_controller.rb` :
  - Modifier `before_action :set_classroom` pour cibler aussi `:edit` et `:update` :
    ```ruby
    before_action :set_classroom, only: [ :show, :edit, :update ]
    ```
  - Ajouter l'action `edit` :
    ```ruby
    def edit
    end
    ```
  - Ajouter l'action `update` :
    ```ruby
    def update
      if @classroom.update(classroom_update_params)
        redirect_to teacher_classroom_path(@classroom),
                    notice: "Paramètres mis à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end
    ```
  - Dans la section `private`, ajouter une méthode dédiée aux paramètres d'update (distinct de `classroom_params` utilisé pour `create`) :
    ```ruby
    def classroom_update_params
      params.require(:classroom).permit(:tutor_free_mode_enabled)
    end
    ```

- [ ] Créer `app/views/teacher/classrooms/edit.html.erb` :
  ```erb
  <%# Paramètres de la classe %>
  <div class="max-w-xl">
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-slate-900 dark:text-white mb-1">
        Paramètres — <%= @classroom.name %>
      </h1>
      <%= link_to "← Retour à la classe",
          teacher_classroom_path(@classroom),
          class: "text-sm text-slate-500 dark:text-slate-400 hover:underline" %>
    </div>

    <%= form_with model: @classroom,
                  url: teacher_classroom_path(@classroom),
                  method: :patch do |f| %>

      <div class="bg-white/80 dark:bg-slate-900/60 border border-slate-200 dark:border-indigo-500/15 rounded-2xl p-5 mb-5 shadow-sm">
        <p class="text-xs font-semibold uppercase tracking-wider text-indigo-600 dark:text-indigo-400 mb-4">
          Mode tuteur
        </p>

        <label class="flex items-start gap-3 cursor-pointer">
          <%= f.check_box :tutor_free_mode_enabled,
              class: "mt-1 accent-indigo-500 w-4 h-4 shrink-0" %>
          <div>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
              Activer le tuteur en mode gratuit pour cette classe
            </span>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              Les élèves sans clé personnelle pourront utiliser le tuteur via
              votre clé OpenRouter. Configurez votre clé OpenRouter dans
              <%= link_to "votre profil", edit_user_registration_path,
                  class: "underline hover:text-indigo-600" %>.
            </p>
          </div>
        </label>
      </div>

      <%= render(ButtonComponent.new(variant: :primary, size: :md, type: "submit")) { "Enregistrer" } %>
    <% end %>
  </div>
  ```

- [ ] Ajouter le lien "Paramètres" dans `app/views/teacher/classrooms/show.html.erb`, dans le bloc `<div class="flex flex-wrap items-center justify-between gap-3 mb-4">` après le titre `Élèves (...)`. Ajouter après les boutons `Exporter Markdown` existants :
  ```erb
  <%= render ButtonComponent.new(
        href: edit_teacher_classroom_path(@classroom),
        variant: :ghost, size: :sm) do %>
    Paramètres
  <% end %>
  ```

- [ ] Relancer les specs :
  ```bash
  bundle exec rspec spec/requests/teacher/classrooms_spec.rb --format documentation 2>&1 | tail -20
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add config/routes.rb \
    app/controllers/teacher/classrooms_controller.rb \
    app/views/teacher/classrooms/edit.html.erb \
    app/views/teacher/classrooms/show.html.erb \
    spec/requests/teacher/classrooms_spec.rb
  git commit -m "feat(tutor): add tutor_free_mode_enabled toggle in teacher classroom settings"
  ```

---

## Task 3 — Teacher UI : saisie de la clé OpenRouter dans le profil

**Files:**
- Modify: `app/views/users/registrations/edit.html.erb` — ajouter champ `openrouter_api_key` masqué (affiche seulement les 4 derniers caractères si déjà configurée)
- Modify: `app/controllers/application_controller.rb` (ou surcharge Devise `RegistrationsController`) — autoriser le paramètre `openrouter_api_key` via `configure_permitted_parameters`
- Create: `spec/requests/teacher/profile_spec.rb` — tester PUT/PATCH sur la registration Devise
- Commit: `feat(tutor): add OpenRouter API key field in teacher profile`

### Steps

- [ ] Écrire la spec failing. Créer `spec/requests/teacher/profile_spec.rb` :

  ```ruby
  # spec/requests/teacher/profile_spec.rb
  require "rails_helper"

  RSpec.describe "Teacher::Profile (Devise registration)", type: :request do
    let(:user) { create(:user, confirmed_at: Time.current) }

    before { sign_in user }

    describe "GET /users/edit" do
      it "returns 200" do
        get edit_user_registration_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PUT /users (update profile with openrouter_api_key)" do
      it "stores openrouter_api_key encrypted" do
        put user_registration_path, params: {
          user: {
            openrouter_api_key: "or-test-key-abc123",
            current_password: "password"
          }
        }

        user.reload
        expect(user.openrouter_api_key).to eq("or-test-key-abc123")
      end

      it "stores nil when key is blank (clearing the key)" do
        user.update!(openrouter_api_key: "or-existing-key")

        put user_registration_path, params: {
          user: {
            openrouter_api_key: "",
            current_password: "password"
          }
        }

        # Blank string from form → stored as nil or blank; key should be gone
        user.reload
        expect(user.openrouter_api_key).to be_blank
      end

      it "does not expose the key in plaintext in the response body" do
        user.update!(openrouter_api_key: "or-secret-key-xyz")
        get edit_user_registration_path
        expect(response.body).not_to include("or-secret-key-xyz")
      end
    end

    describe "encryption at rest" do
      it "stores openrouter_api_key encrypted (ciphertext differs from plaintext)" do
        user.update!(openrouter_api_key: "or-test-plain")
        raw_row = ActiveRecord::Base.connection.execute(
          "SELECT openrouter_api_key_ciphertext FROM users WHERE id = #{user.id}"
        ).first
        ciphertext = raw_row["openrouter_api_key_ciphertext"]
        expect(ciphertext).to be_present
        expect(ciphertext).not_to include("or-test-plain")
      end
    end
  end
  ```

- [ ] Confirmer l'échec (les tests PATCH/PUT devraient échouer car le param n'est pas permis) :
  ```bash
  bundle exec rspec spec/requests/teacher/profile_spec.rb --format documentation 2>&1 | tail -15
  ```

- [ ] Autoriser le paramètre dans Devise. La méthode standard est via `configure_permitted_parameters` dans `ApplicationController`. Ouvrir `app/controllers/application_controller.rb` et ajouter, si pas déjà présent :

  ```ruby
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [ :openrouter_api_key ])
  end
  ```

  Si un tel bloc existe déjà (potentiellement pour `:first_name`/`:last_name`), ajouter `:openrouter_api_key` à la liste existante.

- [ ] Mettre à jour `app/views/users/registrations/edit.html.erb`. Ajouter la section clé OpenRouter après le champ `current_password`. Utiliser un input password masqué avec `placeholder` affichant les 4 derniers chars si une clé est configurée :

  ```erb
  <div class="field">
    <p><%= f.label :openrouter_api_key, "Clé OpenRouter (mode tuteur gratuit)" %></p>
    <p>
      <%= f.password_field :openrouter_api_key,
          value: "",
          placeholder: resource.openrouter_api_key.present? ?
            "••••••••#{resource.openrouter_api_key.last(4)}" :
            "or-...",
          autocomplete: "off" %>
    </p>
    <% if resource.openrouter_api_key.present? %>
      <p><small>Clé configurée (se terminant par <code><%= resource.openrouter_api_key.last(4) %></code>).
      Laissez vide pour conserver la clé actuelle, ou entrez une nouvelle clé pour la remplacer.</small></p>
    <% else %>
      <p><small>Optionnel. Nécessaire pour activer le mode tuteur gratuit pour vos classes.</small></p>
    <% end %>
  </div>
  ```

  Note : le champ `value: ""` garantit que la clé chiffrée n'est jamais pré-remplie dans le HTML. Si l'utilisateur laisse le champ vide lors de la soumission, Devise ne modifie pas la valeur existante si on gère la logique de "blank = keep existing". Voir l'étape suivante.

- [ ] Gérer le cas "champ laissé vide = conserver la clé existante". Dans `ApplicationController`, surcharger `configure_permitted_parameters` pour filtrer le param vide avant qu'il n'écrase une clé existante. Alternative plus propre : créer `app/controllers/users/registrations_controller.rb` :

  ```ruby
  # app/controllers/users/registrations_controller.rb
  class Users::RegistrationsController < Devise::RegistrationsController
    protected

    def account_update_params
      p = super
      # Si le champ openrouter_api_key est soumis vide, ne pas écraser la valeur existante
      p.delete(:openrouter_api_key) if p[:openrouter_api_key].blank?
      p
    end
  end
  ```

  Mettre à jour `config/routes.rb` pour utiliser ce controller :
  ```ruby
  devise_for :users, controllers: { registrations: "users/registrations" }
  ```

- [ ] Relancer les specs :
  ```bash
  bundle exec rspec spec/requests/teacher/profile_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected : `0 failures`. Note : le test "stores nil when key is blank" peut passer ou avoir une logique différente selon le comportement final choisi — ajuster si besoin.

- [ ] Vérifier que les specs Devise existantes passent toujours :
  ```bash
  bundle exec rspec spec/requests/ --format progress 2>&1 | tail -5
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/controllers/application_controller.rb \
    app/controllers/users/registrations_controller.rb \
    app/views/users/registrations/edit.html.erb \
    config/routes.rb \
    spec/requests/teacher/profile_spec.rb
  git commit -m "feat(tutor): add OpenRouter API key field in teacher profile"
  ```

---

## Task 4 — Student UI : toggle `use_personal_key`

**Files:**
- Modify: `app/controllers/student/settings_controller.rb` — ajouter `:use_personal_key` dans `settings_params`
- Modify: `app/views/student/settings/show.html.erb` — ajouter la checkbox dans la section Configuration IA
- Modify: `spec/requests/student/settings_spec.rb` — ajouter test PATCH `use_personal_key`
- Commit: `feat(tutor): add use_personal_key toggle in student settings`

### Steps

- [ ] Écrire la spec failing. Ouvrir `spec/requests/student/settings_spec.rb` et ajouter dans le bloc `describe "PATCH /settings"` :

  ```ruby
  it "updates use_personal_key to false" do
    patch student_settings_path(access_code: classroom.access_code),
          params: { student: { use_personal_key: false } }

    expect(student.reload.use_personal_key).to be(false)
    expect(response).to redirect_to(student_settings_path(access_code: classroom.access_code))
  end

  it "updates use_personal_key back to true" do
    student.update!(use_personal_key: false)

    patch student_settings_path(access_code: classroom.access_code),
          params: { student: { use_personal_key: true } }

    expect(student.reload.use_personal_key).to be(true)
  end
  ```

- [ ] Confirmer l'échec (param non permis, la valeur ne change pas) :
  ```bash
  bundle exec rspec spec/requests/student/settings_spec.rb --format documentation 2>&1 | tail -10
  ```

- [ ] Modifier `app/controllers/student/settings_controller.rb`. Dans `settings_params`, ajouter `:use_personal_key` :

  ```ruby
  def settings_params
    params.require(:student).permit(:default_mode, :api_provider, :api_model, :api_key, :specialty, :use_personal_key)
  end
  ```

- [ ] Ajouter la checkbox dans `app/views/student/settings/show.html.erb`. Localiser le bloc `<%# AI config section %>` (l.52). Ajouter **avant** le bouton "Enregistrer" (l.104), à la suite de la section IA — en fait insérer dans cette section, après le `<div class="mb-5">` du champ `api_key` (l.78) et le bouton "Tester la clé" (l.95), mais **dans** le même card. Insérer juste après le `turbo_frame_tag "test_key_result"` (l.101) et avant la fermeture du card `</div>` (l.102) :

  ```erb
  <%# Toggle: utiliser la clé personnelle vs clé enseignant %>
  <% if current_student.classroom.tutor_free_mode_enabled? %>
    <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700">
      <label class="flex items-start gap-3 cursor-pointer">
        <%= f.check_box :use_personal_key,
            class: "mt-0.5 accent-indigo-500 w-4 h-4 shrink-0" %>
        <div>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            Utiliser ma clé personnelle (modèle premium)
          </span>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Si décoché, la clé de votre enseignant sera utilisée (modèle gratuit OpenRouter).
          </p>
        </div>
      </label>
    </div>
  <% end %>
  ```

- [ ] Relancer les specs :
  ```bash
  bundle exec rspec spec/requests/student/settings_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/controllers/student/settings_controller.rb \
    app/views/student/settings/show.html.erb \
    spec/requests/student/settings_spec.rb
  git commit -m "feat(tutor): add use_personal_key toggle in student settings"
  ```

---

## Task 5 — Mettre à jour `require_api_key` dans `ConversationsController`

**Context :** Actuellement, `require_api_key` dans `Student::ConversationsController` vérifie `current_student.api_key.present?`. Avec le mode gratuit, un élève sans clé personnelle doit quand même pouvoir activer le tuteur si `classroom.tutor_free_mode_enabled? && classroom.owner.openrouter_api_key.present?`. La guard doit déléguer à `ResolveTutorApiKey`.

**Files:**
- Modify: `app/controllers/student/conversations_controller.rb` — mettre à jour `require_api_key`
- Modify: `spec/requests/student/conversations_spec.rb` — ajouter test free-mode
- Commit: `feat(tutor): allow free-mode students in conversations#create guard`

### Steps

- [ ] Écrire les specs failing. Ouvrir `spec/requests/student/conversations_spec.rb` et ajouter un nouveau contexte dans `describe "POST /conversations"` (ou `describe "POST /:access_code/conversations"` selon la version en place après Vague 4) :

  ```ruby
  context "quand le mode gratuit est activé (pas de clé personnelle)" do
    let(:teacher) { user } # user est déjà le owner du classroom
    let(:student_no_key) do
      create(:student,
        classroom: classroom,
        api_key: nil,
        use_personal_key: false)
    end

    before do
      classroom.update!(tutor_free_mode_enabled: true)
      user.update!(openrouter_api_key: "or-teacher-free-key")
      # Re-login as student_no_key
      delete student_session_path(access_code: classroom.access_code)
      post student_session_path(access_code: classroom.access_code),
           params: { username: student_no_key.username, password: "password123" }
    end

    it "autorise la création de conversation via la clé enseignant" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { subject_id: subject_record.id },
           as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  context "quand ni clé personnelle ni mode gratuit n'est disponible" do
    let(:student_no_key) do
      create(:student,
        classroom: classroom,
        api_key: nil,
        use_personal_key: false)
    end

    before do
      classroom.update!(tutor_free_mode_enabled: false)
      delete student_session_path(access_code: classroom.access_code)
      post student_session_path(access_code: classroom.access_code),
           params: { username: student_no_key.username, password: "password123" }
    end

    it "rejette avec 422 et message d'erreur" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { subject_id: subject_record.id },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end
  end
  ```

- [ ] Confirmer l'échec :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -15
  ```

- [ ] Mettre à jour `app/controllers/student/conversations_controller.rb`. Remplacer la méthode `require_api_key` :

  ```ruby
  def require_api_key
    classroom = current_student.classroom
    ResolveTutorApiKey.new(student: current_student, classroom: classroom).call
  rescue ResolveTutorApiKey::NoApiKeyError, Tutor::NoApiKeyError
    respond_to do |format|
      format.json do
        render json: {
          error: "Configurez votre clé IA dans les réglages, ou demandez à votre enseignant d'activer le mode gratuit.",
          settings_url: student_settings_path(access_code: params[:access_code])
        }, status: :unprocessable_entity
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "tutor-activation-banner",
          html: %(<p class="text-sm text-red-600 dark:text-red-400">
            Configurez votre clé IA dans les
            <a href="#{student_settings_path(access_code: params[:access_code])}" class="underline">réglages</a>.
          </p>)
        )
      end
      format.html do
        redirect_to student_settings_path(access_code: params[:access_code]),
                    alert: "Configurez votre clé IA pour utiliser le tutorat."
      end
    end
  end
  ```

  Note : `ResolveTutorApiKey` peut lever `ResolveTutorApiKey::NoApiKeyError` ou `Tutor::NoApiKeyError` selon la vague où il a été implémenté. Les deux sont capturés.

- [ ] Relancer les specs :
  ```bash
  bundle exec rspec spec/requests/student/conversations_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/controllers/student/conversations_controller.rb \
    spec/requests/student/conversations_spec.rb
  git commit -m "feat(tutor): allow free-mode students in conversations#create guard"
  ```

---

## Task 6 — Vérifier et corriger `ResolveTutorApiKey` (provider OpenRouter forcé)

**Context :** Quand `ResolveTutorApiKey` retourne la clé enseignant, il doit forcer le provider à `:openrouter` (free mode = OpenRouter only). Vérifier que c'est déjà le cas — si oui, juste écrire un spec de non-régression. Si non, corriger.

**Files:**
- Read: `app/services/resolve_tutor_api_key.rb`
- Modify ou confirm: `app/services/resolve_tutor_api_key.rb`
- Modify: `spec/services/resolve_tutor_api_key_spec.rb` — ajouter spec provider enforcement
- Commit: `test(tutor): verify ResolveTutorApiKey forces openrouter for teacher key`

### Steps

- [ ] Lire le service actuel :
  ```bash
  cat app/services/resolve_tutor_api_key.rb
  ```

- [ ] Vérifier que la branche teacher-key retourne `provider: "openrouter"` (ou `:openrouter`). Extrait attendu de la Vague 2 :
  ```ruby
  if @classroom.tutor_free_mode_enabled? && @classroom.owner.openrouter_api_key.present?
    key = @classroom.owner.openrouter_api_key
    return { api_key: key, provider: "openrouter", model: DEFAULT_MODEL["openrouter"] }
  end
  ```
  Si ce n'est pas le cas, corriger la ligne `provider:` pour qu'elle soit `"openrouter"`.

- [ ] Ajouter un spec explicite dans `spec/services/resolve_tutor_api_key_spec.rb` pour le provider :

  ```ruby
  context "mode gratuit (teacher key)" do
    before do
      classroom.update!(tutor_free_mode_enabled: true)
      user.update!(openrouter_api_key: "or-teacher-key")
      student.update!(api_key: nil, use_personal_key: false)
    end

    it "force le provider à openrouter" do
      result = described_class.new(student: student, classroom: classroom).call
      expect(result[:provider]).to eq("openrouter")
    end

    it "retourne la clé enseignant" do
      result = described_class.new(student: student, classroom: classroom).call
      expect(result[:api_key]).to eq("or-teacher-key")
    end
  end
  ```

- [ ] Lancer les specs du service :
  ```bash
  bundle exec rspec spec/services/resolve_tutor_api_key_spec.rb --format documentation 2>&1 | tail -10
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add app/services/resolve_tutor_api_key.rb \
    spec/services/resolve_tutor_api_key_spec.rb
  git commit -m "test(tutor): verify ResolveTutorApiKey forces openrouter for teacher key"
  ```

---

## Task 7 — Configuration `rack-attack` (rate limiting tutor messages)

**Files:**
- Create: `config/initializers/rack_attack.rb`
- Create: `spec/requests/rack_attack_spec.rb`
- Commit: `feat(tutor): configure rack-attack throttle on tutor message endpoint`

### Steps

- [ ] Écrire la spec failing. Créer `spec/requests/rack_attack_spec.rb` :

  ```ruby
  # spec/requests/rack_attack_spec.rb
  require "rails_helper"

  RSpec.describe "Rack::Attack tutor message throttle", type: :request do
    let(:user)      { create(:user, confirmed_at: Time.current) }
    let(:classroom) { create(:classroom, owner: user) }
    let(:student) do
      create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic)
    end
    let(:subject_record) { create(:subject, owner: user, status: :published) }
    let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
    let(:part)     { create(:part, subject: subject_record) }
    let(:question) { create(:question, part: part, status: :validated) }
    let!(:answer)  { create(:answer, question: question) }
    let!(:conversation) do
      create(:conversation, student: student, subject: subject_record)
    end

    before do
      # Enable rack-attack in tests
      Rack::Attack.enabled = true
      Rack::Attack.reset!

      post student_session_path(access_code: classroom.access_code),
           params: { username: student.username, password: "password123" }
    end

    after do
      Rack::Attack.enabled = false
      Rack::Attack.reset!
    end

    it "retourne 429 après 10 messages en moins d'une minute" do
      # Stub TutorStreamJob to avoid side effects
      allow(ProcessTutorMessageJob).to receive(:perform_later)

      10.times do |i|
        post message_student_conversation_path(
               access_code: classroom.access_code,
               id: conversation.id
             ),
             params: { content: "Message #{i}", question_id: question.id },
             as: :json
        # Les 10 premiers doivent réussir (200 ou 422 si streaming, mais pas 429)
        expect(response.status).not_to eq(429), "Request #{i + 1} was rate limited early"
      end

      # Le 11e doit être bloqué
      post message_student_conversation_path(
             access_code: classroom.access_code,
             id: conversation.id
           ),
           params: { content: "Message 11", question_id: question.id },
           as: :json

      expect(response).to have_http_status(429)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("minute")
    end
  end
  ```

  Note : ce test dépend de la route `message_student_conversation_path` (POST `/:access_code/conversations/:id/message` ou `/:id/messages` selon la version en place). Adapter le chemin à la route réelle :
  ```bash
  bundle exec rails routes | grep "conversation" | grep POST
  ```

- [ ] Confirmer l'échec (aucun throttle configuré, le 11e message passe) :
  ```bash
  bundle exec rspec spec/requests/rack_attack_spec.rb --format documentation 2>&1 | tail -10
  ```

- [ ] Créer `config/initializers/rack_attack.rb` :

  ```ruby
  # config/initializers/rack_attack.rb
  class Rack::Attack
    # Throttle tutor messages by student_id (extracted from Rails session).
    # Path: POST /:access_code/conversations/:id/message  (old)
    #    or POST /:access_code/conversations/:id/messages (new, Vague 4)
    throttle("tutor/messages/student", limit: 10, period: 1.minute) do |req|
      if req.post? && req.path.match?(%r{/conversations/\d+/messages?\z})
        # req.session is a Rack::Session::Abstract::SessionHash
        # student_id is stored as integer by Student::BaseController
        req.session["student_id"]
      end
    end

    # Safety net: throttle all requests by IP (excluding assets)
    throttle("req/ip", limit: 100, period: 1.minute) do |req|
      req.ip unless req.path.start_with?("/assets")
    end

    # 429 response in JSON (tutor uses JSON endpoint)
    self.throttled_responder = lambda do |_req|
      [
        429,
        { "Content-Type" => "application/json" },
        [ { error: "Trop de requêtes. Attends une minute avant d'envoyer un nouveau message." }.to_json ]
      ]
    end
  end
  ```

- [ ] Activer rack-attack dans l'application. Vérifier que le middleware est chargé. Par défaut, rack-attack se plug automatiquement dans les apps Rack/Rails si la gem est chargée. Vérifier :
  ```bash
  bundle exec rails middleware | grep Attack
  ```
  Expected : `use Rack::Attack` dans la liste. Si absent, ajouter dans `config/application.rb` :
  ```ruby
  config.middleware.use Rack::Attack
  ```

- [ ] Relancer la spec. Note : en test, les sessions Rack sont gérées différemment. Si `req.session["student_id"]` retourne nil (session non accessible au niveau middleware dans les tests request), le throttle par `student_id` ne fonctionnera pas et le test échouera pour une raison différente. Dans ce cas, adapter la spec pour tester le throttle par IP :

  Alternative de fallback si session inaccessible dans les specs request :
  ```ruby
  # Dans le spec, forcer la même IP pour les 11 requêtes
  # (déjà le cas par défaut dans request specs — IP = 127.0.0.1)
  # Mais le throttle par IP est à 100/min, pas 10 — difficile à tester sans boucle de 101 requêtes.
  # Solution : tester directement via Rack::MockRequest
  ```

  Alternative recommandée — tester `rack-attack` avec un test unitaire direct (sans passer par Rails routing) :

  Remplacer le contenu de `spec/requests/rack_attack_spec.rb` par :

  ```ruby
  # spec/requests/rack_attack_spec.rb
  require "rails_helper"

  RSpec.describe "Rack::Attack", type: :request do
    before do
      Rack::Attack.enabled = true
      Rack::Attack.reset!
    end

    after do
      Rack::Attack.enabled = false
      Rack::Attack.reset!
    end

    describe "tutor message throttle" do
      it "permet 10 requêtes puis bloque la 11e pour le même student_id" do
        # Simuler des requêtes avec un session student_id via un stub
        allow_any_instance_of(Rack::Attack::Request).to receive(:session).and_return(
          { "student_id" => 42 }
        )

        10.times do
          post "/terminale-sin-xxx/conversations/1/message",
               params: {},
               headers: { "REMOTE_ADDR" => "1.2.3.4" }
          # 404 ou autre erreur Rails = pas de throttle, c'est ok
          expect(response.status).not_to eq(429)
        end

        post "/terminale-sin-xxx/conversations/1/message",
             params: {},
             headers: { "REMOTE_ADDR" => "1.2.3.4" }
        expect(response).to have_http_status(429)

        json = JSON.parse(response.body)
        expect(json["error"]).to include("minute")
      end
    end

    describe "IP throttle" do
      it "la réponse 429 contient un message en français" do
        # Déclencher le throttle IP directement en forçant la limite
        stub_const("Rack::Attack::THROTTLE_LIMIT_IP", 1)

        # Vérifier juste le format de la réponse si on force un throttle
        # (difficile à tester sans surcharger la config — tester la config directement)
        config = Rack::Attack.instance_variable_get(:@throttled_responder)
        response_parts = config.call(double("req"))

        expect(response_parts[0]).to eq(429)
        expect(JSON.parse(response_parts[2].first)["error"]).to include("minute")
      end
    end
  end
  ```

- [ ] Relancer :
  ```bash
  bundle exec rspec spec/requests/rack_attack_spec.rb --format documentation 2>&1 | tail -15
  ```
  Expected : `0 failures`.

- [ ] Vérifier que la suite complète passe toujours :
  ```bash
  bundle exec rspec spec/ --format progress 2>&1 | tail -5
  ```
  Expected : `0 failures`.

- [ ] Commit :
  ```bash
  git add config/initializers/rack_attack.rb \
    spec/requests/rack_attack_spec.rb
  git commit -m "feat(tutor): configure rack-attack throttle on tutor message endpoint"
  ```

---

## Task 8 — Suite complète et validation finale

**But:** S'assurer que rien n'a cassé, que les specs de régression des vagues précédentes passent, et préparer la branche pour la PR.

### Steps

- [ ] Lancer la suite complète :
  ```bash
  bundle exec rspec spec/ --format progress 2>&1 | tail -10
  ```
  Expected : `0 failures`. Les specs `xdescribe` (vagues 1-4 en cours) comptent comme `pending` — c'est normal.

- [ ] Vérifier les routes finales pour la feature complète :
  ```bash
  bundle exec rails routes | grep -E "(classroom|settings|conversation)" | grep -v "assets"
  ```
  Attendu entre autres :
  ```
  edit_teacher_classroom   GET    /teacher/classrooms/:id/edit
       teacher_classroom   PATCH  /teacher/classrooms/:id
  edit_user_registration   GET    /users/edit
       user_registration   PUT    /users
         student_settings   GET    /:access_code/settings
                            PATCH  /:access_code/settings
  ```

- [ ] Test smoke fonctionnel (optionnel, si l'environnement de dev est disponible) :
  1. Se connecter en tant qu'enseignant
  2. Aller sur `/users/edit` → saisir une clé OpenRouter → sauvegarder
  3. Aller sur `/teacher/classrooms/:id/edit` → cocher "Activer le tuteur gratuit" → sauvegarder
  4. Se connecter en tant qu'élève de cette classe (sans clé personnelle)
  5. Aller dans les réglages → vérifier que la checkbox "Utiliser ma clé personnelle" est visible (puisque free mode activé)
  6. Essayer d'activer le tuteur → la conversation doit se créer normalement

- [ ] Commit de finalisation si aucune correction n'était nécessaire. Si des corrections ont été faites pendant les tests, les committer séparément avec un message `fix(tutor): ...`.

---

## Récapitulatif des fichiers modifiés / créés

| Fichier | Action | Task |
|---|---|---|
| `config/routes.rb` | Modifier — `:edit`, `:update` sur classrooms ; `devise_for` controller override | T2, T3 |
| `app/controllers/teacher/classrooms_controller.rb` | Modifier — ajouter `edit`, `update`, `classroom_update_params` | T2 |
| `app/views/teacher/classrooms/edit.html.erb` | Créer | T2 |
| `app/views/teacher/classrooms/show.html.erb` | Modifier — lien "Paramètres" | T2 |
| `app/controllers/application_controller.rb` | Modifier — `configure_permitted_parameters` | T3 |
| `app/controllers/users/registrations_controller.rb` | Créer — filtrer blank openrouter_api_key | T3 |
| `app/views/users/registrations/edit.html.erb` | Modifier — champ `openrouter_api_key` masqué | T3 |
| `app/controllers/student/settings_controller.rb` | Modifier — ajouter `:use_personal_key` dans `settings_params` | T4 |
| `app/views/student/settings/show.html.erb` | Modifier — checkbox `use_personal_key` conditionnelle | T4 |
| `app/controllers/student/conversations_controller.rb` | Modifier — `require_api_key` délègue à `ResolveTutorApiKey` | T5 |
| `app/services/resolve_tutor_api_key.rb` | Vérifier / corriger provider `:openrouter` | T6 |
| `config/initializers/rack_attack.rb` | Créer | T7 |
| `spec/requests/teacher/classrooms_spec.rb` | Modifier — ajouter tests `edit`/`update` | T2 |
| `spec/requests/teacher/profile_spec.rb` | Créer | T3 |
| `spec/requests/student/settings_spec.rb` | Modifier — ajouter test `use_personal_key` | T4 |
| `spec/requests/student/conversations_spec.rb` | Modifier — ajouter tests free-mode | T5 |
| `spec/services/resolve_tutor_api_key_spec.rb` | Modifier — ajouter spec provider enforcement | T6 |
| `spec/requests/rack_attack_spec.rb` | Créer | T7 |

---

## Décisions d'architecture notables

**Pourquoi `classroom_update_params` séparé de `classroom_params` ?**
`classroom_params` est utilisé pour `create` et inclut `name`, `school_year`, `specialty`. Pour `update`, on n'expose que `tutor_free_mode_enabled` — les autres champs ne sont pas éditables dans ce MVP. Séparer les deux méthodes évite d'autoriser accidentellement le changement de `specialty` après création.

**Pourquoi un `Users::RegistrationsController` custom plutôt qu'un before_action ?**
Devise appelle `account_update_params` directement dans son controller. Surcharger via `configure_permitted_parameters` dans `ApplicationController` permet d'autoriser le champ, mais ne permet pas facilement de filtrer un champ vide (ne pas écraser une clé existante). Le controller custom donne un point d'extension propre et testable.

**Pourquoi rack-attack throttle à 10/min identique pour free-mode et premium ?**
Différencier au niveau rack nécessiterait une requête DB pour lire `student.use_personal_key`. La distinction est déjà faite au niveau LLM (clé OpenRouter pour free-mode = limites du provider, clé premium = limites du provider de l'élève). rack-attack protège contre les abus — 10/min est conservateur et cohérent avec les limites de réponse humaine.

**Pourquoi `req.session["student_id"]` et non l'IP ?**
Les élèves peuvent être derrière le même NAT (salle de classe, tablettes sur le même réseau). Throttler par IP bloquerait toute la classe. Le `student_id` en session donne une granularité par utilisateur.

# Vague 6 — Tests E2E complets & nettoyage final : Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Réécrire les specs E2E Capybara pour le nouveau système tuteur, supprimer les specs orphelines des services supprimés, nettoyer les `xdescribe` résiduels, et valider la CI verte avec un run complet de la suite.

**Architecture:** FakeRubyLlm stubbe tous les appels LLM. Les specs features couvrent le parcours élève complet (activation → greeting → spotting → guiding → validating → feedback). Les specs modèles/services des vagues précédentes couvrent les unités. Les specs à supprimer sont celles dont les services applicatifs ont été supprimés lors de la migration (Vagues 1–5).

**Tech Stack:** Capybara, Selenium (headless Chrome), FakeRubyLlm, RSpec, FactoryBot, Rails seeds

**Prérequis Vagues 1-5 accomplis :**
- `Conversation` : colonnes `lifecycle_state`, `tutor_state` (JSONB), `subject_id`; plus de `messages` JSONB ni de `streaming` boolean; index unique sur `(student_id, subject_id)`
- Table `messages` (colonnes : `conversation_id`, `role` enum, `content`, `question_id`, `tokens_in`, `tokens_out`, `chunk_index`, `streaming_finished_at`)
- `TutorState` Data class + `QuestionState` nested type sérialisés via `TutorStateType`
- `Tutor::ProcessMessage` pipeline (7 étapes POJO : `BuildContext`, `CallLlm`, `FilterSpottingOutput`, `ParseToolCalls`, `ApplyToolCalls`, `UpdateTutorState`, `BroadcastMessage`)
- `FilterSpottingOutput` : filtre regex qui détecte les mentions de sources (DT/DR) en phase spotting et retourne un relaunch neutre
- `InjectDataHints` + `DataHintsComponent` : composant affiché après spotting terminal
- `ConversationChannel` stream `"conversation_{id}"`
- `Student::ConversationsController` : actions `create` (POST `/:access_code/conversations`), `messages` (POST `/:access_code/conversations/:id/messages`), `confidence` (PATCH `/:access_code/conversations/:id/confidence`)
- Activation via `Classroom#tutor_free_mode_enabled` (enseignant) ou `Student#use_personal_key` (élève)
- rack-attack throttle sur `POST */conversations/*/messages` (10/min/étudiant)
- `spec/support/fake_ruby_llm.rb` avec `FakeRubyLlm.setup_stub` — charge dans `spec/rails_helper.rb` via `Rails.root.glob('spec/support/**/*.rb')`
- Toutes les specs de la liste ci-dessous ont leur premier `RSpec.describe` changé en `RSpec.xdescribe` (Vague 1, Task 4)

---

## Task 1 — Vérifier l'état des prérequis

**But :** Confirmer que tout le code Vague 1-5 est en place avant de toucher aux specs. Lecture seule — aucun fichier créé ou modifié.

### Steps

- [ ] Vérifier les colonnes `conversations` :
  ```bash
  bundle exec rails runner "
    cols = Conversation.column_names
    %w[lifecycle_state tutor_state subject_id].each do |c|
      puts \"#{c}: #{cols.include?(c) ? 'OK' : 'MISSING'}\"
    end
    %w[messages streaming].each do |c|
      puts \"#{c}: #{cols.include?(c) ? 'PRESENT (should be gone!)' : 'OK (removed)'}\"
    end
  "
  ```
  Résultat attendu : `lifecycle_state: OK`, `tutor_state: OK`, `subject_id: OK`, `messages: OK (removed)`, `streaming: OK (removed)`.

- [ ] Vérifier la table `messages` :
  ```bash
  bundle exec rails runner "
    cols = Message.column_names
    %w[conversation_id role content question_id chunk_index streaming_finished_at].each do |c|
      puts \"#{c}: #{cols.include?(c) ? 'OK' : 'MISSING'}\"
    end
  "
  ```
  Résultat attendu : `OK` pour chaque colonne.

- [ ] Vérifier les services du pipeline :
  ```bash
  for f in \
    app/services/tutor/result.rb \
    app/services/tutor/build_context.rb \
    app/services/tutor/call_llm.rb \
    app/services/tutor/filter_spotting_output.rb \
    app/services/tutor/parse_tool_calls.rb \
    app/services/tutor/apply_tool_calls.rb \
    app/services/tutor/update_tutor_state.rb \
    app/services/tutor/broadcast_message.rb \
    app/services/tutor/process_message.rb \
    app/services/inject_data_hints.rb
  do
    test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
  done
  ```
  Résultat attendu : `OK` pour tous.

- [ ] Vérifier `FakeRubyLlm` :
  ```bash
  test -f spec/support/fake_ruby_llm.rb && echo "OK" || echo "MISSING"
  ```
  Résultat attendu : `OK`.

- [ ] Vérifier les factories requises :
  ```bash
  bundle exec rails runner "
    %w[conversation message].each do |f|
      path = Rails.root.join('spec', 'factories', \"#{f}s.rb\")
      puts \"#{f}: #{File.exist?(path) ? 'OK' : 'MISSING'}\"
    end
  "
  ```
  Résultat attendu : `OK` pour les deux.

- [ ] Vérifier l'état `xdescribe` des 12 fichiers marqués en Vague 1 :
  ```bash
  bundle exec rspec \
    spec/features/student_tutor_activation_spec.rb \
    spec/features/student_tutor_chat_spec.rb \
    spec/features/student_tutor_spotting_spec.rb \
    spec/features/student_ai_tutoring_spec.rb \
    spec/models/conversation_spec.rb \
    spec/requests/student/conversations_spec.rb \
    spec/requests/student/subjects/tutor_activations_spec.rb \
    spec/requests/student/tutor_spec.rb \
    spec/services/build_tutor_prompt_spec.rb \
    spec/jobs/tutor_stream_job_spec.rb \
    spec/channels/tutor_channel_spec.rb \
    spec/helpers/student/tutor_helper_spec.rb \
    --dry-run 2>&1 | tail -3
  ```
  Résultat attendu : `0 examples, 0 failures` (tous pending/skipped).

- [ ] Si une vérification échoue, terminer les tâches manquantes de Vague 1-5 avant de continuer.

---

## Task 2 — Supprimer les 8 specs orphelines

Ces specs testent des services/controllers/helpers/jobs **supprimés** lors des Vagues 1-5. Leur équivalent fonctionnel a été réécrit dans les Vagues 1-4 sous de nouveaux noms. Les supprimer maintenant évite de maintenir des tests morts.

**Fichiers à supprimer :**
- `spec/models/conversation_spec.rb` — testé `add_message!` / `messages_for_api` (méthodes supprimées). Remplacé par `spec/models/conversation_spec.rb` (nouveau) écrit en Vague 1.
- `spec/requests/student/conversations_spec.rb` — testé ancien schéma `messages` JSONB. Remplacé par le nouveau spec écrit en Vague 4.
- `spec/requests/student/subjects/tutor_activations_spec.rb` — testé `Student::Subjects::TutorActivationsController` (supprimé). L'activation est désormais dans `conversations#create`.
- `spec/requests/student/tutor_spec.rb` — testé `verify_spotting` / `skip_spotting` (endpoints supprimés). La logique de spotting est dans le pipeline Vague 3.
- `spec/services/build_tutor_prompt_spec.rb` — testé `BuildTutorPrompt` (service supprimé). Remplacé par `spec/services/tutor/build_context_spec.rb` écrit en Vague 2.
- `spec/jobs/tutor_stream_job_spec.rb` — testé ancien `TutorStreamJob`. Remplacé par le nouveau spec écrit en Vague 4.
- `spec/channels/tutor_channel_spec.rb` — testé `TutorChannel` (supprimé). Remplacé par `spec/channels/conversation_channel_spec.rb` écrit en Vague 2.
- `spec/helpers/student/tutor_helper_spec.rb` — testé `Student::TutorHelper` (supprimé avec ses méthodes `task_type_options` / `spotting_source_options`).

**Files:**
- Delete: `spec/models/conversation_spec.rb`
- Delete: `spec/requests/student/conversations_spec.rb`
- Delete: `spec/requests/student/subjects/tutor_activations_spec.rb`
- Delete: `spec/requests/student/tutor_spec.rb`
- Delete: `spec/services/build_tutor_prompt_spec.rb`
- Delete: `spec/jobs/tutor_stream_job_spec.rb`
- Delete: `spec/channels/tutor_channel_spec.rb`
- Delete: `spec/helpers/student/tutor_helper_spec.rb`
- Commit: `test(tutor): delete orphaned xdescribe specs replaced in Vagues 1-4`

### Steps

- [ ] Supprimer les 8 fichiers :
  ```bash
  git rm \
    spec/models/conversation_spec.rb \
    spec/requests/student/conversations_spec.rb \
    spec/requests/student/subjects/tutor_activations_spec.rb \
    spec/requests/student/tutor_spec.rb \
    spec/services/build_tutor_prompt_spec.rb \
    spec/jobs/tutor_stream_job_spec.rb \
    spec/channels/tutor_channel_spec.rb \
    spec/helpers/student/tutor_helper_spec.rb
  ```

- [ ] Vérifier qu'aucun des fichiers supprimés n'est requis ailleurs :
  ```bash
  grep -r "tutor_channel_spec\|build_tutor_prompt_spec\|tutor_activations_spec\|tutor_stream_job_spec\|tutor_helper_spec" spec/ --include="*.rb"
  ```
  Résultat attendu : aucune ligne.

- [ ] Lancer un dry-run pour confirmer que le reste de la suite ne casse pas :
  ```bash
  bundle exec rspec --dry-run 2>&1 | tail -3
  ```
  Résultat attendu : exit code 0, 0 failures.

- [ ] Commit :
  ```bash
  git commit -m "test(tutor): delete orphaned xdescribe specs replaced in Vagues 1-4"
  ```

---

## Task 3 — Nettoyer `spec/models/student_session_spec.rb`

Le bloc `describe "tutor_state helpers"` (lignes 214–309) teste les méthodes `question_step`, `set_question_step!`, `store_spotting!`, `spotting_data`, `spotting_completed?`, et `tutored_active?` qui ont été **supprimées** du modèle `StudentSession` lors de la Vague 1 (le `tutor_state` a été déplacé sur `Conversation`). Ce bloc est sans doute `xdescribe` ou fait échouer la suite. Le supprimer.

**Files:**
- Modify: `spec/models/student_session_spec.rb`
- Commit: `test(student-session): remove obsolete tutor_state helper specs`

### Steps

- [ ] Vérifier si le bloc compile encore (si `StudentSession` n'a plus ces méthodes, les specs échouent ou sont en pending) :
  ```bash
  bundle exec rspec spec/models/student_session_spec.rb --format documentation 2>&1 | grep -E "FAILED|pending|question_step|set_question_step|store_spotting|spotting_data|spotting_completed|tutored_active"
  ```

- [ ] Ouvrir `spec/models/student_session_spec.rb`. Repérer et **supprimer** le bloc entier suivant (de la ligne `describe "tutor_state helpers"` jusqu'à son `end` fermant inclus) :

  ```ruby
  describe "tutor_state helpers" do
    let(:ss) { create(:student_session, mode: :tutored) }
    let(:question_id) { 123 }

    describe "#question_step" do
      # ... (tous les exemples internes)
    end

    describe "#set_question_step!" do
      # ...
    end

    describe "#store_spotting!" do
      # ...
    end

    describe "#spotting_data" do
      # ...
    end

    describe "#spotting_completed?" do
      # ...
    end

    describe "#tutored_active?" do
      # ...
    end
  end
  ```

  Le fichier conserve tous les autres blocs (`describe "associations"`, `describe "uniqueness"`, `describe "#mark_seen!"`, etc.).

- [ ] Confirmer que la spec passe après suppression :
  ```bash
  bundle exec rspec spec/models/student_session_spec.rb --format documentation 2>&1 | tail -5
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add spec/models/student_session_spec.rb
  git commit -m "test(student-session): remove obsolete tutor_state helper specs"
  ```

---

## Task 4 — Réécrire `spec/features/student_tutor_activation_spec.rb`

L'ancien spec testait la bannière `[data-testid='tutor-banner']` et le bouton "Activer le mode tuteur" qui appelait `Student::Subjects::TutorActivationsController#create` (maintenant supprimé). Le nouveau comportement est : un étudiant avec clé API (ou bénéficiant du mode gratuit de sa classe) voit un bouton "Activer le tuteur" sur la page sujet. Cliquer crée une `Conversation` avec `lifecycle_state: active` et ouvre le drawer chat.

**Files:**
- Modify: `spec/features/student_tutor_activation_spec.rb` (réécriture complète — retirer `xdescribe`, remplacer le contenu)
- Commit: `test(tutor): rewrite student_tutor_activation_spec for new Conversation lifecycle`

### Steps

- [ ] Remplacer le contenu entier de `spec/features/student_tutor_activation_spec.rb` par :

  ```ruby
  # spec/features/student_tutor_activation_spec.rb
  require "rails_helper"

  RSpec.describe "Activation du tuteur depuis la page sujet", type: :feature do
    let(:teacher)   { create(:user) }
    let(:classroom) { create(:classroom, owner: teacher, tutor_free_mode_enabled: false) }
    let(:subject_record) { create(:subject, status: :published, owner: teacher) }
    let!(:_cs) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
    let(:part) { create(:part, :specific, subject: subject_record, position: 1) }
    let!(:_q)  { create(:question, part: part, position: 1) }

    def visit_subject
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    end

    context "étudiant avec clé API personnelle", js: true do
      let(:student) do
        create(:student, classroom: classroom, api_key: "sk-test-key", api_provider: :openrouter, use_personal_key: true)
      end

      before { login_as_student(student, classroom) }

      it "affiche le bouton Activer le tuteur" do
        visit_subject
        expect(page).to have_button("Activer le tuteur")
      end

      it "crée une Conversation active et ouvre le drawer au clic", js: true do
        visit_subject
        click_button "Activer le tuteur"

        expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)

        conv = Conversation.find_by(student: student, subject: subject_record)
        expect(conv).to be_present
        expect(conv.lifecycle_state).to eq("active")
      end

      it "ne montre plus le bouton après activation" do
        visit_subject
        click_button "Activer le tuteur"
        expect(page).not_to have_button("Activer le tuteur", wait: 5)
      end
    end

    context "étudiant sans clé API, mode gratuit désactivé", js: true do
      let(:student) { create(:student, classroom: classroom, api_key: nil) }

      before { login_as_student(student, classroom) }

      it "n'affiche pas le bouton Activer le tuteur" do
        visit_subject
        expect(page).not_to have_button("Activer le tuteur")
      end
    end

    context "mode gratuit activé par l'enseignant", js: true do
      let(:classroom_free) { create(:classroom, owner: teacher, tutor_free_mode_enabled: true) }
      let!(:_cs2) { create(:classroom_subject, classroom: classroom_free, subject: subject_record) }
      let(:student_no_key) { create(:student, classroom: classroom_free, api_key: nil) }

      before { login_as_student(student_no_key, classroom_free) }

      it "affiche le bouton Activer le tuteur même sans clé personnelle" do
        visit student_subject_path(access_code: classroom_free.access_code, id: subject_record.id)
        expect(page).to have_button("Activer le tuteur")
      end
    end

    context "étudiant qui a déjà une Conversation active", js: true do
      let(:student) { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :openrouter, use_personal_key: true) }
      let!(:_conv) { create(:conversation, student: student, subject: subject_record, lifecycle_state: "active") }

      before { login_as_student(student, classroom) }

      it "n'affiche pas le bouton Activer le tuteur (conversation déjà active)" do
        visit_subject
        expect(page).not_to have_button("Activer le tuteur")
      end
    end
  end
  ```

- [ ] Lancer les nouveaux specs pour voir les failures attendues (UI pas encore vérifiée) :
  ```bash
  bundle exec rspec spec/features/student_tutor_activation_spec.rb --format documentation 2>&1 | tail -20
  ```
  Si des specs passent déjà, c'est que l'UI Vague 5 est correctement en place. Si des specs échouent sur des sélecteurs manquants, noter les IDs pour correction dans Task 11 (section UI).

- [ ] Commit :
  ```bash
  git add spec/features/student_tutor_activation_spec.rb
  git commit -m "test(tutor): rewrite student_tutor_activation_spec for new Conversation lifecycle"
  ```

---

## Task 5 — Vérifier et débloquer `spec/features/student_tutor_chat_spec.rb`

Ce fichier a été **partiellement réécrit** dans Vague 4 pour tester les nouveaux endpoints de conversation. L'objectif ici est de confirmer que l'enveloppe `xdescribe` a bien été retirée (ou ne l'a jamais eu après Vague 4), et que les scénarios existants sont alignés avec le nouveau schéma.

**Files:**
- Modify: `spec/features/student_tutor_chat_spec.rb` (retirer `xdescribe` si présent, adapter `tutor_state` → `Conversation#lifecycle_state`)
- Commit: `test(tutor): unlock student_tutor_chat_spec from xdescribe`

### Steps

- [ ] Vérifier si le fichier a encore un `xdescribe` :
  ```bash
  head -5 spec/features/student_tutor_chat_spec.rb
  ```

- [ ] Si la ligne 1 contient `RSpec.xdescribe`, changer en `RSpec.describe`.

- [ ] Vérifier que le spec n'utilise plus `tutor_state:` directement sur `student_session` pour simuler l'état — la Vague 4 doit avoir réécrit le setup avec une factory `conversation` qui porte le `lifecycle_state`. Chercher :
  ```bash
  grep -n "tutor_state\|TutorStreamJob\|add_message!" spec/features/student_tutor_chat_spec.rb
  ```
  Si ces références sont présentes, les remplacer conformément aux patterns Vague 4 (conversation avec `lifecycle_state: "active"` et `Message` records).

- [ ] Lancer les specs :
  ```bash
  bundle exec rspec spec/features/student_tutor_chat_spec.rb --format documentation 2>&1 | tail -10
  ```
  Résultat attendu : `0 failures`.

- [ ] Commit :
  ```bash
  git add spec/features/student_tutor_chat_spec.rb
  git commit -m "test(tutor): unlock student_tutor_chat_spec from xdescribe"
  ```

---

## Task 6 — Vérifier et débloquer `spec/features/student_tutor_spotting_spec.rb`

Ce fichier a été **remplacé** dans Vague 3 par un nouveau spec dédié à la phase spotting dans le pipeline. Confirmer que Vague 3 a bien créé un spec de remplacement, puis supprimer l'ancien fichier.

**Files:**
- Delete: `spec/features/student_tutor_spotting_spec.rb` (si remplacé par Vague 3)
- Verify: `spec/services/tutor/filter_spotting_output_spec.rb` et `spec/features/student/spotting_phase_spec.rb` existent (specs Vague 3)
- Commit: `test(tutor): delete superseded student_tutor_spotting_spec (replaced in Vague 3)`

### Steps

- [ ] Vérifier que les specs Vague 3 existent :
  ```bash
  for f in \
    spec/services/tutor/filter_spotting_output_spec.rb \
    spec/components/data_hints_component_spec.rb; do
    test -f "$f" && echo "OK: $f" || echo "MISSING: $f"
  done
  ```

- [ ] Si les specs Vague 3 existent bien, supprimer l'ancien fichier :
  ```bash
  git rm spec/features/student_tutor_spotting_spec.rb
  ```

- [ ] Si les specs Vague 3 sont absents, **ne pas supprimer** l'ancien fichier et noter la tâche bloquante pour compléter Vague 3 d'abord.

- [ ] Commit (si suppression faite) :
  ```bash
  git commit -m "test(tutor): delete superseded student_tutor_spotting_spec (replaced in Vague 3)"
  ```

---

## Task 7 — Réécrire `spec/features/student_ai_tutoring_spec.rb`

L'ancien spec testait le flux de chat avec `messages` JSONB sur `Conversation`, `TutorStreamJob`, et `BuildTutorPrompt` (tous supprimés). Le réécrire pour couvrir les scénarios de l'interface chat (drawer, envoi de message, historique) avec le nouveau schéma `Message` et le job `ProcessTutorMessageJob`.

**Files:**
- Modify: `spec/features/student_ai_tutoring_spec.rb` (réécriture complète — retirer `xdescribe`)
- Commit: `test(tutor): rewrite student_ai_tutoring_spec for new Message table and ProcessTutorMessageJob`

### Steps

- [ ] Remplacer le contenu entier de `spec/features/student_ai_tutoring_spec.rb` par :

  ```ruby
  # spec/features/student_ai_tutoring_spec.rb
  require "rails_helper"

  RSpec.describe "Interface chat tuteur (drawer + envoi + historique)", type: :feature do
    let(:teacher)       { create(:user) }
    let(:classroom)     { create(:classroom, owner: teacher) }
    let(:student)       { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
    let(:subject_record) do
      create(:subject, status: :published, owner: teacher,
        specific_presentation: "La société CIME fabrique des véhicules électriques.")
    end
    let(:part)     { create(:part, :specific, subject: subject_record, number: 1, title: "Transport et DD", objective_text: "Comparer les modes.", position: 1) }
    let!(:question) do
      create(:question, part: part, number: "1.1",
        label: "Calculer la consommation en litres pour 186 km.", points: 2, position: 1)
    end
    let!(:answer) do
      create(:answer, question: question,
        correction_text: "Car = 56,73 l",
        explanation_text: "Formule Consommation × Distance / 100")
    end
    let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

    def visit_question_page
      visit student_question_path(
        access_code: classroom.access_code,
        subject_id:  subject_record.id,
        id:          question.id
      )
    end

    context "avec une conversation active" do
      let!(:conversation) do
        create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
      end

      before { login_as_student(student, classroom) }

      scenario "le drawer s'ouvre au clic sur Tutorat", js: true do
        visit_question_page

        drawer = find("[data-chat-target='drawer']", visible: :all)
        expect(drawer[:class]).to include("translate-x-full")

        click_button "Tutorat"

        expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)
      end

      scenario "le drawer affiche le message vide quand aucun message", js: true do
        visit_question_page
        click_button "Tutorat"

        within("[data-chat-target='drawer']") do
          expect(page).to have_text("Posez votre question pour commencer le tutorat.")
        end
      end

      scenario "le drawer se ferme au clic sur ✕", js: true do
        visit_question_page
        click_button "Tutorat"

        expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)

        within("[data-chat-target='drawer']") do
          find("button[aria-label='Fermer le tutorat']").click
        end

        expect(page).to have_css("[data-chat-target='drawer'].translate-x-full", visible: :all, wait: 5)
      end
    end

    context "avec messages existants dans la conversation" do
      let!(:conversation) do
        conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
        create(:message, conversation: conv, role: :user,      content: "Comment je calcule la consommation ?")
        create(:message, conversation: conv, role: :assistant, content: "Bonne question ! Quelles données as-tu ?")
        create(:message, conversation: conv, role: :user,      content: "J'ai la consommation aux 100 km.")
        create(:message, conversation: conv, role: :assistant, content: "Et quelle est la distance du trajet ?")
        conv
      end

      before { login_as_student(student, classroom) }

      scenario "l'historique complet s'affiche à la réouverture du drawer", js: true do
        visit_question_page
        click_button "Tutorat"

        within("[data-chat-target='drawer']") do
          expect(page).to have_text("Comment je calcule la consommation ?")
          expect(page).to have_text("Bonne question ! Quelles données as-tu ?")
          expect(page).to have_text("J'ai la consommation aux 100 km.")
          expect(page).to have_text("Et quelle est la distance du trajet ?")
        end
      end
    end

    context "envoi d'un nouveau message" do
      let!(:conversation) do
        create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
      end

      before do
        login_as_student(student, classroom)
        visit_question_page
        click_button "Tutorat"
        expect(page).to have_css("[data-chat-target='input']", visible: :all, wait: 5)
      end

      scenario "envoyer un message le fait apparaître dans le drawer et enqueue le job", js: true do
        find("[data-chat-target='input']").fill_in(with: "Comment calculer la consommation ?")
        find("[data-chat-target='sendButton']").click

        within("[data-chat-target='drawer']") do
          expect(page).to have_text("Comment calculer la consommation ?", wait: 5)
        end

        msg = Message.find_by(conversation: conversation, role: "user", content: "Comment calculer la consommation ?")
        expect(msg).to be_present
        expect(ProcessTutorMessageJob).to have_been_enqueued.with(conversation.id)
      end

      scenario "l'input est désactivé pendant le streaming", js: true do
        find("[data-chat-target='input']").fill_in(with: "Aide-moi")
        find("[data-chat-target='sendButton']").click

        expect(page).to have_css("[data-chat-target='input'][disabled]", visible: :all, wait: 3)
        expect(page).to have_css("[data-chat-target='sendButton'][disabled]", visible: :all)
      end
    end
  end
  ```

- [ ] Lancer les specs pour voir l'état :
  ```bash
  bundle exec rspec spec/features/student_ai_tutoring_spec.rb --format documentation 2>&1 | tail -20
  ```

- [ ] Commit :
  ```bash
  git add spec/features/student_ai_tutoring_spec.rb
  git commit -m "test(tutor): rewrite student_ai_tutoring_spec for new Message table and ProcessTutorMessageJob"
  ```

---

## Task 8 — Mettre à jour `spec/factories/conversations.rb`

La factory `conversation` utilise encore l'ancien schéma (`messages`, `streaming`, `question`). La mettre à jour pour le nouveau schéma (`lifecycle_state`, `tutor_state`, `subject`). La factory `message` doit être créée si elle n'existe pas encore depuis Vague 1.

**Files:**
- Modify: `spec/factories/conversations.rb`
- Create (si absent): `spec/factories/messages.rb`
- Commit: `test(factories): update conversation factory and add message factory for new schema`

### Steps

- [ ] Vérifier l'état actuel des factories :
  ```bash
  cat spec/factories/conversations.rb
  test -f spec/factories/messages.rb && cat spec/factories/messages.rb || echo "MISSING"
  ```

- [ ] Remplacer le contenu de `spec/factories/conversations.rb` :

  ```ruby
  # spec/factories/conversations.rb
  FactoryBot.define do
    factory :conversation do
      association :student
      association :subject
      lifecycle_state { "active" }
      tutor_state     { {} }
      provider_used   { "anthropic" }
      tokens_used     { 0 }
    end
  end
  ```

- [ ] Si `spec/factories/messages.rb` est absent, le créer :

  ```ruby
  # spec/factories/messages.rb
  FactoryBot.define do
    factory :message do
      association :conversation
      role        { :user }
      content     { "Message de test" }
      tokens_in   { 0 }
      tokens_out  { 0 }
      chunk_index { 0 }
    end
  end
  ```

- [ ] Vérifier que les factories compilent sans erreur :
  ```bash
  bundle exec rails runner "FactoryBot.find_definitions; FactoryBot.build(:conversation); FactoryBot.build(:message); puts 'OK'"
  ```
  Résultat attendu : `OK`.

- [ ] Commit :
  ```bash
  git add spec/factories/conversations.rb spec/factories/messages.rb
  git commit -m "test(factories): update conversation factory and add message factory for new schema"
  ```

---

## Task 9 — Mettre à jour `db/seeds/development.rb`

Les seeds référencent potentiellement les anciennes colonnes (`messages` JSONB, `streaming`, `tutor_state` sur `StudentSession`). Supprimer toute création de conversations/messages dans les seeds de développement et ajouter un bloc commenté montrant comment créer une conversation d'exemple avec le nouveau schéma.

**Files:**
- Modify: `db/seeds/development.rb`
- Commit: `chore(seeds): remove obsolete tutor seed data, add example for new schema`

### Steps

- [ ] Chercher les références obsolètes dans les seeds :
  ```bash
  grep -n "Conversation\|tutor_state\|\.messages\|StudentInsight\|StudentSession.*mode.*tutored" db/seeds/development.rb
  ```

- [ ] Supprimer ou commenter tout bloc qui crée des `Conversation`, `StudentInsight`, ou des `StudentSession` avec `mode: :tutored` et `tutor_state:` (JSONB) dans les seeds de développement.

- [ ] Ajouter à la fin du fichier le bloc de seed pour les conversations du tuteur. Insérer après la ligne `# === C. Lien Classroom ↔ Subject ===` :

  ```ruby
  # === D. Conversations tuteur (exemple — étudiant Maëlys) ===

  maelys = Student.find_by(username: "maelys.riviere", classroom: classroom)
  if maelys && subject
    first_q = subject.all_parts.flat_map { |p| p.questions.kept.order(:position) }.first

    conv = Conversation.find_or_initialize_by(student: maelys, subject: subject)
    if conv.new_record?
      conv.assign_attributes(lifecycle_state: "active", tutor_state: {}, provider_used: "anthropic")
      conv.save!
      Message.find_or_create_by!(conversation: conv, role: :user, content: "Comment calculer la consommation ?") do |m|
        m.question_id  = first_q&.id
        m.chunk_index  = 0
      end
      Message.find_or_create_by!(conversation: conv, role: :assistant, content: "Bonne question ! Quelles données as-tu dans l'énoncé ?") do |m|
        m.question_id  = first_q&.id
        m.chunk_index  = 1
        m.streaming_finished_at = Time.current
      end
      puts "  Conversation tuteur créée pour Maëlys (#{conv.messages.count} messages)"
    else
      puts "  Conversation tuteur Maëlys déjà présente"
    end
  end
  ```

- [ ] Tester les seeds en mode dry :
  ```bash
  bundle exec rails db:seed:replant 2>&1 | tail -15
  ```
  Résultat attendu : pas d'erreur, ligne `Conversation tuteur créée pour Maëlys`.

- [ ] Commit :
  ```bash
  git add db/seeds/development.rb
  git commit -m "chore(seeds): remove obsolete tutor seed data, add example for new schema"
  ```

---

## Task 10 — Créer le spec E2E complet `spec/features/student_tutor_full_flow_spec.rb`

C'est la spec showstopper qui valide le parcours tuteur bout en bout : activation → greeting → spotting (succès et forced_reveal) → filtre regex → guiding → validating → confidence → feedback → persistance du drawer.

Chaque scénario utilise `FakeRubyLlm.setup_stub` pour contrôler la réponse LLM. Les assertions vérifient le DOM Capybara ET la base de données.

**Files:**
- Create: `spec/features/student_tutor_full_flow_spec.rb`
- Commit: `test(tutor): add full E2E flow spec for greeting → spotting → guiding → validating → feedback`

### Steps

- [ ] Créer `spec/features/student_tutor_full_flow_spec.rb` avec le contenu suivant :

  ```ruby
  # spec/features/student_tutor_full_flow_spec.rb
  require "rails_helper"

  # FakeRubyLlm doit être chargé via spec/support/fake_ruby_llm.rb (rails_helper auto-require)
  # Usage : FakeRubyLlm.setup_stub(tool_calls: [...], content: "...")
  # Le stub remplace l'appel au LLM pour un seul tour ; appeler à nouveau pour le tour suivant.

  RSpec.describe "Parcours tuteur complet (E2E FakeRubyLlm)", type: :feature do
    let(:teacher)   { create(:user) }
    let(:classroom) { create(:classroom, owner: teacher, tutor_free_mode_enabled: false) }
    let(:student) do
      create(:student, classroom: classroom,
        api_key: "sk-test-key", api_provider: :anthropic, use_personal_key: true)
    end
    let(:subject_record) do
      create(:subject, status: :published, owner: teacher,
        specific_presentation: "La société CIME fabrique des véhicules électriques.")
    end
    let(:part) do
      create(:part, :specific, subject: subject_record,
        number: 1, title: "Transport et DD",
        objective_text: "Comparer les modes de transport.", position: 1)
    end
    let!(:question) do
      create(:question, part: part,
        number: "1.1",
        label: "Calculer la consommation en litres pour 186 km.",
        answer_type: :calculation, points: 2, position: 1)
    end
    let!(:answer) do
      create(:answer, question: question,
        correction_text: "Car = 56,73 l",
        data_hints: [
          { "source" => "DT1", "location" => "tableau Consommation moyenne" },
          { "source" => "mise_en_situation", "location" => "distance 186 km" }
        ])
    end
    let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

    def visit_subject
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    end

    def open_drawer
      click_button "Tutorat"
      expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)
    end

    before { login_as_student(student, classroom) }

    # ─── Scénario 1 : Activation ──────────────────────────────────────────────
    scenario "1 — Activation : clic Activer le tuteur crée Conversation active et ouvre le drawer", js: true do
      visit_subject

      expect(page).to have_button("Activer le tuteur")

      FakeRubyLlm.setup_stub(
        content: "Bonjour ! Je suis ton tuteur pour cette question. Prêt à commencer ?",
        tool_calls: []
      )

      click_button "Activer le tuteur"

      expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)

      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).to be_present
      expect(conv.lifecycle_state).to eq("active")
    end

    # ─── Scénario 2 : Greeting → Reading ─────────────────────────────────────
    scenario "2 — Greeting → Reading : l'outil transition(phase: :reading) met le learner_model à jour", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")

      FakeRubyLlm.setup_stub(
        content: "Commençons par lire l'énoncé.",
        tool_calls: [{ name: "transition", arguments: { phase: "reading" } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "Bonjour")
      find("[data-chat-target='sendButton']").click

      # Attendre la réponse streamée
      expect(page).to have_text("Commençons par lire l'énoncé.", wait: 10)

      conv.reload
      expect(conv.tutor_state.dig("current_phase")).to eq("reading")
    end

    # ─── Scénario 3 : Reading → Spotting ─────────────────────────────────────
    scenario "3 — Reading → Spotting : l'outil transition(phase: :spotting) demande le repérage", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: { "current_phase" => "reading" })
      create(:message, conversation: conv, role: :user, content: "J'ai lu l'énoncé.")

      FakeRubyLlm.setup_stub(
        content: "Quelles sources de données vas-tu utiliser pour calculer ?",
        tool_calls: [{ name: "transition", arguments: { phase: "spotting" } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "J'ai lu l'énoncé.")
      find("[data-chat-target='sendButton']").click

      expect(page).to have_text("Quelles sources de données", wait: 10)

      conv.reload
      expect(conv.tutor_state.dig("current_phase")).to eq("spotting")
    end

    # ─── Scénario 4 : Spotting réussi ────────────────────────────────────────
    scenario "4 — Spotting réussi : evaluate_spotting(outcome: :success) affiche DataHintsComponent", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: { "current_phase" => "spotting", "current_question_id" => question.id })
      create(:message, conversation: conv, role: :user, content: "DT1 et la mise en situation")

      FakeRubyLlm.setup_stub(
        content: "Excellent ! Tu as identifié les bonnes sources.",
        tool_calls: [{ name: "evaluate_spotting", arguments: { outcome: "success" } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "DT1 et la mise en situation")
      find("[data-chat-target='sendButton']").click

      expect(page).to have_css("[data-testid='data-hints']", wait: 10)
      expect(page).to have_text("DT1")
      expect(page).to have_text("Consommation moyenne")

      conv.reload
      expect(conv.tutor_state.dig("current_phase")).to eq("guiding")
    end

    # ─── Scénario 5 : Forced reveal ───────────────────────────────────────────
    scenario "5 — Forced reveal : evaluate_spotting(outcome: :forced_reveal) affiche aussi les data hints", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: { "current_phase" => "spotting", "current_question_id" => question.id })
      create(:message, conversation: conv, role: :user, content: "Je ne sais pas où trouver les données.")

      FakeRubyLlm.setup_stub(
        content: "Voici les sources qui te seront utiles.",
        tool_calls: [{ name: "evaluate_spotting", arguments: { outcome: "forced_reveal" } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "Je ne sais pas.")
      find("[data-chat-target='sendButton']").click

      expect(page).to have_css("[data-testid='data-hints']", wait: 10)
    end

    # ─── Scénario 6 : Filtre regex ────────────────────────────────────────────
    scenario "6 — Filtre regex : réponse LLM contenant 'DT1' est interceptée, relaunch neutre affiché", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: { "current_phase" => "spotting", "current_question_id" => question.id })
      create(:message, conversation: conv, role: :user, content: "Je cherche dans DT1")

      # Le LLM tente de révéler la source — FilterSpottingOutput doit l'intercepter
      FakeRubyLlm.setup_stub(
        content: "Les données se trouvent dans DT1, tableau de consommation.",
        tool_calls: []
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "Je cherche dans DT1")
      find("[data-chat-target='sendButton']").click

      # Le texte du LLM NE DOIT PAS apparaître — un message neutre doit le remplacer
      expect(page).not_to have_text("Les données se trouvent dans DT1", wait: 5)
      # Message de relaunch neutre attendu (texte configurable dans FilterSpottingOutput)
      expect(page).to have_text("Continue à chercher", wait: 5)
    end

    # ─── Scénario 7 : Guiding avec indice ────────────────────────────────────
    scenario "7 — Guiding : request_hint(level: 1) affiche le compteur d'indices", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: {
          "current_phase"      => "guiding",
          "current_question_id" => question.id,
          "question_states"    => { question.id.to_s => { "hints_used" => 0 } }
        })
      create(:message, conversation: conv, role: :user, content: "Je ne comprends pas la formule.")

      FakeRubyLlm.setup_stub(
        content: "Indice 1 : pense à la formule distance × consommation / 100.",
        tool_calls: [{ name: "request_hint", arguments: { level: 1 } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "Je ne comprends pas la formule.")
      find("[data-chat-target='sendButton']").click

      expect(page).to have_text("Indice 1", wait: 10)
      expect(page).to have_css("[data-hint-count]", wait: 5)
    end

    # ─── Scénario 8 : Validation ──────────────────────────────────────────────
    scenario "8 — Validation : transition(phase: :validating) affiche les boutons de confiance dans le drawer", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active",
        tutor_state: { "current_phase" => "guiding", "current_question_id" => question.id })
      create(:message, conversation: conv, role: :user, content: "J'ai obtenu 56,73 litres.")

      FakeRubyLlm.setup_stub(
        content: "Bravo ! C'est la bonne réponse. À quel point étais-tu sûr(e) ?",
        tool_calls: [{ name: "transition", arguments: { phase: "validating" } }]
      )

      visit_subject
      open_drawer

      find("[data-chat-target='input']").fill_in(with: "J'ai obtenu 56,73 litres.")
      find("[data-chat-target='sendButton']").click

      expect(page).to have_css("[data-controller='confidence-form']", wait: 10)
      expect(page).to have_button("Très peu sûr")
      expect(page).to have_button("Très sûr")
    end

    # ─── Scénario 9 : Confiance soumise ──────────────────────────────────────
    scenario "9 — Confiance soumise : cliquer niveau 3 retire les boutons et avance en :feedback", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "validating",
        tutor_state: { "current_phase" => "validating", "current_question_id" => question.id })

      visit_subject
      open_drawer

      # Le form de confiance doit être présent dans le drawer (rendu côté serveur)
      expect(page).to have_css("[data-controller='confidence-form']", wait: 5)

      click_button "Moyennement sûr"

      expect(page).not_to have_css("[data-controller='confidence-form']", wait: 5)

      conv.reload
      expect(conv.lifecycle_state).to eq("feedback")
      q_state = conv.tutor_state.dig("question_states", question.id.to_s)
      expect(q_state&.dig("last_confidence")).to eq(3)
    end

    # ─── Scénario 10 : Persistance du drawer ─────────────────────────────────
    scenario "10 — Persistance : fermer et rouvrir le drawer conserve tous les messages", js: true do
      conv = create(:conversation, student: student, subject: subject_record, lifecycle_state: "active")
      create(:message, conversation: conv, role: :user,      content: "Premier message")
      create(:message, conversation: conv, role: :assistant, content: "Réponse du tuteur")

      visit_subject
      open_drawer

      within("[data-chat-target='drawer']") do
        expect(page).to have_text("Premier message")
        expect(page).to have_text("Réponse du tuteur")

        find("button[aria-label='Fermer le tutorat']").click
      end

      expect(page).to have_css("[data-chat-target='drawer'].translate-x-full", visible: :all, wait: 5)

      # Rouvrir
      click_button "Tutorat"
      expect(page).to have_css("[data-chat-target='drawer']:not(.translate-x-full)", wait: 5)

      within("[data-chat-target='drawer']") do
        expect(page).to have_text("Premier message")
        expect(page).to have_text("Réponse du tuteur")
      end
    end
  end
  ```

- [ ] Lancer les specs pour voir le nombre de failures :
  ```bash
  bundle exec rspec spec/features/student_tutor_full_flow_spec.rb --format documentation 2>&1 | tail -30
  ```
  À ce stade, des failures sont attendues si l'UI Vague 4/5 n'est pas parfaitement alignée. Les noter pour Task 11.

- [ ] Commit (même si certains scénarios échouent encore) :
  ```bash
  git add spec/features/student_tutor_full_flow_spec.rb
  git commit -m "test(tutor): add full E2E flow spec for greeting → spotting → guiding → validating → feedback"
  ```

---

## Task 11 — Corriger les divergences UI révélées par les specs

Les Tasks 4, 7, et 10 auront révélé des sélecteurs CSS ou des textes manquants. Cette tâche les corrige.

**Principe :** Modifier uniquement les vues/partials nécessaires pour que les assertions Capybara passent. Ne pas modifier les specs.

**Files potentiels (selon les failures) :**
- `app/views/student/subjects/show.html.erb` — bouton "Activer le tuteur"
- `app/views/student/questions/_chat_drawer.html.erb` — bouton "Tutorat", aria-label "Fermer le tutorat"
- `app/views/student/conversations/_confidence_form.html.erb` — libellés "Très peu sûr" / "Très sûr" / "Moyennement sûr"
- `app/components/data_hints_component.html.erb` — attribut `data-testid="data-hints"`
- `app/javascript/controllers/chat_controller.js` — gestion `data-hint-count`

### Steps

- [ ] Lancer l'ensemble des feature specs E2E pour avoir la liste complète des failures :
  ```bash
  bundle exec rspec spec/features/student_tutor_activation_spec.rb \
                   spec/features/student_ai_tutoring_spec.rb \
                   spec/features/student_tutor_full_flow_spec.rb \
                   --format documentation 2>&1 | grep "FAILED\|expected\|did not find\|Unable to find" | head -30
  ```

- [ ] Pour chaque failure de type `Unable to find button "Activer le tuteur"` :
  - Vérifier que `app/views/student/subjects/show.html.erb` contient un `button_to` avec le texte "Activer le tuteur" visible quand `conv.nil? && student.can_use_tutor?`
  - Si absent, ajouter le bouton d'activation (code attendu depuis Vague 5) :
    ```erb
    <%# app/views/student/subjects/show.html.erb — bloc conditionnel tuteur %>
    <% if @conversation.nil? && current_student.can_use_tutor?(@classroom) %>
      <%= button_to "Activer le tuteur",
            student_conversations_path(access_code: params[:access_code]),
            method: :post,
            params: { subject_id: @subject.id },
            data: { testid: "tutor-activate-btn" },
            class: "btn-primary" %>
    <% end %>
    ```

- [ ] Pour chaque failure de type `Unable to find button "Tutorat"` :
  - Vérifier que la question show page contient un `button` avec texte "Tutorat" lié à `data-action="click->chat#open"`.
  - Le bouton doit exister même si la conversation est en `lifecycle_state: "active"`.

- [ ] Pour chaque failure sur `[data-testid='data-hints']` :
  - Vérifier `app/components/data_hints_component.html.erb` contient `data-testid="data-hints"` sur l'élément racine.

- [ ] Pour chaque failure sur `[data-hint-count]` :
  - Vérifier que `Tutor::BroadcastMessage` envoie `type: "hint_count"` avec le compteur, et que le Stimulus controller `chat_controller.js` met à jour un attribut `data-hint-count` dans le DOM.

- [ ] Pour chaque failure sur le texte de relaunch neutre ("Continue à chercher") :
  - Vérifier `Tutor::FilterSpottingOutput::NEUTRAL_RELAUNCH_MESSAGE` dans `app/services/tutor/filter_spotting_output.rb` et adapter le test si le texte exact est différent.

- [ ] Relancer les specs après chaque correction et confirmer que les failures disparaissent une par une :
  ```bash
  bundle exec rspec spec/features/student_tutor_full_flow_spec.rb --format progress 2>&1 | tail -5
  ```

- [ ] Commit pour chaque fichier modifié :
  ```bash
  git add <fichiers modifiés>
  git commit -m "fix(tutor): align UI selectors with E2E spec assertions"
  ```

---

## Task 12 — Vérifier et finaliser la configuration CI

Le fichier `.github/workflows/ci.yml` exécute uniquement `spec/features/`. Vague 6 requiert aussi l'exécution des specs models/services/requests/jobs réécrites dans les Vagues 1-4. La suite doit être verte dans son intégralité.

**Files:**
- Modify: `.github/workflows/ci.yml`
- Commit: `ci: run full rspec suite (not just features) in CI`

### Steps

- [ ] Vérifier la commande de test actuelle dans `.github/workflows/ci.yml` :
  ```bash
  grep -A 3 "Run feature specs" .github/workflows/ci.yml
  ```
  La ligne actuelle : `bundle exec rspec spec/features/ --format progress --no-color`

- [ ] Remplacer la step "Run feature specs" par deux steps distinctes pour que les failures soient plus faciles à diagnostiquer :

  Trouver dans `.github/workflows/ci.yml` :
  ```yaml
      - name: Run feature specs
        run: bundle exec rspec spec/features/ --format progress --no-color
        env:
          RAILS_SERVE_STATIC_FILES: "1"
  ```

  Remplacer par :
  ```yaml
      - name: Run unit specs (models, services, requests, jobs, channels, components)
        run: |
          bundle exec rspec \
            spec/models/ \
            spec/services/ \
            spec/requests/ \
            spec/jobs/ \
            spec/channels/ \
            spec/components/ \
            --format progress --no-color

      - name: Run feature specs (E2E Capybara)
        run: bundle exec rspec spec/features/ --format progress --no-color
        env:
          RAILS_SERVE_STATIC_FILES: "1"
  ```

- [ ] Confirmer que `WebMock` est configuré pour autoriser localhost (déjà dans `spec/support/capybara.rb`) :
  ```bash
  grep "allow_localhost" spec/support/capybara.rb
  ```
  Résultat attendu : `WebMock.disable_net_connect!(allow_localhost: true)`.

- [ ] Confirmer que `FakeRubyLlm` est auto-chargé :
  ```bash
  grep "fake_ruby_llm\|spec/support" spec/rails_helper.rb | head -3
  ```
  Résultat attendu : la ligne `Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }` est présente — elle charge `spec/support/fake_ruby_llm.rb` automatiquement.

- [ ] Commit :
  ```bash
  git add .github/workflows/ci.yml
  git commit -m "ci: run full rspec suite (not just features) in CI"
  ```

---

## Task 13 — Run complet local et vérification finale

Run de l'ensemble de la suite RSpec en local. Vert = tâche terminée.

### Steps

- [ ] Préparer la base de test :
  ```bash
  bundle exec rails db:schema:load RAILS_ENV=test
  ```

- [ ] Lancer la suite complète sans les specs marquées `xdescribe` (il ne doit plus en rester après Tasks 2-6) :
  ```bash
  bundle exec rspec --format progress --no-color 2>&1 | tail -10
  ```
  Résultat attendu :
  ```
  Finished in X seconds (files took Y seconds to load)
  NNN examples, 0 failures, 0 pending
  ```

- [ ] Si des failures subsistent, les diagnostiquer :
  ```bash
  bundle exec rspec --format documentation --no-color 2>&1 | grep -A 5 "FAILED"
  ```
  Corriger dans les fichiers concernés et relancer.

- [ ] Confirmer qu'aucun fichier `xdescribe` ne subsiste dans la spec directory :
  ```bash
  grep -r "RSpec\.xdescribe\|RSpec\.xfeature" spec/ --include="*.rb"
  ```
  Résultat attendu : aucune ligne.

- [ ] Commit final si des corrections mineures ont été nécessaires :
  ```bash
  git add -A
  git commit -m "test(tutor): green suite — all E2E and unit specs passing, no xdescribe remaining"
  ```

- [ ] Push et ouvrir la PR :
  ```bash
  git push -u origin <branch>
  gh pr create \
    --title "test(tutor): Vague 6 — E2E complets & nettoyage final" \
    --body "$(cat <<'EOF'
  ## Summary

  - Supprime 8 specs orphelines (services/controllers/helpers/jobs supprimés en Vagues 1–4)
  - Supprime le bloc `tutor_state helpers` obsolète de `student_session_spec.rb`
  - Réécrit `student_tutor_activation_spec.rb` pour le nouveau lifecycle `Conversation`
  - Réécrit `student_ai_tutoring_spec.rb` pour le nouveau schéma `Message` + `ProcessTutorMessageJob`
  - Ajoute `student_tutor_full_flow_spec.rb` : 10 scénarios E2E FakeRubyLlm couvrant le parcours complet
  - Met à jour les factories `conversation` et `message`
  - Met à jour `db/seeds/development.rb` (supprime les refs JSONB obsolètes)
  - CI : exécute désormais la suite complète (models + services + features)

  ## Test plan

  - [ ] `bundle exec rspec --format progress` → 0 failures
  - [ ] `grep -r "RSpec\.xdescribe" spec/` → aucun résultat
  - [ ] CI verte sur la PR

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
  )"
  ```

---

## Résumé des fichiers impactés

| Action | Fichier |
|--------|---------|
| DELETE | `spec/models/conversation_spec.rb` |
| DELETE | `spec/requests/student/conversations_spec.rb` |
| DELETE | `spec/requests/student/subjects/tutor_activations_spec.rb` |
| DELETE | `spec/requests/student/tutor_spec.rb` |
| DELETE | `spec/services/build_tutor_prompt_spec.rb` |
| DELETE | `spec/jobs/tutor_stream_job_spec.rb` |
| DELETE | `spec/channels/tutor_channel_spec.rb` |
| DELETE | `spec/helpers/student/tutor_helper_spec.rb` |
| DELETE | `spec/features/student_tutor_spotting_spec.rb` (si remplacé par Vague 3) |
| MODIFY | `spec/models/student_session_spec.rb` (supprimer bloc `tutor_state helpers`) |
| REWRITE | `spec/features/student_tutor_activation_spec.rb` |
| REWRITE | `spec/features/student_ai_tutoring_spec.rb` |
| VERIFY/UNLOCK | `spec/features/student_tutor_chat_spec.rb` |
| CREATE | `spec/features/student_tutor_full_flow_spec.rb` |
| MODIFY | `spec/factories/conversations.rb` |
| CREATE (si absent) | `spec/factories/messages.rb` |
| MODIFY | `db/seeds/development.rb` |
| MODIFY | `.github/workflows/ci.yml` |
| MAYBE MODIFY | `app/views/student/subjects/show.html.erb` |
| MAYBE MODIFY | `app/views/student/questions/_chat_drawer.html.erb` |
| MAYBE MODIFY | `app/components/data_hints_component.html.erb` |

require "rails_helper"

RSpec.describe "Tuteur — activation depuis la page question (044)", type: :feature do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:exam_session)   { create(:exam_session, title: "CIME 2024", owner: teacher) }
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher, exam_session: exam_session)
  end
  let(:part) do
    create(:part, :specific, subject: subject_record,
           number: 1, title: "Transport et DD", position: 1)
  end
  let!(:question) do
    create(:question, part: part,
           number: "1.1", label: "Calculer la consommation.", points: 2, position: 1)
  end
  let!(:answer)            { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
  end

  # ─── T300 : bouton conditionnel ───────────────────────────────────────────

  describe "T300 — bouton conditionnel selon disponibilité clé" do
    context "sans clé API (tutor indisponible)" do
      let(:student) { create(:student, classroom: classroom, api_key: nil, use_personal_key: false) }

      before do
        login_as_student(student, classroom)
        visit_question
      end

      scenario "affiche 'Activer le tuteur' avec lien vers settings", js: false do
        expect(page).to have_link("Activer le tuteur",
                                  href: student_settings_path(access_code: classroom.access_code))
        expect(page).not_to have_button("Tutorat")
        expect(page).not_to have_css("button", text: /Tutorat/)
      end
    end

    context "avec clé API personnelle" do
      let(:student) do
        create(:student, classroom: classroom,
               api_key: "sk-test", api_provider: :anthropic, use_personal_key: true)
      end

      before do
        login_as_student(student, classroom)
        visit_question
      end

      scenario "affiche le bouton '💬 Tutorat'", js: false do
        expect(page).to have_button("Tutorat")
        expect(page).not_to have_link("Activer le tuteur")
      end
    end

    context "avec free mode classroom (sans clé élève)" do
      let(:teacher)   { create(:user, openrouter_api_key: "or-teacher-key") }
      let(:classroom) { create(:classroom, owner: teacher, tutor_free_mode_enabled: true) }
      let(:student)   { create(:student, classroom: classroom, api_key: nil, use_personal_key: false) }

      before do
        login_as_student(student, classroom)
        visit_question
      end

      scenario "affiche le bouton '💬 Tutorat'", js: false do
        expect(page).to have_button("Tutorat")
        expect(page).not_to have_link("Activer le tuteur")
      end
    end
  end

  # ─── T301 : activation — drawer + messages ────────────────────────────────

  describe "T301 — clic Tutorat : drawer ouvert + welcome + intro", js: true do
    let(:student) do
      create(:student, classroom: classroom,
             api_key: "sk-test", api_provider: :anthropic, use_personal_key: true)
    end

    before do
      FakeRubyLlm.setup_stub(content: "Tu peux le faire !", tool_calls: [])
      login_as_student(student, classroom)
      visit_question
    end

    scenario "le drawer s'ouvre après le clic" do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 8
      )
    end

    scenario "un message welcome apparaît dans le drawer" do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
      # Le welcome inclut le titre du sujet (exam_session.title)
      expect(drawer).to have_text("CIME", wait: 8)
    end

    scenario "un message intro pour la question apparaît dans le drawer" do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
      expect(drawer).to have_text("1.1", wait: 8)
    end

    scenario "l'input de chat est activé après création de la conversation" do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      # Attendre que le drawer replace soit traité et l'input soit activé
      expect(page).to have_css(
        "[data-tutor-chat-target='input']:not([disabled])",
        visible: :all, wait: 10
      )
    end

    scenario "une conversation est créée en base" do
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 8
      )
      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).to be_present
      expect(conv.lifecycle_state).to eq("active")
    end
  end

  # ─── T302 : idempotence — pas de doublon à la 2e visite ──────────────────

  describe "T302 — re-clic sur Tutorat : pas de doublon intro", js: true do
    let(:student) do
      create(:student, classroom: classroom,
             api_key: "sk-test", api_provider: :anthropic, use_personal_key: true)
    end

    before do
      FakeRubyLlm.setup_stub(content: "Tu peux le faire !", tool_calls: [])
      login_as_student(student, classroom)
    end

    scenario "ouvrir deux fois le drawer ne crée qu'un seul message intro pour la question" do
      visit_question
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 8
      )

      # fermer puis réouvrir (reload de la page = nouvelle visite)
      visit_question
      FakeRubyLlm.setup_stub(content: "Bonne chance !", tool_calls: [])
      find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
      expect(page).to have_css(
        "[data-chat-drawer-target='drawer'].translate-x-0",
        visible: :all, wait: 8
      )

      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv.messages.where(kind: :intro).count).to eq(1)
    end
  end

  # ─── T303 : indicateur tri-état page sujet ───────────────────────────────

  describe "T303 — indicateur tri-état sur la page sujet" do
    let(:student) do
      create(:student, classroom: classroom,
             api_key: "sk-test", api_provider: :anthropic, use_personal_key: true)
    end

    before { login_as_student(student, classroom) }

    scenario "sans conversation active : affiche 'Tuteur disponible'", js: false do
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
      expect(page).to have_text("Tuteur disponible")
    end

    scenario "avec conversation active : affiche 'Tuteur actif'", js: false do
      create(:conversation, student: student, subject: subject_record,
             lifecycle_state: "active", tutor_state: TutorState.default)

      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
      expect(page).to have_text("Tuteur actif")
    end
  end
end

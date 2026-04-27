require "rails_helper"

# Full LLM → ActionCable → DOM pipeline scenarios.
# Vague 5 wired up async cable (config/cable.yml) + inline jobs
# (spec/support/tutor_feature_helpers.rb). Each scenario opts in via
# `tutor_streaming: true`.
RSpec.describe "Tuteur guidé : phase de repérage conversationnelle",
               type: :feature, tutor_streaming: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:exam_session) do
    create(:exam_session, owner: teacher,
      common_presentation: "La société CIME fabrique des véhicules électriques.")
  end
  let(:subject_record) do
    create(:subject, status: :published, owner: teacher, exam_session: exam_session,
      specific_presentation: "Spécialité SIN du sujet CIME.")
  end
  let(:part) do
    create(:part, :specific, subject: subject_record,
      number: 1, title: "Transport et DD", objective_text: "Comparer les modes.", position: 1)
  end
  let!(:question) do
    create(:question, part: part, number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      answer_type: :calcul, points: 2, position: 1)
  end
  let!(:answer) do
    create(:answer, question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation x Distance / 100",
      data_hints: [
        { "source" => "DT1", "location" => "tableau Consommation moyenne" },
        { "source" => "mise_en_situation", "location" => "distance 186 km" }
      ])
  end
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  let!(:spotting_conversation) do
    spotting_state = TutorState.new(
      current_phase:        "spotting_data",
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      {
        question.id.to_s => QuestionState.new(
          phase: "spotting_data", step: 0, hints_used: 0, last_confidence: nil,
          error_types: [], completed_at: nil, intro_seen: true)
      }, welcome_sent: true, last_activity_at: nil)
    create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: spotting_state)
  end

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)
  end

  def open_tutor_drawer
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css("[data-chat-drawer-target='drawer'].translate-x-0", visible: :all, wait: 5)
  end

  before { login_as_student(student, classroom) }

  scenario "le tuteur répond à une question en phase spotting_data", js: true do
    FakeRubyLlm.setup_stub(
      content: "Où penses-tu trouver les informations pour cette question ?",
      tool_calls: []
    )

    visit_question_page
    open_tutor_drawer

    find("[data-tutor-chat-target='input']", visible: :all).set("Bonjour")
    find("[data-tutor-chat-target='sendButton']", visible: :all).click

    drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer).to have_text("Où penses-tu trouver les informations", wait: 10)
  end

  scenario "une réponse correcte déclenche l'affichage du DataHintsComponent", js: true do
    success_tool_call = double("RubyLLM::ToolCall",
      name: "evaluate_spotting",
      arguments: {
        "task_type_identified" => "calcul",
        "sources_identified"   => [ "DT1", "mise_en_situation" ],
        "missing_sources"      => [],
        "extra_sources"        => [],
        "feedback_message"     => "Bien repéré !",
        "relaunch_prompt"      => "",
        "outcome"              => "success"
      }
    )
    FakeRubyLlm.setup_stub(
      content: "Bien repéré ! Les données sont effectivement dans la documentation.",
      tool_calls: [ success_tool_call ]
    )

    visit_question_page
    open_tutor_drawer

    find("[data-tutor-chat-target='input']", visible: :all).set(
      "Je pense que les données sont dans les documents techniques et la mise en situation."
    )
    find("[data-tutor-chat-target='sendButton']", visible: :all).click

    expect(page).to have_css(".data-hints-card", wait: 10)
    expect(page).to have_text("DT1", wait: 5)
    expect(page).to have_text("tableau Consommation moyenne")
    expect(page).to have_text("mise_en_situation")
    expect(page).to have_text("distance 186 km")
  end

  scenario "forced_reveal → DataHintsComponent affiché", js: true do
    forced_tool_call = double("RubyLLM::ToolCall",
      name: "evaluate_spotting",
      arguments: {
        "task_type_identified" => "",
        "sources_identified"   => [],
        "missing_sources"      => [ "DT1", "mise_en_situation" ],
        "extra_sources"        => [],
        "feedback_message"     => "Je vais t'indiquer où se trouvaient les données.",
        "relaunch_prompt"      => "",
        "outcome"              => "forced_reveal"
      }
    )
    FakeRubyLlm.setup_stub(
      content: "Je vais t'indiquer où se trouvaient les données.",
      tool_calls: [ forced_tool_call ]
    )

    visit_question_page
    open_tutor_drawer

    find("[data-tutor-chat-target='input']", visible: :all).set("Je ne sais vraiment pas.")
    find("[data-tutor-chat-target='sendButton']", visible: :all).click

    expect(page).to have_css(".data-hints-card", wait: 10)
    expect(page).to have_text("DT1")
    expect(page).to have_text("tableau Consommation moyenne")
  end

  scenario "le filtre regex remplace un output LLM contenant 'DT1' par une relance neutre", js: true do
    FakeRubyLlm.setup_stub(
      content: "Les données se trouvent dans DT1, tableau page 3.",
      tool_calls: []
    )

    visit_question_page
    open_tutor_drawer

    find("[data-tutor-chat-target='input']", visible: :all).set("Je pense que c'est dans l'énoncé.")
    find("[data-tutor-chat-target='sendButton']", visible: :all).click

    drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer).to have_text("Reformule ta réponse", wait: 10)
    expect(drawer).not_to have_text("DT1")
  end
end

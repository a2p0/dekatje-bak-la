require "rails_helper"

RSpec.describe "Parcours tuteur complet (E2E)", type: :feature, tutor_streaming: true do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student) do
    create(:student, classroom: classroom,
      api_key: "sk-test-key", api_provider: :anthropic, use_personal_key: true)
  end
  let(:subject_record) do
    create(:subject,
      status: :published, owner: teacher,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end
  let(:part) do
    create(:part, :specific, subject: subject_record,
      number: 1, title: "Transport et DD",
      objective_text: "Comparer les modes.", position: 1)
  end
  let!(:question) do
    create(:question, part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      answer_type: :calcul, points: 2, position: 1)
  end
  let!(:answer) { create(:answer, question: question) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  let!(:autonomous_session) do
    create(:student_session,
      student: student, subject: subject_record, mode: :autonomous)
  end

  before { login_as_student(student, classroom) }


  # Helper — build a TutorState anchored on the current question with a
  # given starting phase. Required because TutorState.default starts in
  # :idle, which is not a valid source in Tutor::ApplyToolCalls::TRANSITION_MATRIX.
  # Pre-seeds question_states so that sync_question_state_and_activity in
  # ProcessMessage does not overwrite current_phase back to "enonce".
  def tutor_state_starting_at(phase)
    # Reference TutorState to ensure tutor_state.rb is autoloaded, which
    # also defines the top-level QuestionState constant.
    TutorState

    question_states =
      if Tutor::ApplyToolCalls::QUESTION_REQUIRED_PHASES.include?(phase.to_s)
        qs = QuestionState.new(
          phase: phase.to_s, step: nil, hints_used: 0, last_confidence: nil,
          error_types: [], completed_at: nil, intro_seen: false
        )
        { question.id.to_s => qs }
      else
        {}
      end

    TutorState.new(
      current_phase:        phase,
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      question_states,
      welcome_sent:         true,
      last_activity_at:     nil)
  end

  def fake_tool_call(name:, arguments: {})
    double("RubyLLM::ToolCall", name: name, arguments: arguments)
  end

  def open_drawer_and_send(message)
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-0",
      visible: :all, wait: 5
    )
    # Wait for ActionCable subscription to be established before sending,
    # otherwise the broadcast from the inline job may arrive before the
    # subscription is ready (or the drawer replacement by conversations#create
    # may overwrite the chips rendered by the broadcast).
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)
    find("[data-tutor-chat-target='input']", visible: :all).set(message)
    find("[data-tutor-chat-target='sendButton']", visible: :all).click
  end

  scenario "transition greeting → enonce : le tool 'transition' fait progresser current_phase", js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active",
      tutor_state: tutor_state_starting_at("greeting"))

    FakeRubyLlm.setup_stub(
      content:    "Voici la question sur laquelle tu vas travailler.",
      tool_calls: [ fake_tool_call(
        name:      "transition",
        arguments: { "phase" => "enonce", "question_id" => question.id }
      ) ]
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    open_drawer_and_send("Bonjour")

    expect(page).to have_text("Voici la question", wait: 10)
    expect(conv.reload.tutor_state.current_phase).to eq("enonce")
  end

  scenario "transition enonce → spotting_type : tool 'transition' avec question_id avance la phase", js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active",
      tutor_state: tutor_state_starting_at("enonce"))

    FakeRubyLlm.setup_stub(
      content:    "Quel type de tâche te demande-t-on dans cette question ?",
      tool_calls: [ fake_tool_call(
        name:      "transition",
        arguments: { "phase" => "spotting_type", "question_id" => question.id }
      ) ]
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    open_drawer_and_send("J'ai lu l'énoncé.")

    expect(page).to have_text("Quel type de tâche", wait: 10)
    expect(conv.reload.tutor_state.current_phase).to eq("spotting_type")
  end

  scenario "guiding : request_hint(level: 1) affiche les chips de guidage dans le drawer",
           js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active",
      tutor_state: tutor_state_starting_at("guiding"))

    FakeRubyLlm.setup_stub(
      content:    "Indice 1 : pense à la formule distance × consommation / 100.",
      tool_calls: [ fake_tool_call(name: "request_hint", arguments: { "level" => 1 }) ]
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    open_drawer_and_send("Je ne comprends pas la formule.")

    expect(page).to have_css("#tutor-chips [data-chip-action='send']", text: "Un indice", wait: 10)
  end

  scenario "validation : transition vers :validating injecte les confidence chips dans le drawer",
           js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active",
      tutor_state: tutor_state_starting_at("guiding"))

    FakeRubyLlm.setup_stub(
      content:    "Bravo ! À quel point étais-tu sûr(e) ?",
      tool_calls: [ fake_tool_call(
        name:      "transition",
        arguments: { "phase" => "validating", "question_id" => question.id }
      ) ]
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    open_drawer_and_send("J'ai obtenu 56,73 litres.")

    expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", wait: 10)
  end

  scenario "confiance : cliquer un niveau depuis le drawer enregistre last_confidence et bascule en :feedback",
           js: true,
           pending: "PATCH /confidence reaches server but Turbo stream replacement does not update DOM in the JS test harness — backend covered by request spec" do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "validating",
      tutor_state: tutor_state_starting_at("validating"))

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )

    expect(page).to have_css("[data-chat-connected='true']", wait: 10)
    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-0",
      visible: :all, wait: 5
    )
    expect(page).to have_css("#tutor-chips [data-chip-action='confidence']", wait: 5)
    find("#tutor-chips [data-chip-action='confidence'][data-chip-level='3']").click

    # Wait for confidence chips to be replaced by feedback chips, which confirms
    # the PATCH request completed and the turbo-stream updated the DOM.
    expect(page).to have_no_css("#tutor-chips [data-chip-action='confidence']", wait: 10)

    expect(conv.reload.lifecycle_state).to eq("feedback")
    q_state = conv.tutor_state.question_states[question.id.to_s]
    expect(q_state.last_confidence).to eq(3)
  end

  scenario "persistance : rouvrir le drawer conserve les messages précédents", js: true do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active", tutor_state: TutorState.default.with(welcome_sent: true))
    create(:message, conversation: conv, role: :user,      content: "Premier message élève")
    create(:message, conversation: conv, role: :assistant, content: "Réponse du tuteur")

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    drawer = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer).to have_text("Premier message élève", wait: 5)
    expect(drawer).to have_text("Réponse du tuteur")

    find("button[aria-label='Fermer le tutorat']", wait: 5).click

    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-full",
      visible: :all, wait: 15
    )

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    drawer_reopened = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer_reopened).to have_text("Premier message élève")
    expect(drawer_reopened).to have_text("Réponse du tuteur")
  end
end

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
  def tutor_state_starting_at(phase)
    TutorState.new(
      current_phase:        phase,
      current_question_id:  question.id,
      concepts_mastered:    [],
      concepts_to_revise:   [],
      discouragement_level: 0,
      question_states:      {}, welcome_sent: true, last_activity_at: nil)
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

  # ───── Pending scenarios — UI gaps to close in a future wave ─────
  #
  # These three scenarios exercise drawer-side UI pieces that are
  # deliberately NOT part of Vagues 4-6:
  #
  # - Hint counter display: no `[data-hint-count]` rendered in the
  #   drawer yet. Tutor::ApplyToolCalls#apply_request_hint tracks
  #   hints_used server-side (covered by unit specs), but nothing
  #   broadcasts the count back to the DOM.
  # - Confidence form auto-injection: when the LLM emits a transition
  #   to :validating, the current drawer does not inject the
  #   _confidence_form partial. The partial exists and works standalone
  #   (Task 3 Vague 4) but is not wired to the broadcast pipeline.
  # - Confidence click from drawer: depends on the form being rendered
  #   by the prior scenario, so it inherits the same gap.
  #
  # Backend coverage is complete (apply_tool_calls_spec, conversations
  # request spec with PATCH /confidence). Reactivate when the drawer
  # gains server-driven partial injection on phase transitions.

  scenario "guiding : request_hint(level: 1) affiche le compteur d'indices dans le drawer",
           js: true, pending: "UI gap: hint counter not rendered in drawer yet" do
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

    expect(page).to have_css("[data-hint-count]", wait: 5)
  end

  scenario "validation : transition vers :validating injecte le formulaire de confiance dans le drawer",
           js: true, pending: "UI gap: confidence form not auto-injected on phase transition" do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "active",
      tutor_state: tutor_state_starting_at("guiding"))

    FakeRubyLlm.setup_stub(
      content:    "Bravo ! À quel point étais-tu sûr(e) ?",
      tool_calls: [ fake_tool_call(
        name:      "transition",
        arguments: { "phase" => "validating" }
      ) ]
    )

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )
    open_drawer_and_send("J'ai obtenu 56,73 litres.")

    expect(page).to have_css("[data-controller='confidence-form']", wait: 10)
  end

  scenario "confiance : cliquer un niveau depuis le drawer enregistre last_confidence et bascule en :feedback",
           js: true, pending: "UI gap: confidence form not auto-injected on phase transition (see prior scenario)" do
    conv = create(:conversation,
      student: student, subject: subject_record,
      lifecycle_state: "validating",
      tutor_state: tutor_state_starting_at("validating"))

    visit student_question_path(
      access_code: classroom.access_code,
      subject_id:  subject_record.id,
      id:          question.id
    )

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click
    click_button "Moyennement sûr"

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

    find("button[aria-label='Fermer le tutorat']").click

    expect(page).to have_css(
      "[data-chat-drawer-target='drawer'].translate-x-full",
      visible: :all, wait: 5
    )

    find("button[aria-label='Ouvrir le tutorat IA']", match: :first).click

    drawer_reopened = find("[data-chat-drawer-target='drawer']", visible: :all)
    expect(drawer_reopened).to have_text("Premier message élève")
    expect(drawer_reopened).to have_text("Réponse du tuteur")
  end
end

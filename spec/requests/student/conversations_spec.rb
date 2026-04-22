require "rails_helper"

RSpec.describe "Student::Conversations", type: :request do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let!(:cs)          { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part, status: :validated) }
  let!(:answer)      { create(:answer, question: question) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /:access_code/conversations" do
    before do
      allow(Tutor::BuildWelcomeMessage).to receive(:call).and_return(Tutor::Result.ok)
    end

    it "creates a conversation for the subject and returns conversation_id" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { subject_id: exam_subject.id },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to be_present
      expect(Conversation.count).to eq(1)
      expect(Conversation.last.student).to eq(student)
      expect(Conversation.last.subject).to eq(exam_subject)
    end

    it "returns existing active conversation if one already exists" do
      existing = create(:conversation, student: student, subject: exam_subject,
                        lifecycle_state: "active", tutor_state: TutorState.default)

      post student_conversations_path(access_code: classroom.access_code),
           params: { subject_id: exam_subject.id },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to eq(existing.id)
      expect(Conversation.count).to eq(1)
    end

    it "returns 404 for unknown subject" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { subject_id: 999_999 },
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    context "when student has no personal key but classroom free mode is enabled" do
      let(:student) do
        create(:student, classroom: classroom, api_key: nil, use_personal_key: false)
      end

      before do
        classroom.update!(tutor_free_mode_enabled: true)
        user.update!(openrouter_api_key: "or-teacher-free-key")
      end

      it "allows creating the conversation via the teacher key" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "when neither a personal key nor free mode is available" do
      let(:student) do
        create(:student, classroom: classroom, api_key: nil, use_personal_key: false)
      end

      before do
        classroom.update!(tutor_free_mode_enabled: false)
      end

      it "rejects with 422 and an error message pointing to the settings page" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
        expect(json["settings_url"]).to include("/settings")
      end
    end
  end

  describe "POST /:access_code/conversations/:id/messages" do
    let!(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: TutorState.default)
    end

    before do
      allow(ProcessTutorMessageJob).to receive(:perform_later)
    end

    it "enqueues the job and returns ok" do
      post messages_student_conversation_path(
             access_code: classroom.access_code,
             id:          conversation.id
           ),
           params: { content: "Je ne comprends pas.", question_id: question.id },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(ProcessTutorMessageJob).to have_received(:perform_later).with(
        conversation.id,
        "Je ne comprends pas.",
        question.id
      )
    end

    it "returns 422 for blank content" do
      post messages_student_conversation_path(
             access_code: classroom.access_code,
             id:          conversation.id
           ),
           params: { content: "   ", question_id: question.id },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for conversation belonging to another student" do
      other_student = create(:student, classroom: classroom)
      other_conv    = create(:conversation, student: other_student, subject: exam_subject,
                             lifecycle_state: "active", tutor_state: TutorState.default)

      post messages_student_conversation_path(
             access_code: classroom.access_code,
             id:          other_conv.id
           ),
           params: { content: "test", question_id: question.id },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /:access_code/conversations/:id/confidence" do
    let(:tutor_state_with_question) do
      TutorState.new(
        current_phase:        "validating",
        current_question_id:  question.id,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {
          question.id.to_s => QuestionState.new(
            step: 0, hints_used: 0, last_confidence: nil,
            error_types: [], completed_at: nil, intro_seen: false)
        }, welcome_sent: false)
    end

    let!(:conversation) do
      create(:conversation,
             student:          student,
             subject:          exam_subject,
             lifecycle_state:  "validating",
             tutor_state:      tutor_state_with_question)
    end

    it "saves the confidence level and returns a Turbo Stream" do
      patch confidence_student_conversation_path(
              access_code: classroom.access_code,
              id:          conversation.id
            ),
            params: { level: 3 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("turbo-stream")

      conversation.reload
      q_state = conversation.tutor_state.question_states[question.id.to_s]
      expect(q_state.last_confidence).to eq(3)
    end

    it "transitions lifecycle from validating to feedback" do
      patch confidence_student_conversation_path(
              access_code: classroom.access_code,
              id:          conversation.id
            ),
            params: { level: 4 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(conversation.reload.lifecycle_state).to eq("feedback")
    end

    it "rejects invalid confidence levels" do
      patch confidence_student_conversation_path(
              access_code: classroom.access_code,
              id:          conversation.id
            ),
            params: { level: 9 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when no current_question_id is set" do
      conversation.update!(tutor_state: TutorState.default, lifecycle_state: "validating")

      patch confidence_student_conversation_path(
              access_code: classroom.access_code,
              id:          conversation.id
            ),
            params: { level: 3 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when conversation belongs to another student" do
      other_student = create(:student, classroom: classroom)
      other_conv    = create(:conversation,
                             student:         other_student,
                             subject:         exam_subject,
                             lifecycle_state: "validating",
                             tutor_state:     tutor_state_with_question)

      patch confidence_student_conversation_path(
              access_code: classroom.access_code,
              id:          other_conv.id
            ),
            params: { level: 3 },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "confidence form partial rendering" do
    let(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "validating", tutor_state: TutorState.default)
    end

    it "renders 5 confidence buttons with labels and data-controller" do
      html = ApplicationController.render(
        partial: "student/conversations/confidence_form",
        locals:  {
          conversation: conversation,
          question_id:  question.id,
          access_code:  classroom.access_code
        }
      )

      expect(html).to include("Très peu sûr")
      expect(html).to include("Très sûr")
      expect(html).to include(%(data-controller="confidence-form"))
      (1..5).each { |n| expect(html).to include(%(value="#{n}")) }
    end
  end

  describe "message partial rendering" do
    let(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: TutorState.default)
    end

    def render_message(message)
      ApplicationController.render(
        partial: "student/conversations/message",
        locals:  { message: message }
      )
    end

    it "renders a user message with self-end alignment and role data-attribute" do
      msg  = create(:message, conversation: conversation, role: :user, content: "Ma question")
      html = render_message(msg)

      expect(html).to include("Ma question")
      expect(html).to include("self-end")
      expect(html).to include(%(data-message-role="user"))
      expect(html).to include(%(data-message-id="#{msg.id}"))
    end

    it "renders an assistant message with self-start alignment" do
      msg  = create(:message, conversation: conversation, role: :assistant, content: "Ma réponse")
      html = render_message(msg)

      expect(html).to include("Ma réponse")
      expect(html).to include("self-start")
      expect(html).to include(%(data-message-role="assistant"))
    end

    it "renders a system message with self-center alignment" do
      msg  = create(:message, conversation: conversation, role: :system, content: "Info système")
      html = render_message(msg)

      expect(html).to include("Info système")
      expect(html).to include("self-center")
      expect(html).to include(%(data-message-role="system"))
    end
  end

  describe "POST #create — welcome message (044)" do
    before do
      allow(Tutor::BuildWelcomeMessage).to receive(:call).and_return(Tutor::Result.ok)
    end

    context "when welcome has not been sent yet (welcome_sent: false)" do
      it "calls BuildWelcomeMessage" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Tutor::BuildWelcomeMessage).to have_received(:call).once
      end

      it "includes a turbo-stream replace for the activation banner" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("tutor-activation-banner")
      end

      it "includes a turbo-stream dispatch for drawer-open event" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("tutor:drawer-open")
      end
    end

    context "when welcome has already been sent (welcome_sent: true)" do
      before do
        create(:conversation, student: student, subject: exam_subject,
               lifecycle_state: "active",
               tutor_state: TutorState.default.with(welcome_sent: true))
      end

      it "does not call BuildWelcomeMessage again" do
        post student_conversations_path(access_code: classroom.access_code),
             params: { subject_id: exam_subject.id },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(Tutor::BuildWelcomeMessage).not_to have_received(:call)
      end
    end
  end

  describe "PATCH #mark_intro_seen (044)" do
    let!(:conversation) do
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: TutorState.default)
    end

    it "sets intro_seen to true for the given question and returns 200" do
      patch mark_intro_seen_student_conversation_path(
              access_code: classroom.access_code,
              id: conversation.id
            ),
            params: { question_id: question.id }

      expect(response).to have_http_status(:ok)
      qs = conversation.reload.tutor_state.question_states[question.id.to_s]
      expect(qs&.intro_seen).to eq(true)
    end
  end
end
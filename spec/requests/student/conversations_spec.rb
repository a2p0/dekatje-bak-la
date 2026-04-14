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
end

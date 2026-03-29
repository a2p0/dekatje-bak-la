require "rails_helper"

RSpec.describe "Student::Conversations", type: :request do
  let(:user) { create(:user) }
  let(:classroom) { create(:classroom, owner: user) }
  let(:student) { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:subject_record) { create(:subject, owner: user, status: :published) }
  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }
  let(:part) { create(:part, subject: subject_record) }
  let(:question) { create(:question, part: part, status: :validated) }

  before do
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "POST /conversations" do
    it "creates a conversation for the question" do
      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to be_present

      expect(Conversation.count).to eq(1)
      expect(Conversation.last.student).to eq(student)
      expect(Conversation.last.question).to eq(question)
    end

    it "returns existing conversation if one already exists" do
      existing = create(:conversation, student: student, question: question)

      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["conversation_id"]).to eq(existing.id)
      expect(Conversation.count).to eq(1)
    end

    it "rejects when student has no API key" do
      student.update!(api_key: nil)

      post student_conversations_path(access_code: classroom.access_code),
           params: { question_id: question.id },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("cle IA")
    end
  end

  describe "POST /conversations/:id/message" do
    let!(:conversation) { create(:conversation, student: student, question: question) }

    it "adds a message and enqueues TutorStreamJob" do
      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "Aide-moi avec cette question" },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:ok)

      conversation.reload
      expect(conversation.messages.last["role"]).to eq("user")
      expect(conversation.messages.last["content"]).to eq("Aide-moi avec cette question")

      expect(TutorStreamJob).to have_been_enqueued.with(conversation.id)
    end

    it "rejects empty messages" do
      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "  " },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects when conversation is already streaming" do
      conversation.update!(streaming: true)

      post message_student_conversation_path(access_code: classroom.access_code, id: conversation.id),
           params: { content: "Question" },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:too_many_requests)
    end

    it "prevents accessing another student's conversation" do
      other_student = create(:student, classroom: classroom)
      other_conversation = create(:conversation, student: other_student, question: question)

      post message_student_conversation_path(access_code: classroom.access_code, id: other_conversation.id),
           params: { content: "Hack" },
           headers: { "Accept" => "application/json" },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end

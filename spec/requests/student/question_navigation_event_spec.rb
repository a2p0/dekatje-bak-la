require "rails_helper"

RSpec.describe "Student question navigation events", type: :request do
  let(:teacher) { create(:user) }
  let(:classroom) { create(:classroom, owner: teacher) }
  let(:student) { create(:student, classroom: classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let(:part) { create(:part, subject: subject_obj) }
  let(:question) { create(:question, part: part, status: :validated) }
  let!(:answer) { create(:answer, question: question) }

  before do
    create(:classroom_subject, classroom: classroom, subject: subject_obj)
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  describe "GET /:access_code/subjects/:subject_id/questions/:id" do
    it "records a navigated_here event in the conversation's QuestionTrace" do
      get student_question_path(access_code: classroom.access_code,
                                subject_id: subject_obj.id, id: question.id)

      expect(response).to have_http_status(:ok)
      conv = Conversation.find_by(student: student, subject: subject_obj)
      expect(conv).not_to be_nil
      types = conv.tutor_state.trace_for(question.id).events.map { |e| e["type"] }
      expect(types).to include("navigated_here")
    end

    it "creates a disabled conversation silently if none exists yet" do
      expect(Conversation.where(student: student, subject: subject_obj)).to be_empty
      get student_question_path(access_code: classroom.access_code,
                                subject_id: subject_obj.id, id: question.id)
      conv = Conversation.find_by(student: student, subject: subject_obj)
      expect(conv).not_to be_nil
      expect(conv).to be_disabled
    end

    it "does not break the page if event recording fails" do
      allow(Tutor::RecordEvent).to receive(:call).and_raise(StandardError, "boom")
      get student_question_path(access_code: classroom.access_code,
                                subject_id: subject_obj.id, id: question.id)
      expect(response).to have_http_status(:ok)
    end
  end
end

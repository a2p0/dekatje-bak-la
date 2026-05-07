require "rails_helper"

RSpec.describe "Student::Events", type: :request do
  let(:classroom) { create(:classroom) }
  let(:student)   { create(:student, classroom: classroom) }
  let(:subject_record) { create(:subject) }
  let(:question) { create(:question, part: create(:part, subject: subject_record)) }

  def sign_in_student
    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }
  end

  before do
    sign_in_student
    create(:classroom_subject, classroom: classroom, subject: subject_record)
  end

  describe "POST /:access_code/events" do
    it "creates an event in the conversation's question_trace" do
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "viewed_data_hints"
      }

      expect(response).to have_http_status(:no_content)
      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).not_to be_nil
      trace = conv.tutor_state.trace_for(question.id)
      expect(trace.events.last["type"]).to eq("viewed_data_hints")
      expect(trace.events.last["source"]).to eq("page_click")
    end

    it "creates a disabled Conversation silently if none exists yet" do
      expect(Conversation.where(student: student, subject: subject_record)).to be_empty
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "navigated_here"
      }

      conv = Conversation.find_by(student: student, subject: subject_record)
      expect(conv).not_to be_nil
      expect(conv).to be_disabled
    end

    it "rejects unknown event types" do
      post "/#{classroom.access_code}/events", params: {
        subject_id:  subject_record.id,
        question_id: question.id,
        type:        "totally_unknown"
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

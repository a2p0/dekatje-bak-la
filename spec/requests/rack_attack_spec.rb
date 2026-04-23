require "rails_helper"

RSpec.describe "Rack::Attack tutor throttle", type: :request do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student) do
    create(:student,
      classroom: classroom,
      api_key:   "sk-test",
      api_provider: :anthropic,
      use_personal_key: true)
  end
  let(:exam_subject)   { create(:subject, owner: user, status: :published) }
  let!(:classroom_sub) { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)           { create(:part, subject: exam_subject) }
  let(:question)       { create(:question, part: part, status: :validated) }
  let!(:answer)        { create(:answer, question: question) }
  let!(:conversation) do
    create(:conversation,
      student: student, subject: exam_subject,
      lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    post student_session_path(access_code: classroom.access_code),
         params: { username: student.username, password: "password123" }

    allow(ProcessTutorMessageJob).to receive(:perform_later)
  end

  after do
    Rack::Attack.reset!
    Rack::Attack.enabled = false
  end

  def send_message(i)
    post messages_student_conversation_path(
           access_code: classroom.access_code,
           id:          conversation.id
         ),
         params: { content: "Message #{i}", question_id: question.id },
         as: :json
  end

  it "allows the first 10 messages per minute and blocks the 11th with 429" do
    10.times do |i|
      send_message(i)
      expect(response.status).not_to eq(429), "Request #{i + 1} was rate limited early"
    end

    send_message(11)

    expect(response).to have_http_status(429)
    json = JSON.parse(response.body)
    expect(json["error"]).to include("minute")
  end

  it "returns 429 with JSON body from the throttled_responder" do
    11.times { |i| send_message(i) }

    expect(response).to have_http_status(429)
    expect(response.content_type).to include("application/json")
    expect(JSON.parse(response.body)).to have_key("error")
  end
end

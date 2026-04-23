require "rails_helper"

RSpec.describe ResolveTutorApiKey do
  let(:user)      { create(:user) }
  let(:classroom) { create(:classroom, owner: user) }
  let(:student)   { create(:student, classroom: classroom) }

  subject(:service) { described_class.new(student: student, classroom: classroom) }

  describe "#call" do
    context "when student has a personal key and use_personal_key is true" do
      before do
        student.update!(
          api_key:          "student-sk-123",
          api_provider:     :anthropic,
          use_personal_key: true
        )
      end

      it "returns the student key" do
        result = service.call
        expect(result[:api_key]).to eq("student-sk-123")
        expect(result[:provider]).to eq("anthropic")
      end
    end

    context "when student key absent but classroom free mode enabled and teacher has key" do
      before do
        classroom.update!(tutor_free_mode_enabled: true)
        user.update!(openrouter_api_key: "or-teacher-key")
        student.update!(use_personal_key: false)
      end

      it "returns the teacher key" do
        result = service.call
        expect(result[:api_key]).to eq("or-teacher-key")
        expect(result[:provider]).to eq("openrouter")
      end
    end

    context "when no key is available" do
      before { student.update!(use_personal_key: false) }

      it "raises Tutor::NoApiKeyError" do
        expect { service.call }.to raise_error(Tutor::NoApiKeyError)
      end
    end
  end
end

# spec/jobs/tutor_stream_job_spec.rb
require "rails_helper"

RSpec.xdescribe "TutorStreamJob (removed in vague1)", type: :job do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:part) { create(:part) }
  let(:question) { create(:question, part: part) }
  let!(:answer) { create(:answer, question: question) }
  let(:conversation) do
    create(:conversation,
      student: student,
      question: question,
      messages: [ { "role" => "user", "content" => "Bonjour, aide-moi" } ]
    )
  end

  let(:mock_client) { instance_double(AiClientFactory) }

  before do
    allow(AiClientFactory).to receive(:build).and_return(mock_client)
  end

  describe "#perform" do
    it "streams tokens and saves the full response" do
      allow(mock_client).to receive(:stream) do |**_args, &block|
        block.call("Bonjour")
        block.call(" !")
      end

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { token: "Bonjour" })
      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { token: " !" })
      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { done: true })

      described_class.perform_now(conversation.id)

      conversation.reload
      expect(conversation.messages.last["role"]).to eq("assistant")
      expect(conversation.messages.last["content"]).to eq("Bonjour !")
      expect(conversation.streaming).to be(false)
      expect(conversation.tokens_used).to be > 0
    end

    it "sets streaming flag during execution" do
      allow(mock_client).to receive(:stream) do |**_args, &block|
        expect(conversation.reload.streaming).to be(true)
        block.call("token")
      end
      allow(ActionCable.server).to receive(:broadcast)

      described_class.perform_now(conversation.id)

      expect(conversation.reload.streaming).to be(false)
    end

    it "broadcasts error on API failure" do
      allow(mock_client).to receive(:stream).and_raise(RuntimeError, "API error 401: Unauthorized")

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { error: "Clé API invalide. Vérifiez vos réglages." })

      described_class.perform_now(conversation.id)

      expect(conversation.reload.streaming).to be(false)
    end

    it "broadcasts timeout error" do
      allow(mock_client).to receive(:stream).and_raise(Faraday::TimeoutError)

      expect(ActionCable.server).to receive(:broadcast)
        .with("conversation_#{conversation.id}", { error: "Le serveur n'a pas répondu. Réessayez." })

      described_class.perform_now(conversation.id)
    end

    it "builds client with student provider and model" do
      allow(mock_client).to receive(:stream) { |**_args, &block| block.call("ok") }
      allow(ActionCable.server).to receive(:broadcast)

      expect(AiClientFactory).to receive(:build).with(
        provider: "anthropic",
        api_key: "sk-test",
        model: student.effective_model
      ).and_return(mock_client)

      described_class.perform_now(conversation.id)
    end
  end
end

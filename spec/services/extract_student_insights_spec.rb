# spec/services/extract_student_insights_spec.rb
require "rails_helper"

RSpec.describe ExtractStudentInsights do
  let(:student) { create(:student, api_provider: :anthropic, api_key: "sk-test") }
  let(:part) { create(:part) }
  let(:question) { create(:question, part: part) }
  let(:conversation) do
    create(:conversation,
      student: student,
      question: question,
      messages: [
        { "role" => "user", "content" => "Comment calculer ?" },
        { "role" => "assistant", "content" => "Quelle formule utiliser ?" },
        { "role" => "user", "content" => "P = U x I ?" },
        { "role" => "assistant", "content" => "Oui ! C'est correct." }
      ]
    )
  end

  let(:mock_client) { instance_double(AiClientFactory) }

  before do
    allow(AiClientFactory).to receive(:build).and_return(mock_client)
  end

  describe ".call" do
    it "extracts and persists insights from conversation" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "mastered", "concept": "puissance electrique", "text": "Connait P=UI"}]'
      )

      result = described_class.call(conversation: conversation)

      expect(result.size).to eq(1)
      expect(StudentInsight.count).to eq(1)

      insight = StudentInsight.last
      expect(insight.insight_type).to eq("mastered")
      expect(insight.concept).to eq("puissance electrique")
      expect(insight.student).to eq(student)
      expect(insight.subject).to eq(part.subject)
    end

    it "returns empty array for short conversations (< 4 messages)" do
      short_conversation = create(:conversation,
        student: student,
        question: question,
        messages: [
          { "role" => "user", "content" => "Bonjour" },
          { "role" => "assistant", "content" => "Salut !" }
        ]
      )

      result = described_class.call(conversation: short_conversation)

      expect(result).to eq([])
      expect(StudentInsight.count).to eq(0)
    end

    it "handles malformed JSON gracefully" do
      allow(mock_client).to receive(:call).and_return("Not valid JSON at all")

      result = described_class.call(conversation: conversation)

      expect(result).to eq([])
      expect(StudentInsight.count).to eq(0)
    end

    it "skips insights with unknown types" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "unknown_type", "concept": "test", "text": "skip me"}, {"type": "mastered", "concept": "valid", "text": "keep me"}]'
      )

      described_class.call(conversation: conversation)

      expect(StudentInsight.count).to eq(1)
      expect(StudentInsight.last.concept).to eq("valid")
    end

    it "skips insights with blank concept" do
      allow(mock_client).to receive(:call).and_return(
        '[{"type": "mastered", "concept": "", "text": "no concept"}]'
      )

      described_class.call(conversation: conversation)

      expect(StudentInsight.count).to eq(0)
    end

    it "falls back to server ANTHROPIC_API_KEY when student has no key" do
      student.update!(api_key: nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("sk-server-key")
      allow(ENV).to receive(:fetch).and_call_original

      expect(AiClientFactory).to receive(:build).with(
        provider: :anthropic,
        api_key: "sk-server-key",
        model: "claude-haiku-4-5-20251001"
      ).and_return(mock_client)

      allow(mock_client).to receive(:call).and_return("[]")

      described_class.call(conversation: conversation)
    end
  end
end

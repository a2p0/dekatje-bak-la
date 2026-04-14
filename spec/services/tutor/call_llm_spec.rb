require "rails_helper"

RSpec.describe Tutor::CallLlm do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let(:conversation) { create(:conversation, student: student, subject: exam_subject) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let(:student_msg)  { create(:message, conversation: conversation, role: :assistant, content: "", chunk_index: 0) }

  before do
    FakeRubyLlm.setup_stub(content: "Qu'est-ce que tu as essayé jusqu'ici ?", tool_calls: [])
  end

  subject(:result) do
    described_class.call(
      conversation:    conversation,
      system_prompt:   "Règles pédagogiques...",
      messages:        [ { role: "user", content: "<student_input>Je ne sais pas.</student_input>" } ],
      student_message: student_msg
    )
  end

  it "returns ok" do
    expect(result.ok?).to be true
  end

  it "returns the full content" do
    expect(result.value[:full_content]).to eq("Qu'est-ce que tu as essayé jusqu'ici ?")
  end

  it "returns an empty tool_calls array when no tools called" do
    expect(result.value[:tool_calls]).to eq([])
  end

  it "updates the assistant message content" do
    result
    expect(student_msg.reload.content).to eq("Qu'est-ce que tu as essayé jusqu'ici ?")
  end

  it "sets streaming_finished_at on the assistant message" do
    result
    expect(student_msg.reload.streaming_finished_at).not_to be_nil
  end

  context "when no API key is available" do
    before do
      student.update!(use_personal_key: false)
      classroom.update!(tutor_free_mode_enabled: false)
    end

    it "returns err with NoApiKeyError message" do
      r = described_class.call(
        conversation:    conversation,
        system_prompt:   "...",
        messages:        [],
        student_message: student_msg
      )
      expect(r.err?).to be true
      expect(r.error).to include("clé API")
    end

    it "broadcasts a typed error event before returning err" do
      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "error")
      )
      described_class.call(
        conversation:    conversation,
        system_prompt:   "...",
        messages:        [],
        student_message: student_msg
      )
    end
  end

  describe "chunk-level token broadcasts" do
    before do
      FakeRubyLlm.setup_stub(chunks: [ "Bon", "jour ", "élève" ])
    end

    it "broadcasts a typed token event for each non-empty chunk" do
      broadcasted = []
      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        broadcasted << data if channel == "conversation_#{conversation.id}"
      end

      described_class.call(
        conversation:    conversation,
        system_prompt:   "...",
        messages:        [ { role: "user", content: "Aide-moi" } ],
        student_message: student_msg
      )

      token_events = broadcasted.select { |d| d[:type] == "token" }
      expect(token_events.map { |d| d[:token] }).to eq([ "Bon", "jour ", "élève" ])
      expect(token_events).to all(include(message_id: student_msg.id))
    end
  end

  describe "error broadcasts" do
    it "broadcasts a typed error event when RubyLLM raises" do
      FakeRubyLlm.setup_stub(raise_error: RuntimeError.new("401 Unauthorized"))

      expect(ActionCable.server).to receive(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "error", error: a_string_including("401"))
      )

      r = described_class.call(
        conversation:    conversation,
        system_prompt:   "...",
        messages:        [ { role: "user", content: "Aide-moi" } ],
        student_message: student_msg
      )
      expect(r.err?).to be true
    end
  end
end

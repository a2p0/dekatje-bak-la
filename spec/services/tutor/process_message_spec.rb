require "rails_helper"

RSpec.describe Tutor::ProcessMessage do
  let(:user)         { create(:user) }
  let(:classroom)    { create(:classroom, owner: user) }
  let(:student)      { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic, use_personal_key: true) }
  let(:exam_subject) { create(:subject, owner: user, status: :published) }
  let!(:cs)          { create(:classroom_subject, classroom: classroom, subject: exam_subject) }
  let(:part)         { create(:part, subject: exam_subject) }
  let(:question)     { create(:question, part: part) }
  let!(:answer)      { create(:answer, question: question, correction_text: "R = 10 Ω") }
  let(:conversation) do
    create(:conversation, student: student, subject: exam_subject,
           lifecycle_state: "active", tutor_state: TutorState.default)
  end

  before do
    FakeRubyLlm.setup_stub(content: "Qu'avez-vous tenté ?", tool_calls: [])
    allow(ActionCable.server).to receive(:broadcast)
  end

  subject(:result) do
    described_class.call(
      conversation:  conversation,
      student_input: "Je ne sais pas.",
      question:      question
    )
  end

  it "returns ok" do
    expect(result.ok?).to be true
  end

  it "persists a user message" do
    expect { result }.to change(Message.where(role: :user), :count).by(1)
  end

  it "persists an assistant message with content" do
    result
    assistant_msg = Message.where(role: :assistant).last
    expect(assistant_msg).not_to be_nil
    expect(assistant_msg.content).to eq("Qu'avez-vous tenté ?")
  end

  it "broadcasts the assistant message" do
    result
    expect(ActionCable.server).to have_received(:broadcast).with(
      "conversation_#{conversation.id}",
      hash_including(type: "done")
    )
  end

  it "also broadcasts chunk-level token events during streaming" do
    result
    expect(ActionCable.server).to have_received(:broadcast).with(
      "conversation_#{conversation.id}",
      hash_including(type: "token")
    ).at_least(:once)
  end

  it "returns err for blank input" do
    r = described_class.call(
      conversation:  conversation,
      student_input: "   ",
      question:      question
    )
    expect(r.err?).to be true
  end

  context "spotting phase integration" do
    before do
      answer.update!(
        correction_text: "Car = 56,73 l",
        data_hints: [
          { "source" => "DT1", "location" => "tableau Consommation moyenne" }
        ]
      )
    end

    let(:spotting_conversation) do
      state = TutorState.new(
        current_phase:        "spotting",
        current_question_id:  question.id,
        concepts_mastered:    [],
        concepts_to_revise:   [],
        discouragement_level: 0,
        question_states:      {
          question.id.to_s => QuestionState.new(
            step: "initial", hints_used: 0, last_confidence: nil,
            error_types: [], completed_at: nil, intro_seen: false)
        }, welcome_sent: false)
      create(:conversation, student: student, subject: exam_subject,
             lifecycle_state: "active", tutor_state: state)
    end

    context "when LLM output contains a forbidden DT reference" do
      before do
        FakeRubyLlm.setup_stub(
          content: "Les données se trouvent dans DT1.",
          tool_calls: []
        )
      end

      it "replaces content with neutral relaunch" do
        result = described_class.call(
          conversation:  spotting_conversation,
          question:      question,
          student_input: "Je ne sais pas."
        )
        expect(result.ok?).to be true
        assistant_msg = spotting_conversation.messages.reload.find { |m| m.role == "assistant" }
        expect(assistant_msg.content).to include("Reformule ta réponse")
        expect(assistant_msg.content).not_to include("DT1")
      end
    end

    context "when LLM calls evaluate_spotting with outcome success" do
      let(:spotting_tool_call) do
        double("RubyLLM::ToolCall",
          name: "evaluate_spotting",
          arguments: {
            "task_type_identified" => "calcul",
            "sources_identified"   => [ "DT1" ],
            "missing_sources"      => [],
            "extra_sources"        => [],
            "feedback_message"     => "Bien repéré !",
            "relaunch_prompt"      => "",
            "outcome"              => "success"
          }
        )
      end

      before do
        FakeRubyLlm.setup_stub(
          content: "Bien repéré !",
          tool_calls: [ spotting_tool_call ]
        )
      end

      it "broadcasts a data_hints message" do
        expect(ActionCable.server).to receive(:broadcast).with(
          "conversation_#{spotting_conversation.id}",
          hash_including(type: "data_hints")
        ).at_least(:once)

        described_class.call(
          conversation:  spotting_conversation,
          question:      question,
          student_input: "Les données sont dans un document technique."
        )
      end

      it "transitions the conversation to guiding phase" do
        described_class.call(
          conversation:  spotting_conversation,
          question:      question,
          student_input: "Les données sont dans un document technique."
        )
        expect(spotting_conversation.reload.tutor_state.current_phase).to eq("guiding")
      end

      it "creates a system message with data_hints content" do
        described_class.call(
          conversation:  spotting_conversation,
          question:      question,
          student_input: "Les données sont dans un document technique."
        )
        sys_msg = spotting_conversation.messages.reload.find { |m| m.role == "system" }
        expect(sys_msg).to be_present
        expect(sys_msg.content).to include("DT1")
      end
    end

    context "when LLM calls evaluate_spotting with outcome forced_reveal" do
      let(:forced_tool_call) do
        double("RubyLLM::ToolCall",
          name: "evaluate_spotting",
          arguments: {
            "task_type_identified" => "",
            "sources_identified"   => [],
            "missing_sources"      => [ "DT1" ],
            "extra_sources"        => [],
            "feedback_message"     => "Voici où se trouvent les données.",
            "relaunch_prompt"      => "",
            "outcome"              => "forced_reveal"
          }
        )
      end

      before do
        FakeRubyLlm.setup_stub(
          content: "Voici où se trouvent les données.",
          tool_calls: [ forced_tool_call ]
        )
      end

      it "also injects data_hints on forced_reveal" do
        described_class.call(
          conversation:  spotting_conversation,
          question:      question,
          student_input: "Je ne sais vraiment pas."
        )
        sys_msg = spotting_conversation.messages.reload.find { |m| m.role == "system" }
        expect(sys_msg).to be_present
        expect(sys_msg.content).to include("DT1")
      end
    end
  end

  describe "end-to-end tool-call wiring" do
    it "advances the tutor phase from idle to greeting when the LLM calls `transition`" do
      tc = double("ToolCall", name: "transition", arguments: { "phase" => "greeting" })
      FakeRubyLlm.setup_stub(content: "Bonjour !", tool_calls: [ tc ])

      expect(conversation.tutor_state.current_phase).to eq("idle")
      result
      expect(result.ok?).to be true
      expect(conversation.reload.tutor_state.current_phase).to eq("greeting")
    end

    it "preserves chunk-level token broadcasts while capturing tool_calls (FR-008)" do
      tc = double("ToolCall", name: "transition", arguments: { "phase" => "greeting" })
      # chunks stub: FakeRubyLlm joins chunks and sets tool_calls on the final chunk
      FakeRubyLlm.setup_stub(chunks: [ "Bon", "jour ", "élève" ], tool_calls: [ tc ])

      result

      expect(ActionCable.server).to have_received(:broadcast).with(
        "conversation_#{conversation.id}",
        hash_including(type: "token")
      ).at_least(3).times
      expect(conversation.reload.tutor_state.current_phase).to eq("greeting")
    end
  end
end

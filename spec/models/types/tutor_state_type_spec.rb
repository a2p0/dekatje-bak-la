require "rails_helper"

RSpec.describe TutorStateType do
  let(:type) { described_class.new }

  describe "#deserialize" do
    it "returns TutorState.default for nil/empty" do
      expect(type.deserialize(nil)).to eq(TutorState.default)
      expect(type.deserialize("{}")).to eq(TutorState.default)
    end

    it "rebuilds TutorState from serialized hash" do
      raw = {
        "current_question_id" => 42,
        "greeted"             => true,
        "question_traces"     => {
          "42" => {
            "question_id" => 42,
            "events"      => [
              { "type" => "viewed_data_hints", "at" => "2026-05-06T10:00:00Z", "source" => "page_click" }
            ]
          }
        },
        "concepts_seen"       => [ "loi d'Ohm" ]
      }
      state = type.deserialize(raw.to_json)

      expect(state.current_question_id).to eq(42)
      expect(state.greeted).to be(true)
      expect(state.concepts_seen).to eq([ "loi d'Ohm" ])
      trace = state.trace_for(42)
      expect(trace.events.length).to eq(1)
      expect(trace.events.first["type"]).to eq("viewed_data_hints")
    end

    it "tolerates missing fields with defaults" do
      state = type.deserialize({}.to_json)
      expect(state).to eq(TutorState.default)
    end
  end

  describe "#serialize" do
    it "produces a JSON-safe hash that roundtrips through deserialize" do
      trace = QuestionTrace.new(
        question_id: 7,
        events: [ {
          "type" => "student_attempt", "at" => "2026-05-06T10:00:00Z",
          "source" => "llm_message", "content" => "5673", "verdict" => "incorrect"
        } ].freeze
      )
      original = TutorState.default
        .with(current_question_id: 7, greeted: true)
        .with_trace(trace)

      blob = type.serialize(original)
      restored = type.deserialize(blob)

      expect(restored).to eq(original)
    end
  end
end

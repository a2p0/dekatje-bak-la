require "rails_helper"

RSpec.describe TutorStateType do
  subject(:type) { described_class.new }

  describe "#cast" do
    context "when given nil" do
      it "returns TutorState.default" do
        result = type.cast(nil)
        expect(result).to eq(TutorState.default)
      end
    end

    context "when given a TutorState instance" do
      it "returns it unchanged" do
        state = TutorState.default
        expect(type.cast(state)).to be(state)
      end
    end

    context "when given an unexpected type" do
      it "raises ArgumentError on a String" do
        expect { type.cast("bogus") }.to raise_error(ArgumentError, /Cannot cast String/)
      end

      it "raises ArgumentError on an Integer" do
        expect { type.cast(42) }.to raise_error(ArgumentError, /Cannot cast Integer/)
      end

      it "raises ArgumentError on an Array" do
        expect { type.cast([]) }.to raise_error(ArgumentError, /Cannot cast Array/)
      end
    end

    context "when given a Hash" do
      it "builds a TutorState from the hash" do
        hash = {
          "current_phase"        => "chat",
          "current_question_id"  => 42,
          "concepts_mastered"    => [ "énergie" ],
          "concepts_to_revise"   => [],
          "discouragement_level" => 1,
          "question_states"      => {}
        }
        result = type.cast(hash)
        expect(result).to be_a(TutorState)
        expect(result.current_phase).to eq("chat")
        expect(result.current_question_id).to eq(42)
        expect(result.concepts_mastered).to eq([ "énergie" ])
        expect(result.discouragement_level).to eq(1)
      end

      it "builds nested QuestionState objects from question_states hash" do
        hash = {
          "current_phase"        => "chat",
          "current_question_id"  => 1,
          "concepts_mastered"    => [],
          "concepts_to_revise"   => [],
          "discouragement_level" => 0,
          "question_states"      => {
            "1" => {
              "step" => 2, "hints_used" => 1,
              "last_confidence" => 3, "error_types" => [], "completed_at" => nil
            }
          }
        }
        result = type.cast(hash)
        qs = result.question_states["1"]
        expect(qs).to be_a(QuestionState)
        expect(qs.step).to eq(2)
        expect(qs.hints_used).to eq(1)
      end
    end
  end

  describe "#serialize" do
    it "converts TutorState to a JSON string" do
      state = TutorState.default
      result = type.serialize(state)
      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed["current_phase"]).to eq("idle")
      expect(parsed["question_states"]).to eq({})
    end

    it "converts nested QuestionState to a hash inside the JSON payload" do
      qs = QuestionState.new(
        step: 1, hints_used: 0, last_confidence: nil,
        error_types: [], completed_at: nil, intro_seen: false)
      state = TutorState.new(
        current_phase: "chat", current_question_id: 5,
        concepts_mastered: [], concepts_to_revise: [],
        discouragement_level: 0,
        question_states: { "5" => qs }, welcome_sent: false)
      parsed = JSON.parse(type.serialize(state))
      expect(parsed["question_states"]["5"]).to be_a(Hash)
      expect(parsed["question_states"]["5"]["step"]).to eq(1)
    end
  end

  describe "#deserialize" do
    it "parses a JSON string and casts to TutorState" do
      json = type.serialize(TutorState.default)
      result = type.deserialize(json)
      expect(result).to be_a(TutorState)
      expect(result.current_phase).to eq("idle")
    end

    it "raises ArgumentError when the parsed JSON is not a Hash" do
      expect { type.deserialize("42") }.to raise_error(ArgumentError, /Cannot cast Integer/)
    end

    it "raises JSON::ParserError on malformed JSON" do
      expect { type.deserialize("{not valid json") }.to raise_error(JSON::ParserError)
    end
  end

  describe "round-trip" do
    it "deserialize(serialize(state)) equals the original state for a populated state" do
      qs = QuestionState.new(
        step: 3, hints_used: 2, last_confidence: 4,
        error_types: [ "calcul", "unit" ], completed_at: "2026-04-13T10:00:00Z", intro_seen: false)
      original = TutorState.new(
        current_phase:        "chat",
        current_question_id:  7,
        concepts_mastered:    [ "énergie primaire" ],
        concepts_to_revise:   [ "rendement" ],
        discouragement_level: 2,
        question_states:      { "7" => qs }, welcome_sent: false)
      round_tripped = type.deserialize(type.serialize(original))
      expect(round_tripped).to eq(original)
    end
  end
end

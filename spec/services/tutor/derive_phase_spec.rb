require "rails_helper"

RSpec.describe Tutor::DerivePhase do
  # Force TutorState to load, which defines QuestionTrace at the top level
  before(:all) { _ = TutorState }

  let(:answer_type) { "calcul" }

  def trace_with(events)
    QuestionTrace.new(question_id: 1, events: events.freeze)
  end

  it "returns :fresh on empty trace" do
    expect(described_class.call(trace: trace_with([]), answer_type: answer_type)).to eq(:fresh)
  end

  it "returns :armed after viewed_data_hints" do
    events = [ { "type" => "viewed_data_hints", "source" => "page_click", "at" => "2026-05-06T10:00:00Z" } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:armed)
  end

  it "returns :armed after tutor_gave formule" do
    events = [ { "type" => "tutor_gave", "what" => "formule", "source" => "classifier", "at" => "2026-05-06T10:00:00Z" } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:armed)
  end

  it "returns :debug after a single incorrect student_attempt" do
    events = [ {
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "5673",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:debug)
  end

  it "returns :done after a correct student_attempt" do
    events = [ {
      "type" => "student_attempt", "verdict" => "correct", "content" => "56,73",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:done)
  end

  it "returns :done after viewed_correction" do
    events = [ { "type" => "viewed_correction", "source" => "page_click", "at" => "2026-05-06T10:00:00Z" } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:done)
  end

  it "returns :close when nearly there (calcul: incorrect within 5% of nothing — fallback :debug)" do
    # close requires last attempt content within 5% of expected; without expected
    # value, we treat as :debug (safe fallback). Actual close detection is
    # opt-in via expected_value parameter (covered in Step 3).
    events = [ {
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "57",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    } ]
    expect(described_class.call(trace: trace_with(events), answer_type: answer_type)).to eq(:debug)
  end

  it "returns :close when last attempt within 5% of expected_value" do
    events = [ {
      "type" => "student_attempt", "verdict" => "incorrect", "content" => "57",
      "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
    } ]
    expect(described_class.call(
      trace:          trace_with(events),
      answer_type:    answer_type,
      expected_value: 56.73
    )).to eq(:close)
  end

  describe "answer_type variations" do
    it "for qcm: skips :close (no continuous proximity)" do
      events = [ {
        "type" => "student_attempt", "verdict" => "incorrect", "content" => "B",
        "source" => "llm_message", "at" => "2026-05-06T10:00:00Z"
      } ]
      expect(described_class.call(
        trace:          trace_with(events),
        answer_type:    "qcm",
        expected_value: "C"
      )).to eq(:debug)
    end
  end
end

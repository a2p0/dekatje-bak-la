require "rails_helper"

RSpec.describe Tutor::Classify do
  describe ".call" do
    let(:tutor_message) { "Bien, tu tiens la formule. Repère la consommation au 100km dans DT1." }
    let(:answer_type)   { "calcul" }

    before do
      stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => "test-key"))
    end

    context "when the LLM returns valid JSON" do
      it "returns the parsed annotation" do
        stub_anthropic_response(<<~JSON)
          {
            "gives_formula": true,
            "gives_value": false,
            "gives_calculation": false,
            "gives_result": false,
            "validates_attempt": false,
            "marks_done": false,
            "concepts": ["consommation totale"]
          }
        JSON

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]["gives_formula"]).to be(true)
        expect(result.value[:annotation]["concepts"]).to eq([ "consommation totale" ])
      end
    end

    context "when JSON is malformed" do
      it "returns a neutral annotation without raising" do
        stub_anthropic_response("not json at all")

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)  # neutral, never blocking
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
        expect(result.value[:warning]).to match(/malformed/i)
      end
    end

    context "when the call times out" do
      it "returns a neutral annotation" do
        allow_any_instance_of(described_class).to receive(:call_anthropic)
          .and_raise(Net::ReadTimeout.new("timeout"))

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
      end
    end

    context "when ANTHROPIC_API_KEY is missing" do
      before { stub_const("ENV", ENV.to_hash.merge("ANTHROPIC_API_KEY" => nil)) }

      it "returns a neutral annotation and logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/missing.*ANTHROPIC_API_KEY/i)

        result = described_class.call(tutor_message: tutor_message, answer_type: answer_type)

        expect(result.ok?).to be(true)
        expect(result.value[:annotation]).to eq(Tutor::Classify::NEUTRAL_ANNOTATION)
      end
    end
  end

  def stub_anthropic_response(content)
    fake = double("anthropic_chat",
      ask: double("response", content: content,
                  input_tokens: 100, output_tokens: 50))
    allow_any_instance_of(described_class).to receive(:build_anthropic_client).and_return(fake)
  end
end

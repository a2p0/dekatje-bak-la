require "rails_helper"

RSpec.describe TutorSimulation::StudentSimulator do
  let(:client) { instance_double(AiClientFactory, call: "Je ne comprends pas cette question.") }

  describe "profiles" do
    TutorSimulation::StudentSimulator::PROFILES.each_key do |profile|
      it "initializes with profile #{profile}" do
        simulator = described_class.new(profile: profile, client: client)
        expect(simulator.profile_label).to be_present
      end
    end

    it "raises on unknown profile" do
      expect { described_class.new(profile: :inexistant, client: client) }.to raise_error(ArgumentError, /Unknown profile/)
    end
  end

  describe "#respond" do
    it "calls the AI client and returns a response" do
      simulator = described_class.new(profile: :eleve_moyen, client: client)

      response = simulator.respond(
        question_label: "Calculer la consommation en litres",
        conversation_history: [],
        turn: 1
      )

      expect(response).to eq("Je ne comprends pas cette question.")
      expect(client).to have_received(:call).once
    end

    it "swaps roles in conversation history for the student LLM perspective" do
      simulator = described_class.new(profile: :bon_eleve, client: client)

      history = [
        { "role" => "user", "content" => "Je pense que c'est 56 litres" },
        { "role" => "assistant", "content" => "Bonne piste ! Comment as-tu trouvé ?" }
      ]

      simulator.respond(question_label: "Calculer la consommation", conversation_history: history, turn: 2)

      call_args = client.as_null_object
      expect(client).to have_received(:call) do |args|
        messages = args[:messages]
        expect(messages.first[:role]).to eq("assistant")
        expect(messages.last[:role]).to eq("user")
      end
    end
  end
end

require "rails_helper"

RSpec.describe ResolveApiKey do
  describe ".call" do
    context "when user has an encrypted api_key" do
      it "returns user api_key and provider" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return("user-sk-test")
        allow(user).to receive(:api_provider).and_return("openrouter")

        result = described_class.call(user: user)

        expect(result[:api_key]).to eq("user-sk-test")
        expect(result[:provider]).to eq(:openrouter)
      end
    end

    context "when user has no api_key" do
      it "falls back to OPENROUTER_API_KEY first with openrouter provider" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return(nil)

        stub_const("ENV", ENV.to_hash.merge("OPENROUTER_API_KEY" => "or-sk-test", "ANTHROPIC_API_KEY" => "ant-sk-test"))

        result = described_class.call(user: user)

        expect(result[:api_key]).to eq("or-sk-test")
        expect(result[:provider]).to eq(:openrouter)
      end

      it "falls back to ANTHROPIC_API_KEY when no OPENROUTER_API_KEY" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return(nil)

        stub_const("ENV", ENV.to_hash.merge("OPENROUTER_API_KEY" => nil, "ANTHROPIC_API_KEY" => "server-sk-test"))

        result = described_class.call(user: user)

        expect(result[:api_key]).to eq("server-sk-test")
        expect(result[:provider]).to eq(:anthropic)
      end

      it "raises if no api_key available at all" do
        user = create(:user, confirmed_at: Time.current)
        allow(user).to receive(:api_key).and_return(nil)

        stub_const("ENV", ENV.to_hash.merge("OPENROUTER_API_KEY" => nil, "ANTHROPIC_API_KEY" => nil))

        expect {
          described_class.call(user: user)
        }.to raise_error(ResolveApiKey::NoApiKeyError)
      end
    end
  end
end

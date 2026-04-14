module FakeRubyLlm
  # Stubs RubyLLM::Chat to return a predictable streaming response.
  #
  # Usage in a spec:
  #   before { FakeRubyLlm.setup_stub(content: "Réponse.", tool_calls: []) }
  #
  def self.setup_stub(content: "Réponse de test.", tool_calls: [])
    chunk = Struct.new(:content, :tool_calls, :input_tokens, :output_tokens) do
      def done? = true
    end.new(content, tool_calls, 10, 20)

    RSpec::Mocks.space
                .any_instance_recorder_for(RubyLLM::Chat)
                .stub(:ask) do |*_args, &block|
      block&.call(chunk)
      chunk
    end

    RSpec::Mocks.space
                .any_instance_recorder_for(RubyLLM::Chat)
                .stub(:with_instructions) { |*_args| nil }
  end
end

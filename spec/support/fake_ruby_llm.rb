module FakeRubyLlm
  # Stubs RubyLLM::Chat to return a predictable streaming response.
  #
  # Usage:
  #   FakeRubyLlm.setup_stub(content: "Réponse.", tool_calls: [])
  #
  def self.setup_stub(content: "Réponse de test.", tool_calls: [])
    chunk = instance_double(
      "RubyLLM::Chunk",
      content:     content,
      tool_calls:  tool_calls,
      done?:       true,
      input_tokens:  10,
      output_tokens: 20
    )
    allow_any_instance_of(RubyLLM::Chat).to receive(:ask) do |_chat, _messages, &block|
      block&.call(chunk)
      chunk
    end
  end
end

module FakeRubyLlm
  ChunkStruct = Struct.new(:content, :tool_calls, :input_tokens, :output_tokens) do
    def done? = true
  end

  # Stubs RubyLLM::Chat to yield either a single chunk or a sequence of chunks.
  #
  # Single-chunk (default shape used by most tutor specs):
  #   FakeRubyLlm.setup_stub(content: "Réponse.", tool_calls: [])
  #
  # Multi-chunk (for specs that exercise chunk-level streaming):
  #   FakeRubyLlm.setup_stub(chunks: [ "Bon", "jour ", "élève" ])
  #
  # Raise inside the #ask block (for error-path specs):
  #   FakeRubyLlm.setup_stub(raise_error: RuntimeError.new("401"))
  def self.setup_stub(content: "Réponse de test.", tool_calls: [], chunks: nil, raise_error: nil)
    RSpec::Mocks.space
                .any_instance_recorder_for(RubyLLM::Chat)
                .stub(:with_instructions) { |*_args| nil }

    RSpec::Mocks.space
                .any_instance_recorder_for(RubyLLM::Chat)
                .stub(:with_tool) { |*_args| nil }

    RSpec::Mocks.space
                .any_instance_recorder_for(RubyLLM::Chat)
                .stub(:with_tools) { |*_args, **_kwargs| nil }

    if raise_error
      RSpec::Mocks.space
                  .any_instance_recorder_for(RubyLLM::Chat)
                  .stub(:ask) { |*_args, &_block| raise raise_error }
      return
    end

    if chunks
      chunk_objects = chunks.map { |c| ChunkStruct.new(c, [], 0, 0) }
      tool_chunk    = ChunkStruct.new("", tool_calls, 0, 0) if tool_calls.present?
      final_chunk   = ChunkStruct.new(chunks.join, tool_calls, 10, 20)

      RSpec::Mocks.space
                  .any_instance_recorder_for(RubyLLM::Chat)
                  .stub(:ask) do |*_args, &block|
        chunk_objects.each { |ch| block&.call(ch) }
        block&.call(tool_chunk) if tool_chunk
        final_chunk
      end
    else
      chunk = ChunkStruct.new(content, tool_calls, 10, 20)
      RSpec::Mocks.space
                  .any_instance_recorder_for(RubyLLM::Chat)
                  .stub(:ask) do |*_args, &block|
        block&.call(chunk)
        chunk
      end
    end
  end
end

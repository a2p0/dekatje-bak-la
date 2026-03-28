class ExtractQuestionsFromPdf
  class ParseError < StandardError; end

  def self.call(subject:, api_key:, provider:)
    text = extract_text_from_pdf(subject.enonce_file)
    prompt = BuildExtractionPrompt.call(text: text)
    client = AiClientFactory.build(provider: provider, api_key: api_key)
    raw_response = client.call(
      messages: prompt[:messages],
      system: prompt[:system],
      max_tokens: 8192,
      temperature: 0.1
    )
    parse_json_response(raw_response)
  end

  def self.extract_text_from_pdf(attachment)
    attachment.blob.open do |file|
      reader = PDF::Reader.new(file)
      reader.pages.map(&:text).join("\n")
    end
  end
  private_class_method :extract_text_from_pdf

  def self.parse_json_response(raw)
    json_match = raw.to_s.match(/\{.*\}/m)
    raise ParseError, "Réponse IA invalide : JSON introuvable" unless json_match

    JSON.parse(json_match[0])
  rescue JSON::ParserError => e
    raise ParseError, "Impossible de parser le JSON : #{e.message}"
  end
  private_class_method :parse_json_response
end

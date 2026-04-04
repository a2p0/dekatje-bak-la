class ExtractQuestionsFromPdf
  class ParseError < StandardError; end

  def self.call(subject:, api_key:, provider:, skip_common: false)
    subject_text = extract_text_from_pdf(subject.subject_pdf)
    correction_text = extract_text_from_pdf(subject.correction_pdf)

    prompt = BuildExtractionPrompt.call(
      subject_text: subject_text,
      correction_text: correction_text,
      specialty: subject.specialty,
      skip_common: skip_common
    )

    client = AiClientFactory.build(provider: provider, api_key: api_key)
    raw_response = client.call(
      messages: prompt[:messages],
      system: prompt[:system],
      max_tokens: 16_384,
      temperature: 0.1
    )

    [ raw_response, parse_json_response(raw_response) ]
  end

  def self.extract_text_from_pdf(attachment)
    attachment.blob.open do |file|
      reader = PDF::Reader.new(file)
      reader.pages.each_with_index.map do |page, index|
        "--- Page #{index + 1} ---\n#{page.text}"
      end.join("\n")
    end
  end
  private_class_method :extract_text_from_pdf

  def self.parse_json_response(raw)
    json_match = raw.to_s.match(/\{.*\}/m)
    raise ParseError, "Réponse IA invalide : JSON introuvable" unless json_match

    cleaned = sanitize_json(json_match[0])
    JSON.parse(cleaned)
  rescue JSON::ParserError => e
    raise ParseError, "Impossible de parser le JSON : #{e.message}"
  end

  def self.sanitize_json(json_str)
    # Remove trailing commas before ] or } (common LLM mistake)
    json_str.gsub(/,(\s*[\]\}])/, '\1')
  end
  private_class_method :parse_json_response
end

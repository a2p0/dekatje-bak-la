# app/services/extract_student_insights.rb
class ExtractStudentInsights
  EXTRACTION_PROMPT = <<~PROMPT
    Analyse cette conversation entre un tuteur et un eleve de Terminale.
    Identifie les concepts maitrises, les difficultes et les erreurs de comprehension.

    Reponds UNIQUEMENT avec un tableau JSON valide, sans texte supplementaire.
    Chaque element doit avoir exactement ces cles :
    - "type": un parmi "mastered", "struggle", "misconception", "note"
    - "concept": le nom court du concept (ex: "energie primaire", "rendement")
    - "text": une phrase explicative courte

    Exemple :
    [
      {"type": "mastered", "concept": "energie primaire", "text": "L'eleve comprend la distinction entre energie primaire et finale."},
      {"type": "struggle", "concept": "rendement", "text": "L'eleve confond rendement et puissance."}
    ]

    Si aucun insight n'est identifiable, reponds avec un tableau vide : []
  PROMPT

  def self.call(conversation:)
    new(conversation: conversation).call
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return [] if @conversation.messages.size < 4

    raw_json = call_ai
    insights = parse_insights(raw_json)
    persist_insights(insights)
    insights
  end

  private

  def call_ai
    client = resolve_client
    messages_text = @conversation.messages.map { |m| "#{m['role']}: #{m['content']}" }.join("\n\n")

    client.call(
      messages: [{ role: "user", content: messages_text }],
      system: EXTRACTION_PROMPT,
      max_tokens: 1024,
      temperature: 0.1
    )
  end

  def resolve_client
    student = @conversation.student

    if student.api_key.present?
      AiClientFactory.build(
        provider: student.api_provider,
        api_key: student.api_key,
        model: student.effective_model
      )
    elsif ENV["ANTHROPIC_API_KEY"].present?
      AiClientFactory.build(
        provider: :anthropic,
        api_key: ENV["ANTHROPIC_API_KEY"],
        model: "claude-haiku-4-5-20251001"
      )
    else
      raise "No API key available for insight extraction"
    end
  end

  def parse_insights(raw_json)
    cleaned = raw_json.to_s.strip
    cleaned = cleaned[/\[.*\]/m] || "[]"
    JSON.parse(cleaned)
  rescue JSON::ParserError
    Rails.logger.warn("[ExtractStudentInsights] Failed to parse JSON: #{raw_json}")
    []
  end

  def persist_insights(insights)
    subject = @conversation.question.part.subject

    insights.each do |insight|
      next unless StudentInsight::INSIGHT_TYPES.include?(insight["type"])
      next if insight["concept"].blank?

      StudentInsight.create!(
        student: @conversation.student,
        subject: subject,
        question: @conversation.question,
        insight_type: insight["type"],
        concept: insight["concept"],
        text: insight["text"]
      )
    end
  end
end

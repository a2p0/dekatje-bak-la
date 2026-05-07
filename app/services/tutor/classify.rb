require "net/http"

module Tutor
  # Inline post-response classifier (haiku 4.5 on the server-side
  # ANTHROPIC_API_KEY). Reads the tutor message and returns a JSON
  # annotation of what the tutor just did.
  #
  # Robustness: malformed JSON, timeout, rate limit, missing key → neutral
  # annotation, no retry. The next turn's budget will self-correct via the
  # explicit counters in the prompt.
  class Classify
    MODEL               = "claude-haiku-4-5-20251001".freeze
    DEFAULT_TEMPERATURE = 0
    DEFAULT_MAX_TOKENS  = 200
    PROMPT_FILE         = Rails.root.join("config", "prompts", "tutor_classifier.txt").freeze

    NEUTRAL_ANNOTATION = {
      "gives_formula"     => false,
      "gives_value"       => false,
      "gives_calculation" => false,
      "gives_result"      => false,
      "validates_attempt" => false,
      "marks_done"        => false,
      "concepts"          => []
    }.freeze

    def self.call(tutor_message:, answer_type:)
      new(tutor_message: tutor_message, answer_type: answer_type).call
    end

    def initialize(tutor_message:, answer_type:)
      @tutor_message = tutor_message.to_s
      @answer_type   = answer_type.to_s
    end

    def call
      api_key = ENV["ANTHROPIC_API_KEY"]
      if api_key.blank?
        Rails.logger.warn("[Tutor::Classify] missing ANTHROPIC_API_KEY, using neutral annotation")
        return Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "missing key")
      end

      raw = call_anthropic(api_key)
      parsed = parse_json(raw)

      if parsed.nil?
        Rails.logger.warn("[Tutor::Classify] malformed JSON, using neutral annotation. raw=#{raw.inspect}")
        return Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "malformed JSON")
      end

      Result.ok(annotation: NEUTRAL_ANNOTATION.merge(parsed.slice(*NEUTRAL_ANNOTATION.keys)))
    rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
      Rails.logger.warn("[Tutor::Classify] timeout: #{e.message}")
      Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "timeout")
    rescue => e
      Rails.logger.warn("[Tutor::Classify] error: #{e.class.name}: #{e.message}")
      Result.ok(annotation: NEUTRAL_ANNOTATION, warning: "error")
    end

    private

    def call_anthropic(api_key)
      client = build_anthropic_client(api_key)
      prompt = build_prompt
      resp   = client.ask(prompt)
      resp.respond_to?(:content) ? resp.content.to_s : resp.to_s
    end

    def build_anthropic_client(api_key = ENV["ANTHROPIC_API_KEY"])
      RubyLLM.configure { |c| c.anthropic_api_key = api_key }
      chat = RubyLLM::Chat.new(model: MODEL)
      chat.with_params(temperature: DEFAULT_TEMPERATURE, max_tokens: DEFAULT_MAX_TOKENS)
      chat
    end

    def build_prompt
      <<~PROMPT
        Tu reçois le message d'un tuteur à un élève préparant le BAC STI2D, sur une question de type #{@answer_type}.
        Identifie ce que le tuteur vient de faire dans ce message.

        Réponds en JSON strict avec ces booléens :
        - gives_formula     : le tuteur énonce une formule, méthode, ou structure de réponse ?
        - gives_value       : le tuteur révèle une valeur précise du sujet (chiffre, donnée DT) ?
        - gives_calculation : le tuteur détaille un calcul étape par étape (avec chiffres) ?
        - gives_result      : le tuteur révèle le résultat final attendu de la question ?
        - validates_attempt : le tuteur confirme/rejette explicitement une tentative de l'élève ?
        - marks_done        : le tuteur indique que la question est résolue / passe à autre chose ?

        Et un array :
        - concepts : liste des concepts disciplinaires mentionnés (ex. ["conductivité thermique"])

        Réponds uniquement le JSON, rien d'autre.

        Message tuteur : """#{@tutor_message}"""
      PROMPT
    end

    def parse_json(raw)
      stripped = raw.to_s.strip
      stripped = stripped.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
      JSON.parse(stripped)
    rescue JSON::ParserError
      nil
    end
  end
end

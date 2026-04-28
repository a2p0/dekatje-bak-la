# Utilitaires partagés entre les juges extraction.
# Charge via : require_relative "shared"

$stdout.sync = true
require "json"

JUDGE_MODEL     = "openai/gpt-5.5"
JUDGE_PRICE_IN  = 5.0   # $/M tokens
JUDGE_PRICE_OUT = 30.0  # $/M tokens

CRITERIA = %w[completude verbatim data_hints structure pedagogique].freeze

def call_openrouter(system_prompt, user_content, api_key, max_tokens: 1024)
  conn = Faraday.new(url: "https://openrouter.ai") do |f|
    f.request :json
    f.response :json
    f.options.timeout = 120
  end
  body = {
    model:       JUDGE_MODEL,
    messages:    [
      { role: "system", content: system_prompt },
      { role: "user",   content: user_content }
    ],
    max_tokens:  max_tokens,
    temperature: 0.0
  }
  headers = {
    "Authorization" => "Bearer #{api_key}",
    "Content-Type"  => "application/json"
  }
  t0 = Time.now
  response = conn.post("/api/v1/chat/completions", body, headers)
  elapsed = (Time.now - t0).round(1)
  raise "OpenRouter error #{response.status}: #{response.body}" unless response.success?

  usage      = response.body["usage"] || {}
  tokens_in  = usage["prompt_tokens"].to_i
  tokens_out = usage["completion_tokens"].to_i
  cost       = (tokens_in * JUDGE_PRICE_IN + tokens_out * JUDGE_PRICE_OUT) / 1_000_000.0
  text       = response.body.dig("choices", 0, "message", "content").to_s.strip

  { text: text, tokens_in: tokens_in, tokens_out: tokens_out, cost: cost, elapsed: elapsed }
end

def parse_json_response(text)
  clean = text.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
  JSON.parse(clean)
rescue JSON::ParseError
  nil
end

def clean_json(raw)
  raw.strip.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "")
end

def extract_all_questions(parsed_json)
  questions = []
  (parsed_json["common_parts"] || []).each do |part|
    (part["questions"] || []).each do |q|
      questions << q.merge("_part_type" => "common", "_part_number" => part["number"])
    end
  end
  (parsed_json["specific_parts"] || []).each do |part|
    (part["questions"] || []).each do |q|
      questions << q.merge("_part_type" => "specific", "_part_number" => part["number"])
    end
  end
  questions
end

def load_extractions(subject_dir)
  opus_path    = subject_dir.join("opus.json")
  mistral_path = subject_dir.join("mistral.json")
  abort "opus.json introuvable dans #{subject_dir}"    unless opus_path.exist?
  abort "mistral.json introuvable dans #{subject_dir}" unless mistral_path.exist?

  opus_parsed    = JSON.parse(clean_json(File.read(opus_path)))    rescue abort("opus.json invalide : #{$!.message}")
  mistral_parsed = JSON.parse(clean_json(File.read(mistral_path))) rescue abort("mistral.json invalide : #{$!.message}")

  opus_questions    = extract_all_questions(opus_parsed)
  mistral_questions = extract_all_questions(mistral_parsed)

  puts "Opus    : #{opus_questions.size} questions"
  puts "Mistral : #{mistral_questions.size} questions"

  opus_by_number    = opus_questions.index_by    { |q| q["number"] }
  mistral_by_number = mistral_questions.index_by { |q| q["number"] }

  common_numbers = (opus_by_number.keys & mistral_by_number.keys).sort
  only_opus      = opus_by_number.keys    - mistral_by_number.keys
  only_mistral   = mistral_by_number.keys - opus_by_number.keys

  puts "\nQuestions communes : #{common_numbers.size}"
  puts "Seulement dans Opus    : #{only_opus.join(", ")}"    if only_opus.any?
  puts "Seulement dans Mistral : #{only_mistral.join(", ")}" if only_mistral.any?

  {
    opus_by_number:    opus_by_number,
    mistral_by_number: mistral_by_number,
    common_numbers:    common_numbers,
    only_opus:         only_opus,
    only_mistral:      only_mistral
  }
end

def build_question_prompt(question_number, extraction_a, extraction_b)
  <<~MSG
    ## Question #{question_number}

    ### Extraction A
    ```json
    #{JSON.pretty_generate(extraction_a)}
    ```

    ### Extraction B
    ```json
    #{JSON.pretty_generate(extraction_b)}
    ```
  MSG
end

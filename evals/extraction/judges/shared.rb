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
rescue JSON::ParserError
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

# model_a et model_b : noms de fichiers sans extension (ex: "opus", "mistral_ocr_opus")
def load_extractions(subject_dir, model_a: "opus", model_b: "mistral")
  path_a = subject_dir.join("#{model_a}.json")
  path_b = subject_dir.join("#{model_b}.json")
  abort "#{model_a}.json introuvable dans #{subject_dir}" unless path_a.exist?
  abort "#{model_b}.json introuvable dans #{subject_dir}" unless path_b.exist?

  parsed_a = JSON.parse(clean_json(File.read(path_a))) rescue abort("#{model_a}.json invalide : #{$!.message}")
  parsed_b = JSON.parse(clean_json(File.read(path_b))) rescue abort("#{model_b}.json invalide : #{$!.message}")

  questions_a = extract_all_questions(parsed_a)
  questions_b = extract_all_questions(parsed_b)

  puts "#{model_a} : #{questions_a.size} questions"
  puts "#{model_b} : #{questions_b.size} questions"

  by_number_a = questions_a.index_by { |q| q["number"] }
  by_number_b = questions_b.index_by { |q| q["number"] }

  common_numbers = (by_number_a.keys & by_number_b.keys).sort
  only_a         = by_number_a.keys - by_number_b.keys
  only_b         = by_number_b.keys - by_number_a.keys

  puts "\nQuestions communes : #{common_numbers.size}"
  puts "Seulement dans #{model_a} : #{only_a.join(", ")}" if only_a.any?
  puts "Seulement dans #{model_b} : #{only_b.join(", ")}" if only_b.any?

  {
    opus_by_number:    by_number_a,
    mistral_by_number: by_number_b,
    common_numbers:    common_numbers,
    only_opus:         only_a,
    only_mistral:      only_b,
    model_a:           model_a,
    model_b:           model_b
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

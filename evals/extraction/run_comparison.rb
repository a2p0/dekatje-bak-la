# Usage: bin/rails runner evals/extraction/run_comparison.rb <subject_id> [subject_id2 ...]
#
# Required env vars:
#   ANTHROPIC_API_KEY  — Claude Opus 4.7 (Anthropic direct)
#   MISTRAL_API_KEY    — Mistral OCR + Mistral Large 2512 (Mistral direct)
#
# Pipelines :
#   opus             : pdf-reader -> texte brut -> Claude Opus 4.7
#   mistral          : Mistral OCR -> Markdown  -> Mistral Large 2512
#   mistral_ocr_opus : Mistral OCR -> Markdown  -> Claude Opus 4.7
#
# Arreter Sidekiq avant : docker stop <sidekiq-container>
# Output  : tmp/llm_comparison/extraction/results/<subject_id>/

$stdout.sync = true
require "csv"

OUTPUT_DIR = Rails.root.join("tmp/llm_comparison/extraction/results")
FileUtils.mkdir_p(OUTPUT_DIR)

MODELS = {
  opus: {
    label:    "Claude Opus 4.7 (pdf-reader)",
    provider: :anthropic_pdftext,
    model_id: "claude-opus-4-7"
  },
  mistral: {
    label:    "Mistral Large 2512 (OCR natif)",
    provider: :mistral_ocr,
    model_id: "mistral-large-2512"
  },
  mistral_ocr_opus: {
    label:    "Claude Opus 4.7 (Mistral OCR)",
    provider: :anthropic_ocr,
    model_id: "claude-opus-4-7"
  }
}.freeze

# ---------- Anthropic ----------

def call_anthropic(system_prompt, user_content, api_key, model_id)
  conn = Faraday.new(url: "https://api.anthropic.com") do |f|
    f.request :json
    f.response :json
    f.options.timeout = 600
  end
  body = {
    model: model_id,
    system: system_prompt,
    messages: [{ role: "user", content: user_content }],
    max_tokens: 32_768
    # temperature omis : deprecated sur Opus 4.7+
  }
  headers = {
    "x-api-key" => api_key,
    "anthropic-version" => "2023-06-01",
    "Content-Type" => "application/json"
  }
  t0 = Time.now
  response = conn.post("/v1/messages", body, headers)
  elapsed = (Time.now - t0).round(1)
  raise "Anthropic error #{response.status}: #{response.body}" unless response.success?

  usage = response.body["usage"] || {}
  tokens_in  = usage["input_tokens"].to_i
  tokens_out = usage["output_tokens"].to_i
  # Opus 4.7 : $15/M input, $75/M output
  cost = (tokens_in * 15.0 + tokens_out * 75.0) / 1_000_000.0

  {
    text:       response.body.dig("content", 0, "text"),
    tokens_in:  tokens_in,
    tokens_out: tokens_out,
    cost:       cost,
    elapsed:    elapsed
  }
end

# ---------- Mistral OCR ----------

def mistral_upload_file(blob, api_key)
  blob.open do |file|
    conn = Faraday.new(url: "https://api.mistral.ai") do |f|
      f.request :multipart
      f.response :json
      f.options.timeout = 120
    end
    payload = {
      purpose: "ocr",
      file: Faraday::FilePart.new(file, blob.content_type, blob.filename.to_s)
    }
    headers = { "Authorization" => "Bearer #{api_key}" }
    response = conn.post("/v1/files", payload, headers)
    raise "Mistral upload error #{response.status}: #{response.body}" unless response.success?
    response.body["id"]
  end
end

def mistral_delete_file(file_id, api_key)
  conn = Faraday.new(url: "https://api.mistral.ai") do |f|
    f.response :json
    f.options.timeout = 30
  end
  conn.delete("/v1/files/#{file_id}", nil, { "Authorization" => "Bearer #{api_key}" })
rescue => e
  # non-fatal
  puts "    [warn] delete file #{file_id}: #{e.message}"
end

def mistral_ocr(file_id, api_key)
  conn = Faraday.new(url: "https://api.mistral.ai") do |f|
    f.request :json
    f.response :json
    f.options.timeout = 300
  end
  body = {
    model: "mistral-ocr-latest",
    document: { type: "file", file_id: file_id },
    table_format: "markdown"
  }
  headers = {
    "Authorization" => "Bearer #{api_key}",
    "Content-Type"  => "application/json"
  }
  t0 = Time.now
  response = conn.post("/v1/ocr", body, headers)
  elapsed = (Time.now - t0).round(1)
  raise "Mistral OCR error #{response.status}: #{response.body}" unless response.success?

  pages_processed = response.body.dig("usage_info", "pages_processed").to_i
  markdown = response.body["pages"].map { |p| p["markdown"] }.join("\n\n")
  # $1/1000 pages
  cost = pages_processed / 1000.0

  { markdown: markdown, pages: pages_processed, cost: cost, elapsed: elapsed }
end

# ---------- Mistral Chat ----------

def call_mistral_chat(system_prompt, user_content, api_key, model_id)
  conn = Faraday.new(url: "https://api.mistral.ai") do |f|
    f.request :json
    f.response :json
    f.options.timeout = 600
  end
  body = {
    model: model_id,
    messages: [
      { role: "system", content: system_prompt },
      { role: "user",   content: user_content }
    ],
    max_tokens: 32_768,
    temperature: 0.1
  }
  headers = {
    "Authorization" => "Bearer #{api_key}",
    "Content-Type"  => "application/json"
  }
  t0 = Time.now
  response = conn.post("/v1/chat/completions", body, headers)
  elapsed = (Time.now - t0).round(1)
  raise "Mistral chat error #{response.status}: #{response.body}" unless response.success?

  usage = response.body["usage"] || {}
  tokens_in  = usage["prompt_tokens"].to_i
  tokens_out = usage["completion_tokens"].to_i
  # Mistral Large 2512 : $0.50/M input, $1.50/M output
  cost = (tokens_in * 0.50 + tokens_out * 1.50) / 1_000_000.0

  {
    text:       response.body.dig("choices", 0, "message", "content"),
    tokens_in:  tokens_in,
    tokens_out: tokens_out,
    cost:       cost,
    elapsed:    elapsed
  }
end

# ---------- extraction texte pdf-reader (pour Opus) ----------

def extract_text_from_blob(blob)
  blob.open do |file|
    reader = PDF::Reader.new(file)
    reader.pages.each_with_index.map { |page, i|
      "--- Page #{i + 1} ---\n#{page.text}"
    }.join("\n")
  end
end

# ---------- main ----------

subject_ids = ARGV.map(&:to_i).select(&:positive?)
if subject_ids.empty?
  puts "Usage: bin/rails runner tmp/extraction_comparison/run_comparison.rb <subject_id> [...]"
  exit 1
end

anthropic_key = ENV["ANTHROPIC_API_KEY"].presence || abort("ANTHROPIC_API_KEY manquant")
mistral_key   = ENV["MISTRAL_API_KEY"].presence   || abort("MISTRAL_API_KEY manquant")

report_rows = []

subject_ids.each do |subject_id|
  puts "\n#{"=" * 60}"
  puts "Sujet ##{subject_id}"
  puts "=" * 60

  subject = Subject.find_by(id: subject_id)
  unless subject
    puts "  ERREUR : sujet ##{subject_id} introuvable"
    next
  end
  unless subject.subject_pdf.attached? && subject.correction_pdf.attached?
    puts "  ERREUR : PDFs non attaches"
    next
  end

  subject_dir = OUTPUT_DIR.join(subject_id.to_s)
  FileUtils.mkdir_p(subject_dir)

  # --- Opus : texte via pdf-reader ---
  puts "  [Opus] Extraction texte via pdf-reader..."
  subject_text    = extract_text_from_blob(subject.subject_pdf.blob)
  correction_text = extract_text_from_blob(subject.correction_pdf.blob)

  prompt = BuildExtractionPrompt.call(
    subject_text:    subject_text,
    correction_text: correction_text,
    specialty:       subject.specialty
  )
  system_prompt     = prompt[:system]
  opus_user_content = prompt[:messages].first[:content]

  puts "  Prompt systeme : #{system_prompt.length} cars | texte sujet : #{subject_text.length} cars"

  # --- Mistral : OCR (reutilise les .md existants si presents) ---
  ocr_cost   = 0.0
  ocr_elapsed = 0.0
  mistral_user_content = nil

  ocr_subject_path    = subject_dir.join("mistral_ocr_subject.md")
  ocr_correction_path = subject_dir.join("mistral_ocr_correction.md")

  begin
    if ocr_subject_path.exist? && ocr_correction_path.exist?
      puts "  [Mistral] OCR deja present -> reutilisation des .md (skip upload)"
      ocr_subject_markdown    = File.read(ocr_subject_path)
      ocr_correction_markdown = File.read(ocr_correction_path)
    else
      puts "  [Mistral] Upload sujet PDF vers Files API..."
      subject_file_id = mistral_upload_file(subject.subject_pdf.blob, mistral_key)
      puts "    file_id: #{subject_file_id}"

      puts "  [Mistral] Upload corrige PDF vers Files API..."
      correction_file_id = mistral_upload_file(subject.correction_pdf.blob, mistral_key)
      puts "    file_id: #{correction_file_id}"

      puts "  [Mistral] OCR sujet PDF..."
      ocr_subject = mistral_ocr(subject_file_id, mistral_key)
      mistral_delete_file(subject_file_id, mistral_key)
      puts "    #{ocr_subject[:pages]} pages, #{ocr_subject[:elapsed]}s"

      puts "  [Mistral] OCR corrige PDF..."
      ocr_correction = mistral_ocr(correction_file_id, mistral_key)
      mistral_delete_file(correction_file_id, mistral_key)
      puts "    #{ocr_correction[:pages]} pages, #{ocr_correction[:elapsed]}s"

      ocr_cost    = ocr_subject[:cost] + ocr_correction[:cost]
      ocr_elapsed = ocr_subject[:elapsed] + ocr_correction[:elapsed]

      ocr_subject_markdown    = ocr_subject[:markdown]
      ocr_correction_markdown = ocr_correction[:markdown]

      File.write(ocr_subject_path,    ocr_subject_markdown)
      File.write(ocr_correction_path, ocr_correction_markdown)
      puts "  [Mistral] OCR OK (cout: $#{format("%.4f", ocr_cost)}) -> Markdown sauvegarde"
    end

    # Construit le message utilisateur pour Mistral chat avec le Markdown OCR
    # On n'embarque pas le texte dans le system prompt (deja dans SYSTEM_PROMPT)
    # On remplace juste le contenu utilisateur
    mistral_user_content = <<~MSG
      Specialite inconnue - extrait toutes les parties (communes et specifiques).

      === SUJET DE L'EXAMEN ===
      #{ocr_subject_markdown}

      === CORRIGE OFFICIEL ===
      #{ocr_correction_markdown}

      Analyse le sujet et le corrige ci-dessus.
      Extrait toutes les parties communes et specifiques avec leurs questions, corrections et references aux documents.
    MSG
  rescue => e
    puts "  [Mistral] ERREUR OCR : #{e.message}"
  end

  # --- Appels LLM ---
  MODELS.each do |key, config|
    puts "\n  --- #{config[:label]} ---"
    output_file = subject_dir.join("#{key}.json")

    if output_file.exist? && output_file.size > 10
      puts "    Deja present (#{output_file.size} octets) -> skip"
      report_rows << {
        subject_id:  subject_id,
        model:       config[:label],
        elapsed_s:   "CACHED",
        tokens_in:   0,
        tokens_out:  0,
        cost_usd:    "0",
        output_file: output_file.to_s
      }
      next
    end

    begin
      result = case config[:provider]
               when :anthropic_pdftext
                 call_anthropic(system_prompt, opus_user_content, anthropic_key, config[:model_id])
               when :mistral_ocr
                 raise "OCR a echoue, impossible d'appeler Mistral chat" unless mistral_user_content
                 llm = call_mistral_chat(system_prompt, mistral_user_content, mistral_key, config[:model_id])
                 llm.merge(cost: llm[:cost] + ocr_cost, elapsed: llm[:elapsed] + ocr_elapsed)
               when :anthropic_ocr
                 raise "OCR a echoue, impossible d'appeler Opus via OCR" unless mistral_user_content
                 call_anthropic(system_prompt, mistral_user_content, anthropic_key, config[:model_id])
               end

      File.write(output_file, result[:text])

      puts "    Temps     : #{result[:elapsed]}s"
      puts "    Tokens    : #{result[:tokens_in]} in / #{result[:tokens_out]} out"
      puts "    Cout est. : $#{format("%.4f", result[:cost])}"
      puts "    Fichier   : #{output_file}"

      report_rows << {
        subject_id:  subject_id,
        model:       config[:label],
        elapsed_s:   result[:elapsed],
        tokens_in:   result[:tokens_in],
        tokens_out:  result[:tokens_out],
        cost_usd:    format("%.4f", result[:cost]),
        output_file: output_file.to_s
      }
    rescue => e
      puts "    ERREUR : #{e.class} -- #{e.message}"
      report_rows << {
        subject_id:  subject_id,
        model:       config[:label],
        elapsed_s:   "ERROR",
        tokens_in:   0,
        tokens_out:  0,
        cost_usd:    "0",
        output_file: "ERROR: #{e.message}"
      }
    end
  end
end

# ---------- rapport CSV ----------
csv_path = OUTPUT_DIR.join("rapport_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv")
CSV.open(csv_path, "w") do |csv|
  csv << %w[subject_id model elapsed_s tokens_in tokens_out cost_usd output_file]
  report_rows.each { |r| csv << r.values }
end

puts "\n#{"=" * 60}"
puts "RESUME"
puts "=" * 60
report_rows.each do |r|
  puts "  Sujet ##{r[:subject_id]} | #{r[:model]} | #{r[:elapsed_s]}s | $#{r[:cost_usd]}"
end
total_cost = report_rows.sum { |r| r[:cost_usd].to_f }
puts "  TOTAL cout estime : $#{format("%.4f", total_cost)}"
puts "\nRapport CSV : #{csv_path}"
puts "JSONs       : #{OUTPUT_DIR}/<subject_id>/{opus,mistral,mistral_ocr_opus}.json"
puts "OCR MD      : #{OUTPUT_DIR}/<subject_id>/mistral_ocr_{subject,correction}.md"
puts "\nPour lancer le juge :"
puts "  bin/rails runner evals/extraction/judge.rb <subject_id> --mode pairwise"
puts "  bin/rails runner evals/extraction/judge.rb <subject_id> --mode absolute"

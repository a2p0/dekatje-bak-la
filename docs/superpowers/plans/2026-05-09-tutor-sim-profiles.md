# 063 — Tutor Sim Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter les profils de simulation `autonome` et `passif` à côté du `collaboratif` existant, et gater 3 nouvelles métriques structurelles (SC-C, SC-D, SC-E) dans le workflow CI tutor_simulation.

**Architecture:** Nouveau service `TutorSimulation::ProfileBehavior` qui encapsule la logique runtime par profil (déclenchement de `viewed_correction` selon un seuil de tours sans réussite + détection du tag `[VOIR_CORRECTION]` dans la réponse élève). Le `Runner` appelle `ProfileBehavior` à chaque tour, déclenche `Tutor::RecordEvent.call(type: "viewed_correction", source: "code")` selon les règles du profil, et break la boucle après abandon. Le `ReportGenerator` est enrichi d'une section par-profil avec drapeau `WARN` indicatif. Le workflow YAML asserte 3 nouveaux seuils sur la moyenne globale (pas par profil).

**Tech Stack:** Ruby 3.3+, Rails 8.1, RSpec, FactoryBot, FakeRubyLlm (stub `RubyLLM::Chat`), GitHub Actions (workflow_dispatch).

**Spec source:** `docs/superpowers/specs/2026-05-09-tutor-sim-profiles-design.md`

---

## File Structure

| Action | Chemin | Responsabilité |
|---|---|---|
| Create | `app/services/tutor_simulation/profile_behavior.rb` | Logique runtime par profil (should_view_correction?, strip_view_tag) |
| Create | `spec/services/tutor_simulation/profile_behavior_spec.rb` | Unit specs |
| Modify | `app/services/tutor_simulation/student_simulator.rb` | Ajouter `autonome` + `passif` à PROFILES |
| Modify | `spec/services/tutor_simulation/student_simulator_spec.rb` | Couverture explicite des nouveaux profils |
| Modify | `app/services/tutor_simulation/runner.rb` | Wire ProfileBehavior dans simulate_profile + emit viewed_correction |
| Modify | `spec/services/tutor_simulation/runner_spec.rb` | Specs integration emit viewed_correction |
| Modify | `app/services/tutor_simulation/report_generator.rb` | Section par-profil + WARN |
| Modify | `spec/services/tutor_simulation/report_generator_spec.rb` | Couverture WARN + multi-profil |
| Modify | `lib/tasks/tutor_simulate.rake` | Doc commentaire (coût 3× si pas de PROFILES=) |
| Modify | `.github/workflows/tutor_simulation.yml` | 3 nouvelles assertions SC-C/D/E |

Tasks 1–6 livrent le code et les specs (TDD). Task 7 ajoute les seuils CI. Tasks 8–9 valident sur sims réelles (smoke + baseline) et ajustent les seuils si nécessaire.

---

## Task 1: ProfileBehavior service + specs

**Files:**
- Create: `app/services/tutor_simulation/profile_behavior.rb`
- Test: `spec/services/tutor_simulation/profile_behavior_spec.rb`

- [ ] **Step 1: Write the failing spec**

Créer `spec/services/tutor_simulation/profile_behavior_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe TutorSimulation::ProfileBehavior do
  describe ".for" do
    it "accepte un symbole" do
      expect { described_class.for(:autonome) }.not_to raise_error
    end

    it "accepte une string" do
      expect { described_class.for("autonome") }.not_to raise_error
    end

    it "lève KeyError sur profil inconnu" do
      expect { described_class.for(:inexistant) }.to raise_error(KeyError)
    end
  end

  describe "#should_view_correction?" do
    context "profil autonome" do
      let(:behavior) { described_class.for(:autonome) }

      it "retourne false même après 20 tours sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "encore raté", turns_without_correct: 20)
        ).to be(false)
      end

      it "retourne false même si le message contient [VOIR_CORRECTION]" do
        expect(
          behavior.should_view_correction?(student_message: "[VOIR_CORRECTION]", turns_without_correct: 0)
        ).to be(false)
      end
    end

    context "profil collaboratif" do
      let(:behavior) { described_class.for(:collaboratif) }

      it "retourne false avant 8 tours sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "j'essaie encore", turns_without_correct: 7)
        ).to be(false)
      end

      it "retourne true au 8e tour sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "je galère", turns_without_correct: 8)
        ).to be(true)
      end

      it "retourne true si message contient [VOIR_CORRECTION] avant 8 tours" do
        expect(
          behavior.should_view_correction?(student_message: "j'abandonne [VOIR_CORRECTION]", turns_without_correct: 2)
        ).to be(true)
      end
    end

    context "profil passif" do
      let(:behavior) { described_class.for(:passif) }

      it "retourne false avant 3 tours" do
        expect(
          behavior.should_view_correction?(student_message: "je sais pas", turns_without_correct: 2)
        ).to be(false)
      end

      it "retourne true au 3e tour sans réussite" do
        expect(
          behavior.should_view_correction?(student_message: "je sais pas", turns_without_correct: 3)
        ).to be(true)
      end

      it "retourne true si message contient [VOIR_CORRECTION]" do
        expect(
          behavior.should_view_correction?(student_message: "[VOIR_CORRECTION]", turns_without_correct: 0)
        ).to be(true)
      end
    end
  end

  describe "#strip_view_tag" do
    let(:behavior) { described_class.for(:passif) }

    it "retire le tag et trim le résultat" do
      expect(behavior.strip_view_tag("Bof. [VOIR_CORRECTION]")).to eq("Bof.")
    end

    it "retourne le message intact si pas de tag" do
      expect(behavior.strip_view_tag("je tente la formule v=d/t")).to eq("je tente la formule v=d/t")
    end

    it "retire toutes les occurrences" do
      expect(
        behavior.strip_view_tag("[VOIR_CORRECTION] ras-le-bol [VOIR_CORRECTION]")
      ).to eq("ras-le-bol")
    end
  end
end
```

- [ ] **Step 2: Run the spec — expect failure (file does not exist)**

```bash
bundle exec rspec spec/services/tutor_simulation/profile_behavior_spec.rb
```

Expected: `LoadError` ou erreur "uninitialized constant TutorSimulation::ProfileBehavior".

- [ ] **Step 3: Implement the service**

Créer `app/services/tutor_simulation/profile_behavior.rb`:

```ruby
module TutorSimulation
  # Encapsulates per-profile runtime behavior used by the simulation Runner
  # — deciding when to trigger `viewed_correction` and whether to honor the
  # `[VOIR_CORRECTION]` tag a simulated student may emit.
  #
  # Profiles' personality (their LLM system prompt) lives in StudentSimulator.
  # ProfileBehavior is purely the deterministic side-channel that the Runner
  # uses to route the simulated student's behavior into trace events.
  class ProfileBehavior
    BEHAVIORS = {
      autonome: {
        view_correction_after_turns: nil,   # never triggers correction
        honor_view_tag:              false  # ignores [VOIR_CORRECTION]
      },
      collaboratif: {
        view_correction_after_turns: 8,
        honor_view_tag:              true
      },
      passif: {
        view_correction_after_turns: 3,
        honor_view_tag:              true
      }
    }.freeze

    VIEW_TAG = "[VOIR_CORRECTION]".freeze

    def self.for(profile)
      new(profile)
    end

    def initialize(profile)
      @profile = profile.to_sym
      @config  = BEHAVIORS.fetch(@profile)
    end

    def should_view_correction?(student_message:, turns_without_correct:)
      return true if @config[:honor_view_tag] && student_message.to_s.include?(VIEW_TAG)

      threshold = @config[:view_correction_after_turns]
      return false if threshold.nil?
      turns_without_correct >= threshold
    end

    def strip_view_tag(student_message)
      student_message.to_s.gsub(VIEW_TAG, "").strip
    end
  end
end
```

- [ ] **Step 4: Run the spec — expect pass**

```bash
bundle exec rspec spec/services/tutor_simulation/profile_behavior_spec.rb
```

Expected: 14 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor_simulation/profile_behavior.rb \
        spec/services/tutor_simulation/profile_behavior_spec.rb
git commit -m "feat(sim): add ProfileBehavior service with autonome/collaboratif/passif rules"
```

---

## Task 2: Étendre StudentSimulator avec autonome + passif

**Files:**
- Modify: `app/services/tutor_simulation/student_simulator.rb`
- Modify: `spec/services/tutor_simulation/student_simulator_spec.rb`

- [ ] **Step 1: Write the failing test**

Étendre `spec/services/tutor_simulation/student_simulator_spec.rb` — ajouter ce bloc à l'intérieur de `describe "profiles" do`:

```ruby
it "exposes the autonome profile" do
  simulator = described_class.new(profile: :autonome, client: client)
  expect(simulator.profile_label).to eq("Élève autonome")
end

it "exposes the passif profile" do
  simulator = described_class.new(profile: :passif, client: client)
  expect(simulator.profile_label).to eq("Élève passif")
end

it "exposes the collaboratif profile (regression)" do
  simulator = described_class.new(profile: :collaboratif, client: client)
  expect(simulator.profile_label).to eq("Élève collaboratif")
end
```

- [ ] **Step 2: Run spec — expect failure**

```bash
bundle exec rspec spec/services/tutor_simulation/student_simulator_spec.rb
```

Expected: 2 failures sur `:autonome` and `:passif` (ArgumentError "Unknown profile").

- [ ] **Step 3: Add profiles to StudentSimulator**

Modifier `app/services/tutor_simulation/student_simulator.rb` — remplacer le hash `PROFILES` (qui contient seulement `:collaboratif`) par:

```ruby
PROFILES = {
  autonome: {
    label: "Élève autonome",
    system: <<~PROMPT
      Tu simules un élève de Terminale STI2D qui prépare le BAC.
      Profil : autonome — tu préfères réfléchir seul. Tu demandes très rarement
      de l'aide. Si tu es bloqué, tu retentes par toi-même plusieurs fois avant
      de demander quoi que ce soit.
      Tu ne demandes JAMAIS à voir la correction.
      Tu n'écris jamais [VOIR_CORRECTION].
      Si vraiment tu n'y arrives pas après 6+ tentatives, tu admets ne pas savoir
      mais tu ne capitules pas, tu retentes encore.
      Réponds en français, niveau lycéen, 1-3 phrases maximum.
    PROMPT
  },
  collaboratif: {
    label: "Élève collaboratif",
    system: <<~PROMPT
      Tu simules un élève de Terminale STI2D qui prépare le BAC.
      Profil : collaboratif — tu tentes d'abord de répondre par toi-même, puis tu demandes
      de l'aide de façon progressive : d'abord la formule à utiliser, puis une valeur, puis
      le calcul. Si tu es bloqué depuis plusieurs échanges, tu demandes à voir la correction.
      Tu préfères des messages courts, style SMS ou chips : "Quelle formule je dois utiliser ?",
      "Donne-moi un indice…", "Je ne vois pas comment partir."
      Réponds en français, niveau lycéen, 1-3 phrases maximum.
    PROMPT
  },
  passif: {
    label: "Élève passif",
    system: <<~PROMPT
      Tu simules un élève de Terminale STI2D qui prépare le BAC.
      Profil : passif — tu cherches le minimum d'effort. Tu demandes vite l'aide
      maximale. Tes premières réponses sont du type "je sais pas",
      "donne-moi un indice", "comment je fais ?".
      Si tu sens que ça bloque dès 3 tours, tu écris [VOIR_CORRECTION] pour voir
      la solution.
      Tu acceptes les chips d'aide proposés sans chercher à les éviter.
      Réponds en français, niveau lycéen, 1-2 phrases maximum.
    PROMPT
  }
}.freeze
```

Aussi : retirer le commentaire obsolète `# 062: only :collaboratif retained. autonome and passif deferred to PR 063.` au-dessus du hash.

- [ ] **Step 4: Run spec — expect pass**

```bash
bundle exec rspec spec/services/tutor_simulation/student_simulator_spec.rb
```

Expected: 8 examples, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor_simulation/student_simulator.rb \
        spec/services/tutor_simulation/student_simulator_spec.rb
git commit -m "feat(sim): add autonome and passif prompts to StudentSimulator"
```

---

## Task 3: Wire ProfileBehavior dans Runner — émettre viewed_correction

**Files:**
- Modify: `app/services/tutor_simulation/runner.rb` (méthode `simulate_profile`, lignes ~92-127)
- Test: `spec/services/tutor_simulation/runner_spec.rb` (ajout d'un nouveau `describe`)

- [ ] **Step 1: Write the failing integration test**

Ajouter à la fin de `spec/services/tutor_simulation/runner_spec.rb`, **avant le `end` final** du `RSpec.describe`:

```ruby
describe "viewed_correction emission via ProfileBehavior" do
  let(:passif_student_client) do
    instance_double(AiClientFactory)
  end

  before do
    # Profil passif : 3 réponses "je sais pas" pour atteindre le seuil de 3 tours.
    allow(passif_student_client).to receive(:call).and_return(
      "je sais pas",
      "donne-moi un indice",
      "toujours pas"
    )
    allow(passif_student_client).to receive(:instance_variable_get).with(:@provider).and_return(:openrouter)
    allow(passif_student_client).to receive(:instance_variable_get).with(:@model).and_return("openai/gpt-4o-mini")
  end

  it "déclenche RecordEvent viewed_correction sur le profil passif après 3 tours sans correct" do
    runner = described_class.new(
      subject:        exam_subject,
      profiles:       [ "passif" ],
      max_turns:      5,
      api_key:        "or-test",
      tutor_model:    "openai/gpt-4o-mini",
      student_client: passif_student_client,
      judge_client:   judge_client,
      output_dir:     Dir.mktmpdir
    )
    ENV["SKIP_JUDGE"] = "1"

    expect(Tutor::RecordEvent).to receive(:call)
      .with(hash_including(type: "viewed_correction", source: "code"))
      .at_least(:once)
      .and_call_original

    runner.run
  ensure
    ENV.delete("SKIP_JUDGE")
  end

  it "n'appelle jamais viewed_correction sur le profil autonome" do
    runner = described_class.new(
      subject:        exam_subject,
      profiles:       [ "autonome" ],
      max_turns:      5,
      api_key:        "or-test",
      tutor_model:    "openai/gpt-4o-mini",
      student_client: passif_student_client,  # même script "je sais pas" mais autonome ignore
      judge_client:   judge_client,
      output_dir:     Dir.mktmpdir
    )
    ENV["SKIP_JUDGE"] = "1"

    expect(Tutor::RecordEvent).not_to receive(:call)
      .with(hash_including(type: "viewed_correction"))

    runner.run
  ensure
    ENV.delete("SKIP_JUDGE")
  end
end
```

- [ ] **Step 2: Run spec — expect failure**

```bash
bundle exec rspec spec/services/tutor_simulation/runner_spec.rb -e "viewed_correction"
```

Expected: 2 failures (RecordEvent jamais appelé pour `viewed_correction` car le Runner ne l'émet pas encore).

- [ ] **Step 3: Modify Runner#simulate_profile to wire ProfileBehavior**

Dans `app/services/tutor_simulation/runner.rb`, remplacer la méthode `simulate_profile` (lignes ~92-151) par :

```ruby
def simulate_profile(question, profile, classroom)
  simulator   = StudentSimulator.new(profile: profile, client: @student_client)
  behavior    = ProfileBehavior.for(profile)
  sim_student = build_sim_student(profile, classroom)
  conversation = build_conversation(sim_student)

  configure_ruby_llm

  transcript            = []
  turns_without_correct = 0

  @max_turns.times do |turn|
    raw_student = simulator.respond(
      question_label:       question.label,
      conversation_history: transcript,
      turn:                 turn + 1
    )
    cleaned = behavior.strip_view_tag(raw_student)
    print "    [#{turn + 1}/#{@max_turns}] élève ✓ "

    if behavior.should_view_correction?(
         student_message:       raw_student,
         turns_without_correct: turns_without_correct
       )
      Tutor::RecordEvent.call(
        conversation: conversation,
        question_id:  question.id,
        type:         "viewed_correction",
        source:       "code"
      )
      transcript << {
        "role"    => "user",
        "content" => cleaned.presence || "Je vais voir la correction."
      }
      puts "abandon — viewed_correction émis"
      break
    end

    transcript << { "role" => "user", "content" => cleaned }

    result = Tutor::ProcessMessage.call(
      conversation:  conversation,
      student_input: cleaned,
      question:      question,
      access_code:   nil
    )

    if result.err?
      puts "tuteur ✗ (#{result.error})"
      transcript << { "role" => "assistant", "content" => "[ERREUR : #{result.error}]" }
      break
    end

    conversation.reload
    last_assistant = conversation.messages.where(role: :assistant).order(:created_at).last
    transcript << { "role" => "assistant", "content" => last_assistant&.content.to_s }
    puts "tuteur ✓"

    trace      = conversation.tutor_state.trace_for(question.id)
    last_event = trace.events.last
    if last_event&.dig("type") == "student_attempt" && last_event["verdict"] == "correct"
      turns_without_correct = 0
    else
      turns_without_correct += 1
    end
  end

  conversation.reload

  structural = StructuralMetrics.compute(conversation: conversation, question_ids: [ question.id ])

  evaluation = if ENV["SKIP_JUDGE"] == "1"
    puts "    Juge désactivé (SKIP_JUDGE=1)"
    { "skipped" => true }
  else
    puts "    Évaluation..."
    judge_transcript(question, profile, simulator.profile_label, transcript)
  end

  {
    profile:               profile.to_s,
    profile_label:         simulator.profile_label,
    student_id:            sim_student.id,
    conversation_id:       conversation.id,
    transcript:            transcript,
    structural_metrics:    structural,
    evaluation:            evaluation,
    final_lifecycle_state: conversation.lifecycle_state
  }
end
```

Notes pour l'engineer :
- Le `print/puts` console est conservé pour les logs runtime, important pour debug en sim live.
- `break` après `viewed_correction` reflète l'abandon (le profil simulé arrête sur cette question).
- Le compteur `turns_without_correct` est mis à jour APRÈS chaque envoi au tuteur, en lisant le dernier event de la trace.

- [ ] **Step 4: Run spec — expect pass**

```bash
bundle exec rspec spec/services/tutor_simulation/runner_spec.rb
```

Expected: 8 examples (les 6 préexistants + 2 nouveaux), 0 failures.

- [ ] **Step 5: Run full sim spec suite to check no regression**

```bash
bundle exec rspec spec/services/tutor_simulation/
```

Expected: tous les specs sim verts.

- [ ] **Step 6: Commit**

```bash
git add app/services/tutor_simulation/runner.rb \
        spec/services/tutor_simulation/runner_spec.rb
git commit -m "feat(sim): wire ProfileBehavior in Runner + emit viewed_correction"
```

---

## Task 4: ReportGenerator — section par-profil + WARN

**Files:**
- Modify: `app/services/tutor_simulation/report_generator.rb`
- Modify: `spec/services/tutor_simulation/report_generator_spec.rb`

Le rapport actuel (`#to_markdown`) affiche déjà chaque profil en section ## séparée avec ses 8 métriques. Le travail ici est d'ajouter un drapeau `⚠ WARN` à côté d'une métrique qui dépasse le seuil indicatif **par profil** (différent du seuil global CI).

- [ ] **Step 1: Write the failing test**

Ajouter à `spec/services/tutor_simulation/report_generator_spec.rb`, dans `describe "#to_markdown"` (ou créer le bloc s'il n'existe pas) :

```ruby
describe "#to_markdown — drapeaux WARN par profil" do
  let(:simulation_data_warn) do
    {
      subject_id:       1,
      subject_title:    "Test",
      timestamp:        "2026-05-09T10:00:00+00:00",
      max_turns:        8,
      tutor_provider:   "openrouter",
      tutor_model:      "openai/gpt-4o-mini",
      student_provider: "openrouter",
      student_model:    "openai/gpt-4o-mini",
      judge_provider:   "openrouter",
      judge_model:      "anthropic/claude-sonnet-4",
      results: [
        {
          question_id:     42,
          question_number: "1.1",
          question_label:  "Calculer",
          points:          2.0,
          answer_type:     "calculation",
          correction:      "56,73 l",
          profiles: [
            {
              profile:       "autonome",
              profile_label: "Élève autonome",
              transcript:    [],
              structural_metrics: {
                resolution_rate:                   1.0,
                cap_violations:                    0,
                mean_help_steps_before_resolution: 1.0,
                proactive_help_rate:               0.40,  # > 0.20 → WARN
                correct_attempts_after_help_rate:  0.50,
                attempts_per_question:             3.0,
                correction_view_rate:              0.50,  # > 0 → WARN (autonome doit être 0)
                mean_turns_to_resolution:          4.0
              },
              evaluation: { "skipped" => true }
            }
          ]
        }
      ]
    }
  end

  it "affiche ⚠ WARN sur proactive_help_rate quand > seuil indicatif autonome (0.20)" do
    md = described_class.new(simulation_data_warn).to_markdown
    expect(md).to match(/Taux aide proactive.*0\.4.*⚠ WARN/)
  end

  it "affiche ⚠ WARN sur correction_view_rate quand > 0 pour autonome" do
    md = described_class.new(simulation_data_warn).to_markdown
    expect(md).to match(/Taux consultation correction.*0\.5.*⚠ WARN/)
  end

  it "n'affiche pas ⚠ WARN si la métrique respecte le seuil indicatif" do
    ok_data = simulation_data_warn.deep_dup
    ok_data[:results][0][:profiles][0][:structural_metrics][:proactive_help_rate]   = 0.10
    ok_data[:results][0][:profiles][0][:structural_metrics][:correction_view_rate] = 0.0

    md = described_class.new(ok_data).to_markdown
    expect(md).not_to match(/Taux aide proactive.*WARN/)
    expect(md).not_to match(/Taux consultation correction.*WARN/)
  end
end
```

- [ ] **Step 2: Run spec — expect failure**

```bash
bundle exec rspec spec/services/tutor_simulation/report_generator_spec.rb -e "WARN"
```

Expected: 2 failures (les patterns WARN ne sont pas dans le markdown).

- [ ] **Step 3: Add per-profile thresholds + WARN rendering**

Dans `app/services/tutor_simulation/report_generator.rb`:

a) Ajouter en haut du module (après `class ReportGenerator`), comme constante :

```ruby
# Per-profile indicative thresholds. Used only for WARN flags in the
# markdown report — not enforced by CI. Calibrate from baseline runs.
PER_PROFILE_THRESHOLDS = {
  "autonome" => {
    proactive_help_rate:               { op: :<=, value: 0.20 },
    mean_help_steps_before_resolution: { op: :>=, value: 0.5 },
    correction_view_rate:              { op: :==, value: 0.0 }
  },
  "collaboratif" => {
    proactive_help_rate:               { op: :<=, value: 0.30 },
    mean_help_steps_before_resolution: { op: :>=, value: 1.5 },
    correct_attempts_after_help_rate:  { op: :>=, value: 0.60 },
    correction_view_rate:              { op: :<=, value: 0.20 }
  },
  "passif" => {
    proactive_help_rate:               { op: :<=, value: 0.50 },
    mean_help_steps_before_resolution: { op: :>=, value: 1.0 },
    correct_attempts_after_help_rate:  { op: :>=, value: 0.40 },
    correction_view_rate:              { op: :>=, value: 0.66 }
  }
}.freeze
```

b) Modifier la signature de `render_structural` pour accepter le profil et utiliser `format_metric` (nouvelle helper) :

Remplacer dans la méthode `to_markdown` la ligne :
```ruby
render_structural(lines, profile_result[:structural_metrics])
```
par :
```ruby
render_structural(lines, profile_result[:structural_metrics], profile_result[:profile])
```

Puis remplacer `render_structural` par :

```ruby
def render_structural(lines, metrics, profile = nil)
  return unless metrics

  lines << "**Métriques structurelles** (calculées sur la conversation persistée)"
  lines << ""
  lines << "| Métrique | Valeur |"
  lines << "|---|---|"
  lines << "| Taux de résolution (cible ≥0.7) | #{format_metric(metrics, :resolution_rate, profile)} |"
  lines << "| Violations CAP (cible = 0) | #{format_value(metrics[:cap_violations])} |"
  lines << "| Étapes d'aide avant résolution | #{format_metric(metrics, :mean_help_steps_before_resolution, profile)} |"
  lines << "| Taux aide proactive | #{format_metric(metrics, :proactive_help_rate, profile)} |"
  lines << "| Taux tentatives correctes après aide | #{format_metric(metrics, :correct_attempts_after_help_rate, profile)} |"
  lines << "| Tentatives par question | #{format_value(metrics[:attempts_per_question])} |"
  lines << "| Taux consultation correction | #{format_metric(metrics, :correction_view_rate, profile)} |"
  lines << "| Tours moyens avant résolution | #{format_value(metrics[:mean_turns_to_resolution])} |"
  lines << ""
end

def format_metric(metrics, key, profile)
  value = metrics[key]
  return "—" if value.nil?

  threshold = PER_PROFILE_THRESHOLDS.dig(profile.to_s, key)
  return value.to_s if threshold.nil?

  passes = case threshold[:op]
           when :<= then value <= threshold[:value]
           when :>= then value >= threshold[:value]
           when :== then value == threshold[:value]
           end

  passes ? value.to_s : "#{value} ⚠ WARN"
end
```

- [ ] **Step 4: Run spec — expect pass**

```bash
bundle exec rspec spec/services/tutor_simulation/report_generator_spec.rb
```

Expected: tous les examples verts (préexistants + 3 nouveaux WARN).

- [ ] **Step 5: Commit**

```bash
git add app/services/tutor_simulation/report_generator.rb \
        spec/services/tutor_simulation/report_generator_spec.rb
git commit -m "feat(sim): enrich ReportGenerator with per-profile WARN flags"
```

---

## Task 5: Documenter le coût rake task

**Files:**
- Modify: `lib/tasks/tutor_simulate.rake` (commentaire d'ouverture)

Pas de code à changer. Juste mettre à jour la doc inline pour avertir que la liste de profils par défaut est passée de 1 à 3 (coût ×3).

- [ ] **Step 1: Read existing comment**

```bash
sed -n '1,30p' lib/tasks/tutor_simulate.rake
```

- [ ] **Step 2: Update comment**

Modifier `lib/tasks/tutor_simulate.rake`. Trouver la ligne :

```ruby
PROFILES            Comma-separated profiles (default: all)
```

Et remplacer par :

```ruby
PROFILES            Comma-separated profiles (default: autonome,collaboratif,passif)
                    NOTE: depuis 063, le default est 3 profils (×3 coût LLM).
                    Pour un smoke test rapide : PROFILES=collaboratif
```

- [ ] **Step 3: Commit**

```bash
git add lib/tasks/tutor_simulate.rake
git commit -m "docs(sim): note 3 profiles default in tutor:simulate rake task"
```

---

## Task 6: Vérification non-régression specs feature

**Files:** aucun, juste exécution.

- [ ] **Step 1: Run feature specs**

```bash
bundle exec rspec spec/features/student_tutor_full_flow_spec.rb \
                  spec/features/student_tutor_activation_spec.rb \
                  spec/features/student_tutor_chat_spec.rb \
                  spec/features/student_tutor_persistance_spec.rb \
                  2>&1 | tail -20
```

Expected: tous verts (063 ne touche aucune UI ni aucun service tutor côté app).

- [ ] **Step 2: Run rubocop and brakeman**

```bash
bundle exec rubocop app/services/tutor_simulation/ spec/services/tutor_simulation/
bundle exec brakeman --no-pager --quiet --confidence-level=2
```

Expected: 0 offenses, 0 warnings.

- [ ] **Step 3: Si rubocop ou brakeman casse, fixer puis commit séparé**

```bash
git add <fichiers fixés>
git commit -m "style(sim): rubocop autocorrect"
```

Si tout est vert, pas de commit.

---

## Task 7: Ajouter les seuils SC-C/D/E au workflow CI

**Files:**
- Modify: `.github/workflows/tutor_simulation.yml`

- [ ] **Step 1: Read current assertions**

```bash
sed -n '90,120p' .github/workflows/tutor_simulation.yml
```

Repérer le step "Assert SC-A (resolution_rate >= 0.70) and SC-B (cap_violations == 0)".

- [ ] **Step 2: Replace this step with extended assertions**

Modifier `.github/workflows/tutor_simulation.yml`. Trouver le bloc :

```yaml
      - name: Assert SC-A (resolution_rate >= 0.70) and SC-B (cap_violations == 0)
        run: |
          RAW_JSON=$(ls -1dt tmp/tutor_simulations/*/raw.json 2>/dev/null | head -n1)
          if [ -z "$RAW_JSON" ]; then
            echo "::error::No raw.json found in tmp/tutor_simulations/"
            exit 1
          fi
          echo "Reading: $RAW_JSON"

          # Aggregate metrics across .results[].profiles[].structural_metrics
          RR=$(jq '[.results[].profiles[].structural_metrics.resolution_rate] | add / length' "$RAW_JSON")
          CV=$(jq '[.results[].profiles[].structural_metrics.cap_violations] | add' "$RAW_JSON")
          echo "resolution_rate (mean) = $RR"
          echo "cap_violations (sum)   = $CV"

          python3 -c "import sys; sys.exit(0 if float('$RR') >= 0.70 else 1)" \
            || { echo "::error::SC-A failed: resolution_rate $RR < 0.70"; exit 1; }
          [ "$CV" = "0" ] \
            || { echo "::error::SC-B failed: $CV cap_violations (target 0)"; exit 1; }

          echo "✓ SC-A and SC-B passed"
```

Et le remplacer par :

```yaml
      - name: Assert SC-A through SC-E on aggregated structural metrics
        run: |
          RAW_JSON=$(ls -1dt tmp/tutor_simulations/*/raw.json 2>/dev/null | head -n1)
          if [ -z "$RAW_JSON" ]; then
            echo "::error::No raw.json found in tmp/tutor_simulations/"
            exit 1
          fi
          echo "Reading: $RAW_JSON"

          # Aggregate metrics across .results[].profiles[].structural_metrics
          RR=$(jq '[.results[].profiles[].structural_metrics.resolution_rate] | add / length' "$RAW_JSON")
          CV=$(jq '[.results[].profiles[].structural_metrics.cap_violations] | add' "$RAW_JSON")
          PHR=$(jq '[.results[].profiles[].structural_metrics.proactive_help_rate] | add / length' "$RAW_JSON")
          MHB=$(jq '[.results[].profiles[].structural_metrics.mean_help_steps_before_resolution] | add / length' "$RAW_JSON")
          CAH=$(jq '[.results[].profiles[].structural_metrics.correct_attempts_after_help_rate] | add / length' "$RAW_JSON")

          echo "SC-A resolution_rate (mean)                    = $RR  (target >= 0.70)"
          echo "SC-B cap_violations (sum)                      = $CV  (target == 0)"
          echo "SC-C proactive_help_rate (mean)                = $PHR (target <= 0.30)"
          echo "SC-D mean_help_steps_before_resolution (mean)  = $MHB (target >= 1.0)"
          echo "SC-E correct_attempts_after_help_rate (mean)   = $CAH (target >= 0.50)"

          python3 -c "import sys; sys.exit(0 if float('$RR') >= 0.70 else 1)" \
            || { echo "::error::SC-A failed: resolution_rate $RR < 0.70"; exit 1; }
          [ "$CV" = "0" ] \
            || { echo "::error::SC-B failed: $CV cap_violations (target 0)"; exit 1; }
          python3 -c "import sys; sys.exit(0 if float('$PHR') <= 0.30 else 1)" \
            || { echo "::error::SC-C failed: proactive_help_rate $PHR > 0.30"; exit 1; }
          python3 -c "import sys; sys.exit(0 if float('$MHB') >= 1.0 else 1)" \
            || { echo "::error::SC-D failed: mean_help_steps_before_resolution $MHB < 1.0"; exit 1; }
          python3 -c "import sys; sys.exit(0 if float('$CAH') >= 0.50 else 1)" \
            || { echo "::error::SC-E failed: correct_attempts_after_help_rate $CAH < 0.50"; exit 1; }

          echo "✓ SC-A through SC-E all passed"
```

- [ ] **Step 3: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tutor_simulation.yml'))"
```

Expected: pas de sortie (YAML valide).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/tutor_simulation.yml
git commit -m "ci(sim): add SC-C/D/E thresholds to tutor_simulation workflow"
```

---

## Task 8: Smoke test local (1 conv par profil, ~$0.50)

**Files:** aucun.

Cette task valide bout-en-bout que le code marche sur un vrai LLM avec le minimum de coût avant la baseline.

- [ ] **Step 1: Identifier un subject_id valide**

```bash
bin/rails runner 'puts Subject.where(status: :published).pluck(:id, :title).first(5).inspect'
```

Noter un `subject_id` (ci-dessous on suppose `1`).

- [ ] **Step 2: Lancer un smoke test avec 1 question, 5 tours, sans juge**

```bash
SKIP_JUDGE=1 bundle exec rake "tutor:simulate[1]" TURNS=5 QUESTIONS=1.1
```

Coût attendu : ~$0.30-0.50 (3 profils × 1 question × ~5 tours).

- [ ] **Step 3: Inspecter le rapport markdown**

```bash
ls -1dt tmp/tutor_simulations/*/report.md | head -1 | xargs cat
```

Vérifier que :
- Trois sections "Profil :" sont présentes (autonome, collaboratif, passif)
- Le bloc "Métriques structurelles" est rendu pour chaque profil
- Sur le profil passif, `correction_view_rate` est > 0 (l'élève a probablement abandonné)
- Sur le profil autonome, `correction_view_rate` est 0
- Aucun crash

- [ ] **Step 4: Si crash → debug + fixer**

Lire le stack trace, identifier la cause, ajouter un test de régression dans le service concerné, fixer, recommit.

Pas de commit nécessaire si tout marche.

---

## Task 9: Baseline calibrage + ajustement seuils si nécessaire (~$5)

**Files:**
- Maybe-modify: `.github/workflows/tutor_simulation.yml` (si seuils ajustés)
- Maybe-modify: `docs/superpowers/specs/2026-05-09-tutor-sim-profiles-design.md` (consigner valeurs observées)

- [ ] **Step 1: Lancer la baseline**

```bash
SKIP_JUDGE=1 bundle exec rake "tutor:simulate[1]" TURNS=8
```

Cette commande lance 5 questions × 3 profils = 15 convs. Coût attendu : ~$5.

- [ ] **Step 2: Extraire les valeurs des 5 SC depuis raw.json**

```bash
RAW=$(ls -1dt tmp/tutor_simulations/*/raw.json | head -1)
echo "=== Aggregated metrics ==="
jq '{
  SC_A_resolution_rate:                   ([.results[].profiles[].structural_metrics.resolution_rate] | add / length),
  SC_B_cap_violations:                    ([.results[].profiles[].structural_metrics.cap_violations] | add),
  SC_C_proactive_help_rate:               ([.results[].profiles[].structural_metrics.proactive_help_rate] | add / length),
  SC_D_mean_help_steps:                   ([.results[].profiles[].structural_metrics.mean_help_steps_before_resolution] | add / length),
  SC_E_correct_attempts_after_help_rate:  ([.results[].profiles[].structural_metrics.correct_attempts_after_help_rate] | add / length)
}' "$RAW"
```

- [ ] **Step 3: Comparer aux seuils a priori**

| SC | Seuil a priori | Valeur observée | Décision |
|---|---|---|---|
| SC-A `resolution_rate` | ≥ 0.70 | ? | Si < 0.70 et écart < 10% → relaxer à 0.65. Si écart > 10% → investigation. |
| SC-B `cap_violations` | == 0 | ? | Si > 0 → bug critique, ne pas relaxer, investiger le tuteur. |
| SC-C `proactive_help_rate` | ≤ 0.30 | ? | Idem A. |
| SC-D `mean_help_steps` | ≥ 1.0 | ? | Idem A. |
| SC-E `correct_attempts_after_help_rate` | ≥ 0.50 | ? | Idem A. |

- [ ] **Step 4a: Si tous les seuils passent à ≥10% de marge**

Saute Step 4b. Aller direct à Step 5.

- [ ] **Step 4b: Sinon, ajuster les seuils dans le workflow YAML**

Modifier `.github/workflows/tutor_simulation.yml` aux lignes correspondantes. Exemple (si SC-D observe `mean_help_steps = 0.7` et qu'on relaxe à 0.5) :

```yaml
python3 -c "import sys; sys.exit(0 if float('$MHB') >= 0.5 else 1)" \
  || { echo "::error::SC-D failed: mean_help_steps_before_resolution $MHB < 0.5"; exit 1; }
```

Commit dédié :

```bash
git add .github/workflows/tutor_simulation.yml
git commit -m "$(cat <<'EOF'
chore(sim): calibrate SC-C/D/E thresholds from 063 baseline

Baseline observée le 2026-05-09 sur subject_id=<X>, TURNS=8 :
- SC-A resolution_rate           = <valeur>  (seuil retenu : >= <X>)
- SC-B cap_violations            = <valeur>  (seuil retenu : == 0)
- SC-C proactive_help_rate       = <valeur>  (seuil retenu : <= <X>)
- SC-D mean_help_steps           = <valeur>  (seuil retenu : >= <X>)
- SC-E correct_attempts_after... = <valeur>  (seuil retenu : >= <X>)

Justification des relax/durcissements : <résumé en 1-2 lignes>.
EOF
)"
```

- [ ] **Step 5: Sim de validation finale**

Re-lancer la même commande qu'au Step 1 et re-extraire les SC. Vérifier que les 5 SC passent toutes avec les seuils retenus.

```bash
SKIP_JUDGE=1 bundle exec rake "tutor:simulate[1]" TURNS=8
RAW=$(ls -1dt tmp/tutor_simulations/*/raw.json | head -1)
jq '{ ... }' "$RAW"  # même requête qu'au Step 2
```

Si toujours passant : OK. Si une SC casse → variance excessive, lancer une 3e sim (ou repenser le profil).

- [ ] **Step 6: Mettre à jour la PR description avec les valeurs baseline**

Pas de commit, c'est dans la description PR. Format suggéré :

```markdown
## Baseline calibrage 063

Sim du 2026-05-09 sur subject_id=<X>, 5 questions × 3 profils, TURNS=8.

| SC | Seuil retenu | Valeur observée |
|---|---|---|
| SC-A resolution_rate | ≥ 0.70 | 0.XX |
| SC-B cap_violations | == 0 | 0 |
| SC-C proactive_help_rate | ≤ 0.30 | 0.XX |
| SC-D mean_help_steps | ≥ 1.0 | X.X |
| SC-E correct_after_help | ≥ 0.50 | 0.XX |

Coût total sim : ~$X (Phase 2 + 3 + 5).
```

---

## Task 10: Push branche + ouvrir PR

**Files:** aucun.

- [ ] **Step 1: Vérifier l'état de la branche**

```bash
git log --oneline main..HEAD
git status
```

Expected : ~7-9 commits propres, working tree clean.

- [ ] **Step 2: Push**

```bash
git push -u origin 063-tutor-sim-profiles
```

- [ ] **Step 3: Ouvrir la PR**

```bash
gh pr create --title "feat(sim): add autonome+passif profiles and SC-C/D/E thresholds (063)" \
  --body "$(cat <<'EOF'
## Summary

- Ajout des profils de simulation `autonome` et `passif` à côté du `collaboratif` existant (062)
- Nouveau service `TutorSimulation::ProfileBehavior` qui encapsule la logique runtime par profil
- Le `Runner` émet `viewed_correction` selon les règles du profil (tag `[VOIR_CORRECTION]` + seuil de tours sans réussite)
- 3 nouveaux seuils CI : SC-C `proactive_help_rate <= 0.30`, SC-D `mean_help_steps_before_resolution >= 1.0`, SC-E `correct_attempts_after_help_rate >= 0.50`
- Rapport markdown enrichi avec drapeau `⚠ WARN` par profil (indicatif, non gaté CI)

Spec : `docs/superpowers/specs/2026-05-09-tutor-sim-profiles-design.md`
Plan : `docs/superpowers/plans/2026-05-09-tutor-sim-profiles.md`

## Baseline calibrage

[À COMPLETER après Task 9]

## Hors scope

- Réécriture du juge LLM (rubrique 062) → PR 064 si nécessaire
- Refonte des profils en machine d'état déterministe

## Test plan

- [ ] CI standard verte (rspec + rubocop + brakeman)
- [ ] Specs feature `student_tutor_*` toujours vertes
- [ ] Smoke test sim local OK (Task 8)
- [ ] Baseline calibrage exécutée et seuils validés (Task 9)
- [ ] Workflow `tutor_simulation.yml` peut être déclenché manuellement et passe les 5 SC

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Reporter le lien de PR**

Récupérer l'URL de la PR via `gh pr view --json url -q .url` et la rapporter.

---

## Notes pour l'engineer

- **`StructuralMetrics#correction_view_rate`** : le spec 063 §5.3 mentionne un regression check unitaire pour cette métrique. Pas de task dédiée — la couverture est indirecte via Task 3 (les tests integration vérifient que `RecordEvent.call(type: "viewed_correction")` est bien appelé et donc que `correction_view_rate` croît). Si en Task 8/9 on observe que `correction_view_rate(passif)` reste à 0 malgré le déclenchement, ajouter un test unitaire dédié dans `structural_metrics_spec.rb`.
- **TDD strict** : chaque task suit Write spec → Run (fail) → Implement → Run (pass) → Commit. Ne pas court-circuiter.
- **Frequent commits** : 9-10 commits prévus, un par task ou demi-task. Squash optionnel à la PR si reviewer le souhaite.
- **Variance LLM attendue** sur Task 8/9 : ±0.1-0.2 sur les métriques continues. Si la baseline est juste au seuil, relaxer de 10% pour donner de l'air.
- **Coût total estimé** : ~$10-15 (Task 8: $0.5, Task 9: $5 baseline + $5 validation + $5 marge).
- **Si Task 8 ou Task 9 révèle un bug fonctionnel** (pas une question de seuil) → arrêter, fixer dans une task supplémentaire avec spec de régression, recommit.
- **Specs feature `student_tutor_*`** : 063 ne les touche pas, mais Task 6 vérifie en garde-fou (cf. mémoire `feedback_specs_in_same_pr` : régressions feature → corriger dans la même PR).

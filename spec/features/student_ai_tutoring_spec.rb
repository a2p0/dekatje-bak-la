require "rails_helper"

RSpec.describe "Story 9: Tutorat IA en streaming", type: :feature do
  let(:teacher) { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom, api_key: "sk-test", api_provider: :anthropic) }
  let(:subject_record) do
    create(:subject,
      status: :published,
      owner: teacher,
      specific_presentation: "La societe CIME fabrique des vehicules electriques.")
  end

  let(:part) do
    create(:part,
      subject: subject_record,
      number: 1,
      title: "Transport et developpement durable",
      objective_text: "Comparer les modes de transport.",
      position: 1)
  end

  let!(:question) do
    create(:question,
      part: part,
      number: "1.1",
      label: "Calculer la consommation en litres pour 186 km.",
      points: 2,
      position: 1)
  end

  let!(:answer) do
    create(:answer,
      question: question,
      correction_text: "Car = 56,73 l",
      explanation_text: "Formule Consommation x Distance / 100")
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  def visit_question_page
    visit student_question_path(
      access_code: classroom.access_code,
      subject_id: subject_record.id,
      id: question.id
    )
    expect(page).to have_css("[data-chat-connected='true']", wait: 10)
  end

  def open_drawer
    click_button "Tutorat"
    expect(page).to have_css("[data-chat-target='drawer'].translate-x-0", visible: :all, wait: 5)
  end

  # Scenario 1: Chat drawer opens on click
  scenario "le chat s'ouvre dans un drawer quand l'eleve clique Tutorat" do
    login_as_student(student, classroom)
    visit_question_page

    # Drawer should initially be off-screen (translate-x-full)
    drawer = find("[data-chat-target='drawer']", visible: :all)
    expect(drawer[:class]).to include("translate-x-full")

    open_drawer

    # Should show the empty state message inside the drawer
    drawer = find("[data-chat-target='drawer']", visible: :all)
    expect(drawer).to have_text("Posez votre question pour commencer le tutorat.")

    # Input should be present in the drawer
    expect(page).to have_css("[data-chat-target='input']", visible: :all)
  end

  # Scenario 1 (close): Chat drawer closes on close button click
  scenario "le chat se ferme au clic sur le bouton fermer" do
    login_as_student(student, classroom)
    visit_question_page

    open_drawer

    # Click the close button
    within("[data-chat-target='drawer']", visible: :all) do
      find("button", text: "✕", visible: :all).click
    end

    # Drawer should be translated offscreen again
    expect(page).to have_css("[data-chat-target='drawer'].translate-x-full", visible: :all, wait: 5)
  end

  # Scenario 2: Message is sent and TutorStreamJob is enqueued
  scenario "envoyer un message cree la conversation et enqueue le job de streaming" do
    login_as_student(student, classroom)
    visit_question_page

    open_drawer

    # Wait for conversation creation (async POST)
    expect(page).to have_css("[data-chat-target='input']", visible: :all, wait: 5)
    sleep 1

    input = find("[data-chat-target='input']", visible: :all)
    input.fill_in(with: "Comment calculer la consommation ?")

    find("[data-chat-target='sendButton']", visible: :all).click

    # User message should appear in the drawer (JS adds it to DOM)
    drawer = find("[data-chat-target='drawer']", visible: :all)
    expect(drawer).to have_text("Comment calculer la consommation ?", wait: 5)

    # Conversation should be persisted in DB (shared with server thread)
    conversation = nil
    using_wait_time(10) do
      expect { conversation = Conversation.find_by(student: student, question: question) }
        .not_to raise_error
    end
    expect(conversation).to be_present
    expect(conversation.messages.last["content"]).to eq("Comment calculer la consommation ?")
  end

  # Scenario 3: Tutor guides by steps (tested at service level)
  scenario "le system prompt du tuteur inclut la regle de ne jamais donner la reponse" do
    prompt = BuildTutorPrompt.call(question: question, student: student)

    expect(prompt).to include("ne donne JAMAIS la reponse directement")
    expect(prompt).to include("Guide l'eleve par etapes")
    expect(prompt).to include("valorise ses tentatives")
  end

  # Scenario 4: Conversation history is displayed when returning to a question
  scenario "l'historique de conversation s'affiche quand l'eleve revient sur une question" do
    # Pre-create a conversation with messages
    create(:conversation,
      student: student,
      question: question,
      messages: [
        { "role" => "user", "content" => "Comment je calcule la consommation ?", "at" => 1.hour.ago.iso8601 },
        { "role" => "assistant", "content" => "Bonne question ! Quelles donnees as-tu ?", "at" => 59.minutes.ago.iso8601 },
        { "role" => "user", "content" => "J'ai la consommation aux 100 km.", "at" => 58.minutes.ago.iso8601 },
        { "role" => "assistant", "content" => "Et quelle est la distance du trajet ?", "at" => 57.minutes.ago.iso8601 }
      ]
    )

    login_as_student(student, classroom)
    visit_question_page

    open_drawer

    drawer = find("[data-chat-target='drawer']", visible: :all)
    expect(drawer).to have_text("Comment je calcule la consommation ?")
    expect(drawer).to have_text("Bonne question ! Quelles donnees as-tu ?")
    expect(drawer).to have_text("J'ai la consommation aux 100 km.")
    expect(drawer).to have_text("Et quelle est la distance du trajet ?")
  end

  # Scenario 5: Insufficient credits error (tested at job level)
  scenario "une erreur de credits insuffisants est geree par le job" do
    conversation = create(:conversation, student: student, question: question)
    conversation.add_message!(role: "user", content: "Aide-moi")

    client_double = instance_double("AiClient")
    allow(AiClientFactory).to receive(:build).and_return(client_double)
    allow(client_double).to receive(:stream).and_raise(RuntimeError.new("402 Payment Required"))

    TutorStreamJob.perform_now(conversation.id)

    conversation.reload
    expect(conversation.streaming).to be false
  end

  # Scenario 6: Invalid API key error (tested at job level)
  scenario "une cle API invalide est geree par le job" do
    conversation = create(:conversation, student: student, question: question)
    conversation.add_message!(role: "user", content: "Aide-moi")

    client_double = instance_double("AiClient")
    allow(AiClientFactory).to receive(:build).and_return(client_double)
    allow(client_double).to receive(:stream).and_raise(RuntimeError.new("401 Unauthorized"))

    TutorStreamJob.perform_now(conversation.id)

    conversation.reload
    expect(conversation.streaming).to be false
  end

  # Scenario 7: Input is disabled during streaming
  scenario "l'input est desactive pendant le streaming" do
    login_as_student(student, classroom)
    visit_question_page

    open_drawer

    # Wait for conversation creation
    expect(page).to have_css("[data-chat-target='input']", visible: :all, wait: 5)
    sleep 1

    input = find("[data-chat-target='input']", visible: :all)
    input.fill_in(with: "Comment calculer ?")
    find("[data-chat-target='sendButton']", visible: :all).click

    # After sending, input and button should be disabled (streaming state)
    expect(page).to have_css("[data-chat-target='input'][disabled]", visible: :all, wait: 3)
    expect(page).to have_css("[data-chat-target='sendButton'][disabled]", visible: :all)
  end

  # Scenario 8: System prompt includes insights from previous conversations
  scenario "le system prompt inclut les insights des conversations precedentes" do
    create(:student_insight,
      student: student,
      subject: subject_record,
      question: question,
      insight_type: "mastered",
      concept: "consommation energetique",
      text: "L'eleve maitrise le calcul de consommation.")

    create(:student_insight,
      student: student,
      subject: subject_record,
      question: question,
      insight_type: "struggle",
      concept: "conversion unites",
      text: "Difficulte avec les conversions kWh/litres.")

    prompt = BuildTutorPrompt.call(question: question, student: student)

    expect(prompt).to include("Historique de l'eleve")
    expect(prompt).to include("consommation energetique")
    expect(prompt).to include("conversion unites")
    expect(prompt).to include("[mastered]")
    expect(prompt).to include("[struggle]")
  end
end

require "rails_helper"

RSpec.describe "Story 4: Validation et publication des questions", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_content("Mes classes")
  end

  # Turbo.config.forms.confirm is overridden with a custom <dialog> in application.js.
  # This requires Turbo JS to be fully loaded. To avoid timing issues, we wait for
  # the dialog to appear and click "Confirmer" inside it.
  def click_with_turbo_confirm(button_text)
    click_button button_text
    dialog = find("dialog", wait: 10)
    within(dialog) do
      click_button "Confirmer"
    end
  end

  before do
    login_as(user)
  end

  context "navigation vers une partie" do
    scenario "l'enseignant voit la liste des questions à gauche et le PDF énoncé à droite" do
      subject_record = create(:subject, owner: user)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, :specific, subject: subject_record, title: "Étude des transports", number: 1, position: 1)
      create(:question, part: part, number: "1.1", label: "Calculer la consommation", points: 2.0)
      create(:question, part: part, number: "1.2", label: "Comparer les énergies", points: 3.0)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("Étude des transports")
      expect(page).to have_content("Questions (2)")
      expect(page).to have_content("Q1.1")
      expect(page).to have_content("Q1.2")
      expect(page).to have_content("Énoncé")
      expect(page).to have_css("iframe", visible: :all)
    end
  end

  context "validation d'une question" do
    scenario "le statut passe à 'validated' et le bouton change quand l'enseignant clique 'Valider'" do
      subject_record = create(:subject, owner: user)
      part = create(:part, :specific, subject: subject_record)
      question = create(:question, part: part, number: "1.1", label: "Calculer la consommation", status: :draft)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("brouillon")
      expect(page).to have_button("Valider")

      click_button "Valider"

      # Wait for the Turbo Frame to process
      expect(page).to have_content("validée", wait: 10)
      expect(question.reload.status).to eq("validated")
    end
  end

  context "modification d'une question" do
    scenario "les modifications du label et des points sont enregistrées sans rechargement" do
      subject_record = create(:subject, owner: user)
      part = create(:part, :specific, subject: subject_record)
      question = create(:question, part: part, number: "1.1", label: "Ancien énoncé", points: 2.0)
      create(:answer, question: question)

      visit teacher_subject_part_path(subject_record, part)

      within("#question_#{question.id}") do
        fill_in "Énoncé", with: "Nouvel énoncé modifié"
        fill_in "Points", with: "4.5"
        click_button "Sauvegarder"
      end

      expect(page).to have_content("Nouvel énoncé modifié", wait: 5)
      expect(page).to have_content("4.5 pts")
      expect(question.reload.label).to eq("Nouvel énoncé modifié")
      expect(question.reload.points).to eq(4.5)
    end
  end

  context "suppression d'une question" do
    scenario "la question disparaît de la liste après suppression douce" do
      subject_record = create(:subject, owner: user)
      part = create(:part, :specific, subject: subject_record)
      create(:question, part: part, number: "1.1", label: "Question à supprimer")
      create(:question, part: part, number: "1.2", label: "Question à garder", position: 2)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("Question à supprimer")
      expect(page).to have_content("Question à garder")

      # data-turbo-confirm triggers custom <dialog> via Turbo JS
      # Two questions = two "Supprimer" buttons; click the first one
      first(:button, "Supprimer").click
      dialog = find("dialog", wait: 10)
      within(dialog) { click_button "Confirmer" }

      expect(page).not_to have_content("Question à supprimer", wait: 5)
      expect(page).to have_content("Question à garder")
    end
  end

  context "publication d'un sujet" do
    scenario "le sujet passe en 'published' et redirige vers l'assignation quand au moins une question est validée" do
      subject_record = create(:subject, owner: user, status: :draft)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, :specific, subject: subject_record)
      create(:question, part: part, status: :validated)

      visit teacher_subject_path(subject_record)

      click_with_turbo_confirm("Publier le sujet")

      expect(page).to have_content("Sujet publié", wait: 5)
      expect(page).to have_content("Assigner")
      expect(subject_record.reload.status).to eq("published")
    end

    scenario "le bouton 'Publier' est désactivé avec un message quand aucune question n'est validée" do
      subject_record = create(:subject, owner: user, status: :draft)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, :specific, subject: subject_record)
      create(:question, part: part, status: :draft)

      visit teacher_subject_path(subject_record)

      expect(page).to have_button("Publier le sujet (validez au moins une question)", disabled: true)
    end
  end

  context "assignation aux classes" do
    scenario "le sujet est assigné aux classes sélectionnées" do
      subject_record = create(:subject, owner: user, status: :published)
      create(:extraction_job, subject: subject_record, status: :done)
      classroom1 = create(:classroom, owner: user, name: "Terminale SIN A")
      classroom2 = create(:classroom, owner: user, name: "Terminale ITEC B")

      visit edit_teacher_subject_assignment_path(subject_record)

      expect(page).to have_content("Assigner")
      expect(page).to have_content("Terminale SIN A")
      expect(page).to have_content("Terminale ITEC B")

      check "Terminale SIN A"
      check "Terminale ITEC B"
      click_button "Enregistrer"

      expect(page).to have_content("Assignation mise à jour")
      expect(subject_record.reload.classroom_ids).to include(classroom1.id, classroom2.id)
    end
  end

  context "dépublication d'un sujet" do
    scenario "le sujet repasse en brouillon quand l'enseignant clique 'Dépublier'" do
      subject_record = create(:subject, owner: user, status: :published)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, :specific, subject: subject_record)
      create(:question, part: part, status: :validated)

      visit teacher_subject_path(subject_record)

      expect(page).to have_content("published")

      click_with_turbo_confirm("Dépublier")

      expect(page).to have_content("Sujet dépublié", wait: 5)
      expect(subject_record.reload.status).to eq("draft")
    end
  end
end

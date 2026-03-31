require "rails_helper"

RSpec.describe "Story 4: Validation et publication des questions", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    expect(page).to have_content("Mes classes")
  end

  before do
    login_as(user)
  end

  context "navigation vers une partie" do
    scenario "l'enseignant voit la liste des questions à gauche et le PDF énoncé à droite" do
      subject_record = create(:subject, owner: user)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, subject: subject_record, title: "Étude des transports", number: 1, position: 1)
      create(:question, part: part, number: "1.1", label: "Calculer la consommation", points: 2.0)
      create(:question, part: part, number: "1.2", label: "Comparer les énergies", points: 3.0)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("Étude des transports")
      expect(page).to have_content("Questions (2)")
      expect(page).to have_content("Q1.1")
      expect(page).to have_content("Q1.2")
      expect(page).to have_content("PDF Énoncé")
      expect(page).to have_css("iframe")
    end
  end

  context "validation d'une question" do
    scenario "le statut passe à 'validated' et le bouton change quand l'enseignant clique 'Valider'" do
      subject_record = create(:subject, owner: user)
      part = create(:part, subject: subject_record)
      question = create(:question, part: part, number: "1.1", label: "Calculer la consommation", status: :draft)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("brouillon")
      expect(page).to have_button("Valider")

      click_button "Valider"

      expect(page).to have_content("validée")
      expect(page).to have_button("Invalider")
      expect(page).not_to have_button("Valider")
      expect(question.reload.status).to eq("validated")
    end
  end

  context "modification d'une question" do
    scenario "les modifications du label et des points sont enregistrées sans rechargement" do
      subject_record = create(:subject, owner: user)
      part = create(:part, subject: subject_record)
      question = create(:question, part: part, number: "1.1", label: "Ancien énoncé", points: 2.0)
      create(:answer, question: question)

      visit teacher_subject_part_path(subject_record, part)

      fill_in "Énoncé", with: "Nouvel énoncé modifié"
      fill_in "Points", with: "4.5"
      click_button "Sauvegarder"

      expect(page).to have_content("Nouvel énoncé modifié")
      expect(page).to have_content("4.5 pts")
      expect(question.reload.label).to eq("Nouvel énoncé modifié")
      expect(question.reload.points).to eq(4.5)
    end
  end

  context "suppression d'une question" do
    scenario "la question disparaît de la liste après suppression douce" do
      subject_record = create(:subject, owner: user)
      part = create(:part, subject: subject_record)
      create(:question, part: part, number: "1.1", label: "Question à supprimer")
      create(:question, part: part, number: "1.2", label: "Question à garder", position: 2)

      visit teacher_subject_part_path(subject_record, part)

      expect(page).to have_content("Question à supprimer")
      expect(page).to have_content("Question à garder")

      accept_confirm("Supprimer cette question ?") do
        first("button", text: "Supprimer").click
      end

      expect(page).not_to have_content("Question à supprimer")
      expect(page).to have_content("Question à garder")
      expect(Question.find_by(number: "1.1").discarded_at).to be_present
    end
  end

  context "publication d'un sujet" do
    scenario "le sujet passe en 'published' et redirige vers l'assignation quand au moins une question est validée" do
      subject_record = create(:subject, owner: user, status: :draft)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, subject: subject_record)
      create(:question, part: part, status: :validated)

      visit teacher_subject_path(subject_record)

      accept_confirm("Publier ce sujet ?") do
        click_button "Publier le sujet"
      end

      expect(page).to have_content("Sujet publié")
      expect(page).to have_content("Assigner")
      expect(subject_record.reload.status).to eq("published")
    end

    scenario "le bouton 'Publier' est désactivé avec un message quand aucune question n'est validée" do
      subject_record = create(:subject, owner: user, status: :draft)
      create(:extraction_job, subject: subject_record, status: :done)
      part = create(:part, subject: subject_record)
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

      visit assign_teacher_subject_path(subject_record)

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
      part = create(:part, subject: subject_record)
      create(:question, part: part, status: :validated)

      visit teacher_subject_path(subject_record)

      expect(page).to have_content("published")

      accept_confirm("Dépublier ce sujet ?") do
        click_button "Dépublier"
      end

      expect(page).to have_content("Sujet dépublié")
      expect(subject_record.reload.status).to eq("draft")
    end
  end
end

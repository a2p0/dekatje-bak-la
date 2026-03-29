require "rails_helper"

RSpec.describe "Story 5: Connexion élève et navigation des sujets", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }

  scenario "un élève accède au formulaire de connexion via le code d'accès" do
    visit student_login_path(access_code: classroom.access_code)

    expect(page).to have_content("Connexion — Terminale SIN 2026")
    expect(page).to have_field("Identifiant")
    expect(page).to have_field("Mot de passe")
    expect(page).to have_button("Se connecter")
  end

  scenario "un élève se connecte avec des identifiants corrects" do
    student = create(:student, classroom: classroom, first_name: "Marie")

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("Bienvenue, Marie")
    expect(page).to have_content("Mes sujets")
  end

  scenario "un élève tente de se connecter avec des identifiants incorrects" do
    create(:student, classroom: classroom)

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: "mauvais.identifiant"
    fill_in "Mot de passe", with: "mauvais_mdp"
    click_button "Se connecter"

    expect(page).to have_content("Identifiant ou mot de passe incorrect")
  end

  scenario "un élève voit uniquement les sujets publiés assignés à sa classe avec la progression" do
    student = create(:student, classroom: classroom)

    published_subject = create(:subject, title: "BAC STI2D Metropole 2025", status: :published)
    create(:classroom_subject, classroom: classroom, subject: published_subject)

    draft_subject = create(:subject, title: "Sujet Brouillon", status: :draft)
    create(:classroom_subject, classroom: classroom, subject: draft_subject)

    unassigned_subject = create(:subject, title: "Sujet Autre Classe", status: :published)

    # Create a part with questions for progress display
    part = create(:part, subject: published_subject)
    q1 = create(:question, part: part, position: 1)
    q2 = create(:question, part: part, number: "1.2", position: 2)

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("BAC STI2D Metropole 2025")
    expect(page).to have_content("0/2 questions")
    expect(page).to have_content("0%")
    expect(page).not_to have_content("Sujet Brouillon")
    expect(page).not_to have_content("Sujet Autre Classe")
  end

  scenario "un élève clique Commencer sur un sujet non commencé" do
    student = create(:student, classroom: classroom)
    subject = create(:subject, title: "BAC STI2D 2025", status: :published)
    create(:classroom_subject, classroom: classroom, subject: subject)

    part = create(:part, subject: subject, position: 1)
    question = create(:question, part: part, position: 1, label: "Calculer la consommation")

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    click_link "Commencer"

    expect(page).to have_content("Calculer la consommation")
  end

  scenario "un élève clique Continuer sur un sujet en cours et arrive sur la première question non terminée" do
    student = create(:student, classroom: classroom)
    subject = create(:subject, title: "BAC STI2D 2025", status: :published)
    create(:classroom_subject, classroom: classroom, subject: subject)

    part = create(:part, subject: subject, position: 1)
    q1 = create(:question, part: part, position: 1, number: "1.1", label: "Question terminée")
    q2 = create(:question, part: part, position: 2, number: "1.2", label: "Question suivante à faire")

    # Create a session with q1 already answered
    create(:student_session,
      student: student,
      subject: subject,
      progression: { q1.id.to_s => { "seen" => true, "answered" => true } }
    )

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    click_link "Continuer"

    expect(page).to have_content("Question suivante à faire")
  end

  scenario "un élève connecté se déconnecte" do
    student = create(:student, classroom: classroom)

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("Mes sujets")

    click_link "Se déconnecter"

    expect(page).to have_content("Vous êtes déconnecté")
    expect(page).to have_content("Connexion — Terminale SIN 2026")
  end
end

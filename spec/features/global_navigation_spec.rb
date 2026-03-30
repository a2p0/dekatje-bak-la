require "rails_helper"

RSpec.describe "Story 10: Navigation globale et pages essentielles", type: :feature do
  scenario "un visiteur voit un lien connexion enseignant et un champ code d'accès élève sur la page d'accueil" do
    visit root_path

    expect(page).to have_link("Connexion enseignant")
    expect(page).to have_field("Code d'accès")
  end

  scenario "un enseignant connecté voit ses classes et ses sujets avec des liens vers toutes les actions possibles" do
    teacher = create(:user, confirmed_at: Time.current)
    classroom = create(:classroom, owner: teacher, name: "Terminale SIN 2026")
    subject = create(:subject, owner: teacher, title: "BAC STI2D Metropole 2025", status: :published)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    expect(page).to have_content("Mes classes")
    expect(page).to have_link("Terminale SIN 2026", href: teacher_classroom_path(classroom))
    expect(page).to have_link("Nouvelle classe")
  end

  scenario "un enseignant voit un bouton Nouveau sujet et des liens vers chaque sujet sur la liste des sujets" do
    teacher = create(:user, confirmed_at: Time.current)
    subject = create(:subject, owner: teacher, title: "BAC STI2D Metropole 2025")

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    visit teacher_subjects_path

    expect(page).to have_link("Nouveau sujet")
    expect(page).to have_link("BAC STI2D Metropole 2025", href: teacher_subject_path(subject))
  end

  scenario "un enseignant voit les PDFs, le statut d'extraction, les parties et les stats sur la page d'un sujet" do
    teacher = create(:user, confirmed_at: Time.current)
    subject = create(:subject, owner: teacher, title: "BAC STI2D Metropole 2025", status: :pending_validation)
    extraction_job = create(:extraction_job, subject: subject, status: :done)
    part = create(:part, subject: subject, title: "Analyse du système CIME", position: 1)
    question = create(:question, part: part, position: 1, status: :validated)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    visit teacher_subject_path(subject)

    # PDFs section
    expect(page).to have_content("Documents PDF")
    expect(page).to have_link("Énoncé")

    # Extraction status
    expect(page).to have_content("Extraction")
    expect(page).to have_content("done")

    # Parts with links
    expect(page).to have_link("Analyse du système CIME", href: teacher_subject_part_path(subject, part))

    # Validation stats
    expect(page).to have_content("Questions validées")
  end

  scenario "le menu enseignant permet de naviguer vers le dashboard, les classes, les sujets et la déconnexion" do
    teacher = create(:user, confirmed_at: Time.current)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    within("nav") do
      expect(page).to have_link("Mes classes", href: teacher_root_path)
      expect(page).to have_link("Mes sujets", href: teacher_subjects_path)
      expect(page).to have_link("Déconnexion")
    end
  end

  scenario "un élève connecté peut toujours accéder aux réglages et à la déconnexion" do
    classroom = create(:classroom, name: "Terminale SIN 2026")
    student = create(:student, classroom: classroom, first_name: "Marie")
    subject = create(:subject, title: "BAC STI2D 2025", status: :published)
    create(:classroom_subject, classroom: classroom, subject: subject)
    part = create(:part, subject: subject, position: 1)
    question = create(:question, part: part, position: 1, label: "Calculer la consommation")

    login_as_student(student, classroom)

    # On the subjects index page
    expect(page).to have_link(text: /Réglages/)
    expect(page).to have_link("Se déconnecter")

    # Navigate to a question page and check settings link is still present
    click_link "Commencer"

    expect(page).to have_link(text: /Réglages/)
  end
end

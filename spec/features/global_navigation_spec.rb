require "rails_helper"

RSpec.describe "Story 10: Navigation globale et pages essentielles", type: :feature do
  scenario "un visiteur voit un lien connexion enseignant et un champ code d'accès élève sur la page d'accueil" do
    visit root_path

    expect(page).to have_link("Connexion enseignant →")
    expect(page).to have_field("Code d'accès")
  end

  scenario "un enseignant connecté voit ses classes et ses sujets avec des liens vers toutes les actions possibles" do
    teacher = create(:user, confirmed_at: Time.current)
    classroom = create(:classroom, owner: teacher, name: "Terminale SIN 2026")
    es = create(:exam_session, owner: teacher, title: "BAC STI2D Metropole 2025")
    subject = create(:subject, owner: teacher, exam_session: es, status: :published)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("Mes classes")
    expect(page).to have_content("Terminale SIN 2026")
    expect(page).to have_link("Nouvelle classe")
  end

  scenario "un enseignant voit un bouton Nouveau sujet et des liens vers chaque sujet sur la liste des sujets" do
    teacher = create(:user, confirmed_at: Time.current)
    es = create(:exam_session, owner: teacher, title: "BAC STI2D Metropole 2025")
    subject_record = create(:subject, owner: teacher, exam_session: es)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_content("Mes classes")

    click_link "Mes sujets"

    expect(page).to have_link("Nouveau sujet")
    expect(page).to have_link("BAC STI2D Metropole 2025", href: teacher_subject_path(subject_record))
  end

  scenario "un enseignant voit les PDFs, le statut d'extraction, les parties et les stats sur la page d'un sujet" do
    teacher = create(:user, confirmed_at: Time.current)
    es = create(:exam_session, owner: teacher, title: "BAC STI2D Metropole 2025")
    subject_record = create(:subject, owner: teacher, exam_session: es, status: :pending_validation)
    create(:extraction_job, subject: subject_record, status: :done)
    part = create(:part, :specific, subject: subject_record, title: "Analyse du système CIME", position: 1)
    create(:question, part: part, position: 1, status: :validated)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_content("Mes classes")

    visit teacher_subject_path(subject_record)

    # PDFs section
    expect(page).to have_content("Documents PDF")
    expect(page).to have_link("Énoncé")

    # Extraction status
    expect(page).to have_content("Extraction")
    expect(page).to have_content("done")

    # Parts listed in accordion (title is not a direct link)
    expect(page).to have_content("Analyse du système CIME")

    # Validation stats
    expect(page).to have_content("Questions validées")
  end

  scenario "le menu enseignant permet de naviguer vers le dashboard, les classes, les sujets et la déconnexion" do
    teacher = create(:user, confirmed_at: Time.current)

    visit new_user_session_path
    fill_in "Email", with: teacher.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"

    within("nav") do
      expect(page).to have_link("Mes classes", href: teacher_root_path)
      expect(page).to have_link("Mes sujets", href: teacher_subjects_path)
      expect(page).to have_link("Déconnexion")
    end
  end

  scenario "un élève connecté peut toujours accéder aux réglages et à la déconnexion" do
    classroom = create(:classroom, name: "Terminale SIN 2026")
    student = create(:student, classroom: classroom, first_name: "Marie")
    subject = create(:subject, status: :published)
    create(:classroom_subject, classroom: classroom, subject: subject)
    part = create(:part, :specific, subject: subject, position: 1)
    question = create(:question, part: part, position: 1, label: "Calculer la consommation")

    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"

    # On the subjects index page
    expect(page).to have_link(text: /Réglages/)
    expect(page).to have_link("Déconnexion")

    # subjects#index → subjects#show (first Commencer)
    click_link "Commencer"
    # subjects#show → questions#show (second Commencer — points to Q1)
    find("a,button", text: "Commencer", match: :first).click

    # On desktop viewport (1400px), sidebar is always visible (lg:translate-x-0)
    within("aside") do
      expect(page).to have_link(text: /Réglages/)
    end
  end
end

require "rails_helper"

RSpec.describe "US3: Student specialty in settings", type: :feature do
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026") }
  let(:student)   { create(:student, classroom: classroom, specialty: nil) }
  let(:subject_record) do
    create(:subject,
      status: :published,
      specific_presentation: "La société CIME fabrique des véhicules électriques.")
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  scenario "l'élève voit le sélecteur de spécialité dans les réglages" do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    expect(page).to have_content("Ma spécialité")
    expect(page).to have_select("student[specialty]", with_options: %w[SIN ITEC EE AC])
  end

  scenario "l'élève sélectionne SIN et la spécialité est persistée" do
    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    select "SIN", from: "Ma spécialité"
    click_button "Enregistrer"

    expect(page).to have_content("Réglages enregistrés.")

    student.reload
    expect(student.specialty).to eq("SIN")
  end

  scenario "la spécialité est conservée après rechargement de la page" do
    student.update!(specialty: :SIN)

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    expect(page).to have_select("student[specialty]", selected: "SIN")
  end

  scenario "l'élève peut retirer sa spécialité en choisissant l'option vide" do
    student.update!(specialty: :SIN)

    login_as_student(student, classroom)
    visit student_settings_path(access_code: classroom.access_code)

    select "Pas de spécialité", from: "Ma spécialité"
    click_button "Enregistrer"

    expect(page).to have_content("Réglages enregistrés.")

    student.reload
    expect(student.specialty).to be_nil
  end
end

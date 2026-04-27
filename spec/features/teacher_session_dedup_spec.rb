require "rails_helper"

RSpec.describe "US2: Teacher uploads second specialty — dedup common parts", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }
  let(:exam_session) { create(:exam_session, owner: user, title: "BAC 2024 Polynesie") }

  def login_as(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"
    expect(page).to have_content("Mes classes")
  end

  before do
    # First subject already uploaded with common parts
    @first_subject = create(:subject, :new_format,
      owner: user,
      exam_session: exam_session,
      specialty: :SIN)

    create(:part,
      exam_session: exam_session, subject: nil,
      number: 1, title: "Partie commune existante",
      section_type: :common, position: 0,
      objective_text: "Objectif commun")

    create(:part,
      subject: @first_subject, exam_session: nil,
      number: 2, title: "Partie specifique SIN",
      section_type: :specific, position: 1)

    login_as(user)
  end

  scenario "second specialty upload reuses existing common parts" do
    visit new_teacher_subject_path

    # Select existing session
    select "BAC 2024 Polynesie", from: "Session existante (optionnel)"
    fill_in "Titre", with: "Sujet AC"
    fill_in "Année", with: "2024"
    select "Bac", from: "Type d'examen"
    select "AC", from: "Spécialité"
    select "Polynésie", from: "Région"

    attach_file "subject[subject_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s
    attach_file "subject[correction_pdf]", Rails.root.join("spec/fixtures/files/dummy.pdf").to_s

    page.execute_script("document.querySelector('form').submit()")

    # Verify the second subject was created under the same session
    second_subject = Subject.last
    expect(second_subject.exam_session).to eq(exam_session)
    expect(second_subject.title).to eq("BAC 2024 Polynesie")

    # Common parts should NOT be duplicated — still only 1
    expect(exam_session.common_parts.count).to eq(1)
    expect(exam_session.subjects.count).to eq(2)
  end
end

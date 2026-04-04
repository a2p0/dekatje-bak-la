require "rails_helper"

RSpec.describe "US4: Student scope selection (perimetre de travail)", type: :feature do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom) }

  # --- New-format subject (with exam_session) ---
  let(:exam_session) do
    create(:exam_session, owner: teacher, title: "BAC STI2D 2025", presentation_text: "Mise en situation CIME.")
  end

  let(:new_format_subject) do
    create(:subject, :new_format,
      title: "Sujet Nouveau Format",
      status: :published,
      specialty: :SIN,
      exam_session: exam_session,
      owner: teacher,
      presentation_text: "Presentation specifique SIN")
  end

  # Common parts (belong to exam_session, not subject)
  let!(:common_part) do
    create(:part,
      exam_session: exam_session,
      subject: nil,
      number: 1,
      title: "Partie commune transport",
      section_type: :common,
      position: 1)
  end

  # Specific parts (belong to subject)
  let!(:specific_part) do
    create(:part,
      subject: new_format_subject,
      exam_session: nil,
      number: 2,
      title: "Partie specifique SIN",
      section_type: :specific,
      position: 2)
  end

  let!(:common_q1) do
    create(:question,
      part: common_part,
      number: "1.1",
      label: "Question commune sur le transport durable",
      points: 4,
      position: 1)
  end

  let!(:common_q2) do
    create(:question,
      part: common_part,
      number: "1.2",
      label: "Deuxieme question commune",
      points: 4,
      position: 2)
  end

  let!(:specific_q1) do
    create(:question,
      part: specific_part,
      number: "2.1",
      label: "Question specifique SIN reseau",
      points: 4,
      position: 1)
  end

  let!(:new_format_cs) { create(:classroom_subject, classroom: classroom, subject: new_format_subject) }

  # --- Legacy subject (no exam_session) ---
  let(:legacy_subject) do
    create(:subject,
      title: "Sujet Legacy Format",
      status: :published,
      specialty: :SIN,
      owner: teacher,
      presentation_text: "Sujet classique sans exam session")
  end

  let!(:legacy_part) do
    create(:part,
      subject: legacy_subject,
      number: 1,
      title: "Partie unique",
      position: 1)
  end

  let!(:legacy_q1) do
    create(:question,
      part: legacy_part,
      number: "1.1",
      label: "Question du sujet legacy",
      points: 5,
      position: 1)
  end

  let!(:legacy_cs) { create(:classroom_subject, classroom: classroom, subject: legacy_subject) }

  scenario "new-format subject shows scope selection screen" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)
    # Should see the scope selection instead of mise en situation
    expect(page).to have_content("Choisissez votre perimetre de travail")
    expect(page).to have_button("Partie commune")
    expect(page).to have_content("Partie specifique SIN")
    expect(page).to have_button("Sujet complet")
    expect(page).to have_content("12 points")
    expect(page).to have_content("8 points")
    expect(page).to have_content("20 points")
  end

  scenario "student chooses 'Partie commune' and sees only common questions" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)
    click_button "Partie commune"

    # Should redirect to mise en situation, then start questions
    expect(page).to have_content("MISE EN SITUATION")
    click_link "Commencer les questions"

    # Should see common question
    expect(page).to have_content("Question commune sur le transport durable")

    # Navigate — should only show common questions, not specific
    click_link "Question suivante"
    expect(page).to have_content("Deuxieme question commune")

    # Last question in common scope — should show "Retour aux sujets" not another question
    expect(page).not_to have_link("Question suivante")
    expect(page).to have_link("Retour aux sujets")
  end

  scenario "student chooses 'Sujet complet' and sees all questions" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)
    click_button "Sujet complet"

    # Should see mise en situation with all parts listed
    expect(page).to have_content("Partie commune transport")
    expect(page).to have_content("Partie specifique SIN")

    click_link "Commencer les questions"

    # Should see first common question
    expect(page).to have_content("Question commune sur le transport durable")
  end

  scenario "legacy subject (no exam_session) skips scope selection" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: legacy_subject.id)

    # Should go directly to mise en situation, no scope selection
    expect(page).not_to have_content("Choisissez votre perimetre de travail")
    expect(page).to have_content("MISE EN SITUATION")
    expect(page).to have_link("Commencer les questions")

    click_link "Commencer les questions"
    expect(page).to have_content("Question du sujet legacy")
  end

  scenario "student with scope selected sees 'Changer de perimetre' option" do
    # Pre-select scope
    session_record = create(:student_session,
      student: student,
      subject: new_format_subject,
      part_filter: :common_only,
      scope_selected: true)

    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)

    # Should see scope indicator and change link
    expect(page).to have_content("Partie commune (12 pts, 2h30)")
    expect(page).to have_button("Changer de perimetre")
  end
end

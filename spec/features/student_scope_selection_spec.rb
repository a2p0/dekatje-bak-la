require "rails_helper"

RSpec.describe "US4: Student scope selection (perimetre de travail)", type: :feature do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom) }

  # --- New-format subject (with exam_session) ---
  let(:exam_session) do
    create(:exam_session, owner: teacher, title: "BAC STI2D 2025", common_presentation: "Mise en situation CIME.")
  end

  let(:new_format_subject) do
    create(:subject, :new_format,
      status: :published,
      specialty: :SIN,
      exam_session: exam_session,
      owner: teacher,
      specific_presentation: "Presentation specifique SIN")
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

  # --- Subject without common parts (no scope selection needed) ---
  let(:legacy_exam_session) do
    create(:exam_session, owner: teacher, title: "BAC Legacy 2025",
      common_presentation: "Sujet classique sans parties communes")
  end
  let(:legacy_subject) do
    create(:subject,
      status: :published,
      specialty: :SIN,
      owner: teacher,
      exam_session: legacy_exam_session)
  end

  let!(:legacy_part) do
    create(:part, :specific,
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
    # Should see the scope selection instead of parts list
    expect(page).to have_content("Quel périmètre veux-tu réviser")
    expect(page).to have_content("Tronc commun seul")
    expect(page).to have_content("Spécifique SIN seul")
    expect(page).to have_content("TC + Spécifique SIN")
    expect(page).to have_content("12 pts")
    expect(page).to have_content("8 pts")
    expect(page).to have_content("20 pts")
  end

  scenario "student chooses 'Tronc commun seul' and sees only common questions" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)
    find("button[data-value='common_only']").click
    click_button "Commencer →"

    # Should see common question
    expect(page).to have_content("Question commune sur le transport durable")

    # Navigate — should only show common questions, not specific
    click_link "Question suivante"
    expect(page).to have_content("Deuxieme question commune")

    # Last question in common scope — should show "Fin de la partie commune" not another question
    expect(page).not_to have_link("Question suivante")
    expect(page).to have_button("Fin de la partie commune")
  end

  scenario "student chooses 'TC + Specifique' and sees all questions" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)
    find("button[data-value='full']").click
    click_button "Commencer →"

    # Should see first common question
    expect(page).to have_content("Question commune sur le transport durable")
  end

  scenario "subject without common parts skips scope selection" do
    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: legacy_subject.id)

    # Should go directly to parts list, no scope selection
    expect(page).not_to have_content("Quel périmètre veux-tu réviser")
    expect(page).to have_content("Partie unique")
    expect(page).to have_content("Continuer la partie")
  end

  scenario "student with scope selected sees scope summary on parts list" do
    # Pre-select scope
    create(:student_session,
      student: student,
      subject: new_format_subject,
      part_filter: :common_only,
      scope_selected: true)

    login_as_student(student, classroom)

    visit student_subject_path(access_code: classroom.access_code, id: new_format_subject.id)

    # Should see scope-filtered parts list (common parts only, no scope selection screen)
    expect(page).not_to have_content("Quel périmètre veux-tu réviser")
    expect(page).to have_content("Partie commune transport")
  end
end

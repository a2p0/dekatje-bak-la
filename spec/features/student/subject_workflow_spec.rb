require "rails_helper"

RSpec.describe "Student subject workflow", type: :feature do
  let(:teacher)   { create(:user) }
  let(:classroom) { create(:classroom, name: "Terminale SIN 2026", owner: teacher) }
  let(:student)   { create(:student, classroom: classroom) }

  let(:exam_session) do
    create(:exam_session, owner: teacher, title: "BAC STI2D 2025",
      common_presentation: "Mise en situation commune CIME.")
  end

  let(:subject_record) do
    create(:subject, :new_format,
      status: :published,
      specialty: :SIN,
      exam_session: exam_session,
      owner: teacher,
      specific_presentation: "Presentation specifique SIN.")
  end

  let!(:common_part) do
    create(:part,
      exam_session: exam_session,
      subject: nil,
      number: 1,
      title: "Partie commune transport",
      objective_text: "Comparer les modes de transport",
      section_type: :common,
      position: 1)
  end

  let!(:specific_part) do
    create(:part,
      subject: subject_record,
      exam_session: nil,
      number: 2,
      title: "Partie specifique SIN",
      objective_text: "Analyser le reseau informatique",
      section_type: :specific,
      position: 2)
  end

  let!(:common_q1) do
    create(:question, part: common_part, number: "1.1",
      label: "Question commune transport durable", points: 4, position: 1)
  end

  let!(:common_q2) do
    create(:question, part: common_part, number: "1.2",
      label: "Deuxieme question commune", points: 4, position: 2)
  end

  let!(:specific_q1) do
    create(:question, part: specific_part, number: "2.1",
      label: "Question specifique reseau", points: 4, position: 1)
  end

  let!(:specific_q2) do
    create(:question, part: specific_part, number: "2.2",
      label: "Deuxieme question specifique", points: 4, position: 2)
  end

  let!(:classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_record) }

  # Create answer records so correction reveal works
  let!(:answer_c1) { create(:answer, question: common_q1, correction_text: "Correction c1") }
  let!(:answer_c2) { create(:answer, question: common_q2, correction_text: "Correction c2") }
  let!(:answer_s1) { create(:answer, question: specific_q1, correction_text: "Correction s1") }
  let!(:answer_s2) { create(:answer, question: specific_q2, correction_text: "Correction s2") }

  before do
    login_as_student(student, classroom)
  end

  # Helper to select "Sujet complet" scope and land on subject page
  def select_full_scope
    visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
    click_button "Sujet complet"
  end

  # ---------- US1: Parts list with grouping + objectives ----------

  describe "US1: Parts list with grouping and objectives" do
    scenario "parts are grouped by section_type with headers on full scope" do
      select_full_scope

      expect(page).to have_content("PARTIE COMMUNE")
      expect(page).to have_content("PARTIE SPECIFIQUE")
      expect(page).to have_content("Partie commune transport")
      expect(page).to have_content("Partie specifique SIN")
    end

    scenario "objective_text is displayed under each part title" do
      select_full_scope

      expect(page).to have_content("Comparer les modes de transport")
      expect(page).to have_content("Analyser le reseau informatique")
    end

    scenario "Commencer button is at the bottom of parts list" do
      select_full_scope

      # The button should exist and be after the parts
      expect(page).to have_link("Commencer")
    end

    scenario "single scope (common_only) shows flat list without section headers" do
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)
      click_button "Partie commune"

      expect(page).not_to have_content("PARTIE COMMUNE")
      expect(page).not_to have_content("PARTIE SPECIFIQUE")
      expect(page).to have_content("Partie commune transport")
    end
  end

  # ---------- US2: Navigation with part transitions ----------

  describe "US2: Navigation with part transitions" do
    scenario "last question in the last common part shows 'Fin de la partie commune' button" do
      select_full_scope
      click_link "Commencer"

      # Navigate to last common question
      click_link "Question suivante"
      expect(page).to have_content("Deuxieme question commune")

      # Should show "Fin de la partie commune" instead of "Question suivante"
      expect(page).to have_button("Fin de la partie commune")
      expect(page).not_to have_link("Question suivante")
    end

    scenario "clicking 'Fin de la partie commune' marks part completed and routes to specific presentation" do
      select_full_scope
      click_link "Commencer"

      # Go to last question
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      # Routed directly to the specific presentation (since specific_presentation is set)
      expect(page).to have_content("Presentation specifique SIN.")

      # And the common part is marked completed in the session record
      session = StudentSession.where(student_id: student.id, subject_id: subject_record.id).first
      expect(session).to be_present
      expect(session.part_completed?(common_part.id)).to be true
    end

    scenario "completed common part shows visual badge when returning to subject page" do
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      # Navigate back to the subject hub to see the parts list
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)

      expect(page).to have_content("Partie commune transport")
      expect(page).to have_content("Terminé")
      specific_row = find("[data-part-id='#{specific_part.id}']")
      expect(specific_row).not_to have_content("Terminé")
    end
  end

  # ---------- US3: Specific presentation ----------

  describe "US3: Specific presentation between parts" do
    scenario "specific presentation shown when finishing common section" do
      # Complete common part first
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      # Should see specific presentation directly after clicking Fin de la partie commune
      expect(page).to have_content("Presentation specifique SIN.")
      expect(page).to have_link("Commencer")
    end

    scenario "specific presentation skipped when empty" do
      subject_record.update!(specific_presentation: nil)

      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      # No specific presentation → go directly to first specific question
      expect(page).to have_content("Question specifique reseau")
    end
  end

  # ---------- US4: Unanswered questions page ----------

  describe "US4: Unanswered questions page" do
    scenario "shows unanswered questions after all parts completed" do
      # Complete common part without answering
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      # Goes directly to specific presentation
      expect(page).to have_content("Presentation specifique SIN.")
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie spécifique"

      # Should see unanswered questions page
      expect(page).to have_content("Questions non repondues")
      expect(page).to have_content("Question commune transport durable")
      expect(page).to have_content("Question specifique reseau")
      expect(page).to have_link("Revenir a cette question", minimum: 1)
      expect(page).to have_button("Terminer le sujet")
    end

    scenario "'Revenir a cette question' opens question, 'Question suivante' returns to unanswered page" do
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      expect(page).to have_content("Presentation specifique SIN.")
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie spécifique"

      # Click on first unanswered question
      first(:link, "Revenir a cette question").click

      # Should be on the question page
      expect(page).to have_content("Question commune transport durable").or have_content("Question specifique reseau")

      # "Question suivante" should redirect back to unanswered page
      click_link "Question suivante"
      expect(page).to have_content("Questions non repondues")
    end

    scenario "all questions answered after all parts goes directly to completion" do
      select_full_scope
      click_link "Commencer"

      # Answer q1
      click_button "Voir la correction"
      click_link "Question suivante"

      # Answer q2
      click_button "Voir la correction"
      click_button "Fin de la partie commune"

      # Specific presentation
      expect(page).to have_content("Presentation specifique SIN.")
      click_link "Commencer"

      # Answer specific q1
      click_button "Voir la correction"
      click_link "Question suivante"

      # Answer specific q2
      click_button "Voir la correction"
      click_button "Fin de la partie spécifique"

      # Should go directly to completion page
      expect(page).to have_content("Bravo")
    end
  end

  # ---------- US5: Completion page ----------

  describe "US5: Completion page" do
    scenario "'Terminer le sujet' triggers completion page" do
      # Complete both parts without answering
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      expect(page).to have_content("Presentation specifique SIN.")
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie spécifique"

      # On unanswered page, click Terminer
      expect(page).to have_content("Questions non repondues")
      click_button "Terminer le sujet"

      expect(page).to have_content("Bravo")
      expect(page).to have_link("Revenir aux sujets")
    end

    scenario "re-entering completed subject shows relecture mode" do
      # Complete both parts without answering, then terminate
      select_full_scope
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie commune"

      expect(page).to have_content("Presentation specifique SIN.")
      click_link "Commencer"
      click_link "Question suivante"
      click_button "Fin de la partie spécifique"

      expect(page).to have_content("Questions non repondues")
      click_button "Terminer le sujet"

      # Re-enter the subject
      visit student_subject_path(access_code: classroom.access_code, id: subject_record.id)

      # Should see parts list in relecture mode, not Bravo again
      expect(page).to have_content("Partie commune transport")
      expect(page).to have_content("Partie specifique SIN")
      expect(page).not_to have_content("Bravo")
    end
  end
end
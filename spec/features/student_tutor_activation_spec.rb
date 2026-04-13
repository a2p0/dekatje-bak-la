require "rails_helper"

RSpec.xdescribe "Student tutor activation banner", type: :feature do
  let(:classroom) { create(:classroom) }
  let(:subject_obj) { create(:subject, status: :published) }
  let!(:_classroom_subject) { create(:classroom_subject, classroom: classroom, subject: subject_obj) }
  let(:part) { create(:part, :specific, subject: subject_obj, position: 1) }
  let!(:first_question) { create(:question, part: part, position: 1) }

  # Uses login_as_student from StudentLoginHelper (included via spec/support/)

  def visit_subject
    visit student_subject_path(access_code: classroom.access_code, id: subject_obj.id)
  end

  context "when student is autonomous with an API key" do
    let(:student) do
      s = create(:student, classroom: classroom)
      # Set API key directly to avoid encryption issues in CI
      s.update!(api_key: "sk-test-key", api_provider: :openrouter)
      s
    end
    let!(:student_session) do
      create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
    end

    before do
      login_as_student(student, classroom)
      visit_subject
    end

    it "shows the tutor activation banner" do
      expect(page).to have_css("[data-testid='tutor-banner']")
      expect(page).to have_button("Activer le mode tuteur")
    end

    it "activates tutored mode when clicking the button" do
      click_button "Activer le mode tuteur"

      # Wait for redirect to complete
      expect(page).not_to have_css("[data-testid='tutor-banner']")
      student_session.reload
      expect(student_session.mode).to eq("tutored")
    end

    it "no longer shows the banner after activation" do
      click_button "Activer le mode tuteur"

      expect(page).not_to have_css("[data-testid='tutor-banner']")
    end
  end

  context "when student is autonomous without an API key" do
    let(:student) { create(:student, classroom: classroom, api_key: nil) }
    let!(:student_session) do
      create(:student_session, student: student, subject: subject_obj, mode: :autonomous)
    end

    before do
      login_as_student(student, classroom)
      visit_subject
    end

    it "does not show the tutor activation banner" do
      expect(page).not_to have_css("[data-testid='tutor-banner']")
    end
  end

  context "when student is already in tutored mode" do
    let(:student) { create(:student, classroom: classroom, api_key: "sk-test-key") }
    let!(:student_session) do
      create(:student_session, student: student, subject: subject_obj, mode: :tutored)
    end

    before do
      login_as_student(student, classroom)
      visit_subject
    end

    it "does not show the tutor activation banner" do
      expect(page).not_to have_css("[data-testid='tutor-banner']")
    end
  end
end

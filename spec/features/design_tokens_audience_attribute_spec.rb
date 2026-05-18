require "rails_helper"

# FR-015 — verifies the data-audience attribute is set on the <body> tag
# of each layout (student / teacher / public).
RSpec.describe "Design tokens: data-audience attribute on layouts", type: :feature do
  context "public layout (application.html.erb)" do
    scenario "home page exposes data-audience='public' on body" do
      visit root_path
      expect(page).to have_css('body[data-audience="public"]', visible: :all)
    end

    scenario "legal page exposes data-audience='public' on body" do
      visit legal_path
      expect(page).to have_css('body[data-audience="public"]', visible: :all)
    end
  end

  context "student layout (student.html.erb)" do
    let(:classroom) { create(:classroom) }
    let(:student)   { create(:student, classroom: classroom) }

    scenario "student-authenticated page exposes data-audience='student' on body" do
      login_as_student(student, classroom)
      # login_as_student already lands on student_root_path
      expect(page).to have_css('body[data-audience="student"]', visible: :all)
    end
  end

  context "teacher layout (teacher.html.erb)" do
    let(:user) { create(:user, confirmed_at: Time.current) }

    scenario "teacher-authenticated page exposes data-audience='teacher' on body" do
      visit new_user_session_path
      fill_in "Email",    with: user.email
      fill_in "Password", with: "password123"
      click_button "Se connecter"
      expect(page).to have_current_path(teacher_root_path)
      expect(page).to have_css('body[data-audience="teacher"]', visible: :all)
    end
  end
end

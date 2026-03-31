module StudentLoginHelper
  def login_as_student(student, classroom)
    visit student_login_path(access_code: classroom.access_code)
    fill_in "Identifiant", with: student.username
    fill_in "Mot de passe", with: "password123"
    click_button "Se connecter"
    # Wait for redirect to complete before continuing
    expect(page).to have_current_path(student_root_path(access_code: classroom.access_code))
  end
end

RSpec.configure do |config|
  config.include StudentLoginHelper, type: :feature
end

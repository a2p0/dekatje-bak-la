require "rails_helper"

RSpec.describe "Teacher downloads credentials PDF from generated banner", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
  end

  scenario "le bandeau d'identifiants générés expose un bouton de téléchargement PDF" do
    classroom = create(:classroom, owner: user)

    sign_in_teacher(user)
    visit teacher_classroom_path(classroom)
    click_link "Ajouter un élève"

    fill_in "Prénom", with: "Jean"
    fill_in "Nom", with: "Dupont"
    click_button "Ajouter l'élève"

    expect(page).to have_content("Identifiants générés")

    within("#generated-credentials") do
      expect(page).to have_link(
        "Télécharger la fiche PDF",
        href: teacher_classroom_export_path(classroom, format: :pdf)
      )
    end
  end
end

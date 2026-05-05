require "rails_helper"

RSpec.describe "Teacher downloads credentials PDF from generated banner", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  scenario "le bandeau d'identifiants générés expose un bouton de téléchargement PDF" do
    classroom = create(:classroom, owner: user)

    login_as(user, scope: :user)
    visit teacher_classroom_path(classroom)
    find("a", text: "Ajouter un élève", wait: 5).click

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

require "rails_helper"

RSpec.describe "Pages légales", type: :feature do
  scenario "un visiteur accède aux mentions légales depuis la page d'accueil" do
    visit root_path

    click_link "Mentions légales"

    expect(page).to have_content("Mentions légales")
    expect(page).to have_content("Éditeur du site")
    expect(page).to have_content("Hébergement")
    expect(page).to have_link("politique de confidentialité")
    expect(page).to have_link("Retour à l'accueil")
  end

  scenario "un visiteur accède à la politique de confidentialité depuis la page d'accueil" do
    visit root_path

    click_link "Confidentialité"

    expect(page).to have_content("Politique de confidentialité")
    expect(page).to have_content("Responsable du traitement")
    expect(page).to have_content("Données collectées")
    expect(page).to have_content("Services tiers")
    expect(page).to have_content("Vos droits")
    expect(page).to have_content("CNIL")
    expect(page).to have_link("Retour à l'accueil")
  end

  scenario "un visiteur navigue entre les pages légales et revient à l'accueil" do
    visit legal_path

    click_link "politique de confidentialité"
    expect(page).to have_content("Politique de confidentialité")

    click_link "Retour à l'accueil"
    expect(page).to have_content("DekatjeBakLa")
    expect(page).to have_field("Code d'accès")
  end
end
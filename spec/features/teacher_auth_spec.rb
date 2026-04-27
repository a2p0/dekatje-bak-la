require "rails_helper"

RSpec.describe "Story 1: Inscription et connexion enseignant", type: :feature do
  scenario "un enseignant s'inscrit avec prénom, nom, email et mot de passe" do
    visit new_user_registration_path

    fill_in "Prénom", with: "Jean"
    fill_in "Nom", with: "Dupont"
    fill_in "Email", with: "jean@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "S'inscrire"

    expect(page).to have_content("confirmation")
    expect(User.last.first_name).to eq("Jean")
    expect(User.last.last_name).to eq("Dupont")
  end

  scenario "un enseignant confirme son email et se connecte" do
    user = create(:user, confirmed_at: nil)
    user.send_confirmation_instructions
    token = user.confirmation_token

    visit user_confirmation_path(confirmation_token: token)

    expect(user.reload.confirmed?).to be true
  end

  scenario "un enseignant confirmé se connecte et arrive sur le dashboard" do
    user = create(:user, confirmed_at: Time.current)

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("Mes classes")
  end

  scenario "un enseignant se déconnecte" do
    user = create(:user, confirmed_at: Time.current)

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Se connecter"

    expect(page).to have_content("Mes classes")

    # The "Déconnexion" link uses data-turbo-method="delete".
    # Submit a DELETE form via JS to avoid timing issues with Turbo loading.
    page.execute_script(<<~JS)
      const form = document.createElement('form');
      form.method = 'POST';
      form.action = '#{destroy_user_session_path}';
      const method = document.createElement('input');
      method.type = 'hidden'; method.name = '_method'; method.value = 'delete';
      form.appendChild(method);
      const token = document.querySelector('meta[name="csrf-token"]');
      if (token) {
        const csrf = document.createElement('input');
        csrf.type = 'hidden'; csrf.name = 'authenticity_token'; csrf.value = token.content;
        form.appendChild(csrf);
      }
      document.body.appendChild(form);
      form.submit();
    JS

    expect(page).to have_current_path(root_path, wait: 10)
  end

  scenario "un visiteur non connecté est redirigé vers le login" do
    visit teacher_root_path

    expect(page).to have_current_path(new_user_session_path)
  end
end

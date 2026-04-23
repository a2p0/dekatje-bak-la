require "rails_helper"

RSpec.describe "Story 2: Gestion des classes et des eleves", type: :feature do
  let(:user) { create(:user, confirmed_at: Time.current) }

  def sign_in_teacher(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"
    expect(page).to have_content("Mes classes")
  end

  scenario "un enseignant cree une classe avec nom, annee et specialite" do
    sign_in_teacher(user)

    click_link "Nouvelle classe"

    fill_in "Nom de la classe", with: "Terminale ITEC"
    fill_in "Année scolaire", with: "2026"
    fill_in "Spécialité", with: "ITEC"
    click_button "Créer la classe"

    expect(page).to have_content("Classe créée avec succès")
    expect(page).to have_content("Terminale ITEC")
    expect(page).to have_content("2026")
    expect(page).to have_content("Code d'accès")

    classroom = Classroom.last
    expect(classroom.access_code).to be_present
    expect(classroom.owner).to eq(user)
  end

  scenario "la classe creee apparait dans la liste avec son code d'acces et nombre d'eleves" do
    classroom = create(:classroom, owner: user, name: "Terminale SIN", school_year: "2026")
    create_list(:student, 3, classroom: classroom)

    sign_in_teacher(user)

    expect(page).to have_content("Terminale SIN")
    expect(page).to have_content("2026")
    expect(page).to have_content("3 élèves")
  end

  scenario "un enseignant ajoute un eleve et voit les identifiants generes" do
    classroom = create(:classroom, owner: user)

    sign_in_teacher(user)
    click_link "Voir →"

    click_link "Ajouter un élève"

    fill_in "Prénom", with: "Jean"
    fill_in "Nom", with: "Dupont"
    click_button "Ajouter l'élève"

    expect(page).to have_content("Élève ajouté")
    expect(page).to have_content("Identifiants générés")

    within("#generated-credentials") do
      expect(page).to have_content("Jean Dupont")
      expect(page).to have_content("jean.dupont")
    end

    student = Student.last
    expect(student.username).to eq("jean.dupont")
    expect(student.first_name).to eq("Jean")
    expect(student.last_name).to eq("Dupont")
  end

  scenario "les identifiants generes ne sont affiches qu'une seule fois" do
    classroom = create(:classroom, owner: user)

    sign_in_teacher(user)
    click_link "Voir →"
    click_link "Ajouter un élève"

    fill_in "Prénom", with: "Marie"
    fill_in "Nom", with: "Martin"
    click_button "Ajouter l'élève"

    expect(page).to have_content("Identifiants générés")

    # Reload the page — credentials should disappear
    visit current_path

    expect(page).not_to have_content("Identifiants générés")
  end

  scenario "un doublon de nom recoit un suffixe numerique" do
    classroom = create(:classroom, owner: user)
    create(:student, classroom: classroom, first_name: "Jean", last_name: "Dupont", username: "jean.dupont")

    sign_in_teacher(user)
    click_link "Voir →"
    click_link "Ajouter un élève"

    fill_in "Prénom", with: "Jean"
    fill_in "Nom", with: "Dupont"
    click_button "Ajouter l'élève"

    expect(page).to have_content("Élève ajouté")

    within("#generated-credentials") do
      expect(page).to have_content("jean.dupont2")
    end

    expect(Student.where(username: "jean.dupont2")).to exist
  end

  scenario "un enseignant ajoute des eleves en masse" do
    classroom = create(:classroom, owner: user)

    sign_in_teacher(user)
    click_link "Voir →"
    click_link "Ajout en lot"

    fill_in "Liste des élèves", with: "Pierre Bernard\nSophie Leroy\nLuc Moreau"
    click_button "Créer les comptes"

    expect(page).to have_content("3 élèves ajoutés")
    expect(page).to have_content("Identifiants générés")

    within("#generated-credentials") do
      expect(page).to have_content("Pierre Bernard")
      expect(page).to have_content("pierre.bernard")
      expect(page).to have_content("Sophie Leroy")
      expect(page).to have_content("sophie.leroy")
      expect(page).to have_content("Luc Moreau")
      expect(page).to have_content("luc.moreau")
    end

    expect(Student.count).to eq(3)
  end

  scenario "un enseignant reinitialise le mot de passe d'un eleve" do
    classroom = create(:classroom, owner: user)
    student = create(:student, classroom: classroom, first_name: "Alice", last_name: "Blanc", username: "alice.blanc")

    sign_in_teacher(user)
    click_link "Voir →"

    expect(page).to have_content("alice.blanc")

    click_button "Réinitialiser mot de passe"

    expect(page).to have_content("Mot de passe réinitialisé")
    expect(page).to have_content("Identifiants générés")

    within("#generated-credentials") do
      expect(page).to have_content("Alice Blanc")
      expect(page).to have_content("alice.blanc")
    end
  end

  scenario "un enseignant exporte les fiches de connexion en PDF" do
    classroom = create(:classroom, owner: user)
    create(:student, classroom: classroom, first_name: "Emma", last_name: "Duval", username: "emma.duval")

    sign_in_teacher(user)
    click_link "Voir →"
    expect(page).to have_link("Exporter fiches PDF", href: teacher_classroom_export_path(classroom, format: :pdf))
  end

  scenario "le tableau de bord affiche le nombre d'eleves et le code d'acces pour chaque classe" do
    classroom1 = create(:classroom, owner: user, name: "Terminale SIN", school_year: "2026")
    classroom2 = create(:classroom, owner: user, name: "Terminale ITEC", school_year: "2026")
    create_list(:student, 5, classroom: classroom1)
    create_list(:student, 2, classroom: classroom2)

    sign_in_teacher(user)

    expect(page).to have_content("Terminale SIN")
    expect(page).to have_content("5 élèves")
    expect(page).to have_content("Terminale ITEC")
    expect(page).to have_content("2 élèves")

    # Verify access codes are visible on each classroom's show page
    within(find(".rounded-xl.overflow-hidden", text: "Terminale SIN")) { click_link "Voir →" }
    expect(page).to have_content("Code d'accès")
    expect(page).to have_content(classroom1.access_code)
  end
end

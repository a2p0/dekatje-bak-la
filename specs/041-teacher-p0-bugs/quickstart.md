# Quickstart — Teacher P0 bug fixes

**Feature** : Teacher P0 bug fixes
**Branch** : `041-teacher-p0-bugs`
**Date** : 2026-04-16

## Ordre d'implémentation recommandé

3 stories indépendantes, chacune testable seule. On suit l'ordre de priorité P1/P1/P2 avec une commit par story.

```
US1 (P0-a) → US2 (P0-b) → US3 (P0-c) → PR
```

## US1 — Bouton téléchargement PDF dans bandeau credentials

**Fichier** : `app/views/teacher/classrooms/show.html.erb`

**Modification** : dans le bloc `if @generated_credentials.present?` (ligne 18-51), ajouter un bouton primary juste après le `<h2>` ou après la table. Simple, 1 ajout.

```erb
<%= render ButtonComponent.new(
      href: teacher_classroom_export_path(@classroom, format: :pdf),
      variant: :primary, size: :sm) do %>
  Télécharger la fiche PDF
<% end %>
```

**Test** : `spec/features/teacher/classroom_credentials_download_spec.rb`

```ruby
require 'rails_helper'

RSpec.feature "Teacher downloads generated credentials PDF", :js do
  scenario "bouton visible et lié à l'export PDF" do
    teacher = create(:user)
    classroom = create(:classroom, owner: teacher)
    sign_in teacher

    page.set_rack_session(generated_credentials: [
      { "name" => "Jean Dupont", "username" => "jean.dupont", "password" => "abc123" }
    ])
    visit teacher_classroom_path(classroom)

    expect(page).to have_link("Télécharger la fiche PDF",
      href: teacher_classroom_export_path(classroom, format: :pdf))
  end
end
```

**Commit** : `feat(teacher): add credentials PDF download button in generated banner`

---

## US2 — Action destroy pour Subject

### 1. Route (config/routes.rb:17)

```diff
- resources :subjects, only: [ :index, :new, :create, :show ] do
+ resources :subjects, only: [ :index, :new, :create, :show, :destroy ] do
```

### 2. Controller (app/controllers/teacher/subjects_controller.rb)

Modifications :

```ruby
class Teacher::SubjectsController < Teacher::BaseController
  before_action :set_subject, only: [ :show, :destroy ]

  # ... (index, new, create, show inchangés) ...

  def destroy
    @subject.update!(discarded_at: Time.current)
    redirect_to teacher_subjects_path,
                notice: "Sujet « #{@subject.exam_session&.title || 'sans titre'} » archivé."
  end

  private

  def set_subject
    @subject = current_teacher.subjects.kept.find_by(id: params[:id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  # ... rest unchanged ...
end
```

### 3. Vue (app/views/teacher/subjects/show.html.erb)

Ajouter juste après le lien "← Retour aux sujets" (ligne 107), un `button_to` discret de type lien rouge — style cohérent avec la "Supprimer la session" existante (ligne 40) :

```erb
<div class="mt-6 flex items-center justify-between">
  <%= render ButtonComponent.new(href: teacher_subjects_path, variant: :ghost, size: :sm) do %>
    ← Retour aux sujets
  <% end %>

  <%= button_to "Archiver le sujet",
        teacher_subject_path(@subject),
        method: :delete,
        form: { data: { turbo_confirm: "Archiver ce sujet ? Il disparaîtra de votre liste." } },
        class: "text-sm text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 underline underline-offset-2" %>
</div>
```

### 4. Tests

**Request spec** : `spec/requests/teacher/subjects_controller_spec.rb`

```ruby
describe "DELETE /teacher/subjects/:id" do
  it "archives the subject and redirects" do
    teacher = create(:user)
    subject = create(:subject, owner: teacher)
    sign_in teacher

    delete teacher_subject_path(subject)

    expect(response).to redirect_to(teacher_subjects_path)
    expect(subject.reload.discarded_at).not_to be_nil
  end

  it "returns 404 redirect if not owner" do
    other = create(:user)
    subject = create(:subject, owner: other)
    sign_in create(:user)

    delete teacher_subject_path(subject)

    expect(response).to redirect_to(teacher_subjects_path)
    expect(flash[:alert]).to match(/introuvable/)
    expect(subject.reload.discarded_at).to be_nil
  end

  it "is idempotent on already-archived subject" do
    teacher = create(:user)
    subject = create(:subject, owner: teacher, discarded_at: 1.day.ago)
    sign_in teacher

    delete teacher_subject_path(subject)

    expect(response).to redirect_to(teacher_subjects_path)
    expect(flash[:alert]).to match(/introuvable/)
  end
end
```

**Feature spec** : `spec/features/teacher/subject_archive_spec.rb`

```ruby
require 'rails_helper'

RSpec.feature "Teacher archives a subject", :js do
  scenario "archive via bouton + confirmation" do
    teacher = create(:user)
    subject = create(:subject, owner: teacher)
    sign_in teacher

    visit teacher_subject_path(subject)

    accept_confirm do
      click_button "Archiver le sujet"
    end

    expect(page).to have_current_path(teacher_subjects_path)
    expect(page).to have_text(/archivé/)
    expect(page).not_to have_text(subject.title)
  end
end
```

**Commit** : `feat(teacher): add soft-delete archive action for subjects`

---

## US3 — Indication temporelle extraction

**Fichier** : `app/views/teacher/subjects/_extraction_status.html.erb`

**Modifications** :

1. Ligne 2 — ajouter `aria-live="polite"` et `aria-atomic="true"` sur le div racine :

```diff
- <div id="extraction-status">
+ <div id="extraction-status" aria-live="polite" aria-atomic="true">
```

2. Ligne 41 — ajouter la mention temporelle à la phrase "Extraction en cours…" :

```diff
- Extraction en cours…
+ Extraction en cours…
+ <% if job.updated_at %>
+   <span class="text-slate-500 dark:text-slate-400">démarrée il y a <%= time_ago_in_words(job.updated_at) %></span>
+ <% end %>
```

(placer le span dans la ligne `<p>` existante)

**Test** : `spec/features/teacher/extraction_status_feedback_spec.rb`

```ruby
require 'rails_helper'

RSpec.feature "Teacher sees extraction feedback with elapsed time" do
  scenario "processing job shows relative time and aria-live" do
    teacher = create(:user)
    subject = create(:subject, owner: teacher)
    job = create(:extraction_job, subject: subject, status: :processing)

    # Force updated_at to 45 seconds ago
    job.update_columns(updated_at: 45.seconds.ago)

    sign_in teacher
    visit teacher_subject_path(subject)

    expect(page).to have_css('#extraction-status[aria-live="polite"]')
    expect(page).to have_text(/démarrée il y a/)
  end

  scenario "graceful fallback if updated_at is nil (edge case)" do
    # Très improbable en pratique, test défensif
    teacher = create(:user)
    subject = create(:subject, owner: teacher)
    job = create(:extraction_job, subject: subject, status: :processing)

    # On ne peut pas mettre updated_at à nil en Rails normal, donc on stub
    allow_any_instance_of(ExtractionJob).to receive(:updated_at).and_return(nil)

    sign_in teacher
    visit teacher_subject_path(subject)

    expect(page).to have_text(/Extraction en cours/)
    expect(page).not_to have_text(/démarrée il y a/)
  end
end
```

**Commit** : `feat(teacher): show elapsed time and aria-live for extraction status`

---

## Synthèse commits

| # | Type | Scope | Description |
|---|---|---|---|
| 1 | `feat` | `teacher` | `add credentials PDF download button in generated banner` |
| 2 | `feat` | `teacher` | `add soft-delete archive action for subjects` |
| 3 | `feat` | `teacher` | `show elapsed time and aria-live for extraction status` |

**PR** : créer une PR `041-teacher-p0-bugs` → `main` après les 3 commits + CI verte.

## Vérifications avant PR

- [ ] Les 3 tests feature/request passent localement sur machine CI (pas en local machine dev — constitution IV).
- [ ] `rubocop` propre.
- [ ] Pas de régression sur les specs existantes de `Teacher::SubjectsController` (index, show, create).
- [ ] Le bouton "Télécharger la fiche PDF" fonctionne visuellement (QA manuelle ou screenshot).
- [ ] Le sujet archivé disparaît bien de `/teacher/subjects` et de `/teacher/` (dashboard recent_subjects).
- [ ] Le texte relatif s'affiche bien dans la vue sujet pendant extraction.

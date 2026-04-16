# Phase 0 — Research

**Feature** : Teacher P0 bug fixes
**Branch** : `041-teacher-p0-bugs`
**Date** : 2026-04-16

## R1 — Export PDF classe (US1)

**Question** : le service d'export PDF utilisé par le bouton actuel "Exporter fiches PDF" (`classrooms/show.html.erb:69`) est-il réutilisable en l'état pour un deuxième point d'entrée dans le bandeau d'identifiants ?

**Decision** : OUI, réutilisation directe de `teacher_classroom_export_path(@classroom, format: :pdf)` déjà présent dans le template. Aucune modification du service `Teacher::Classrooms::ExportsController#show` ni du générateur PDF.

**Rationale** : la route existe, la vue existe, le contrôleur gère déjà le format `:pdf`. Ajouter un bouton supplémentaire pointant sur la même route = zero-risk, conforme au principe "Always prefer simple, readable code" de la constitution (V).

**Alternatives considered** :
- Générer un PDF restreint aux *seuls* élèves nouvellement créés (ceux du bandeau) plutôt que toute la classe : **rejeté**. Le bandeau `@generated_credentials` contient juste `[{name, username, password}]` sans lien DB robuste vers les Student records (session.delete), et le but de la story est de sauver les mots de passe avant perte — le PDF de toute la classe inclut forcément ces élèves puisqu'ils viennent d'être créés. Scope α = minimal.

---

## R2 — Soft-delete Subject (US2)

**Question** : comment implémenter `destroy` sur `Subject` sans introduire de gem, tout en respectant la colonne `discarded_at` et le scope `kept` existants ?

**Decision** : implémentation maison simple sans dépendance — l'action `destroy` appelle `@subject.update!(discarded_at: Time.current)`. Le scope `kept -> { where(discarded_at: nil) }` existe déjà dans `app/models/subject.rb:32` et est utilisé dans `SubjectsController#index` (`current_teacher.subjects.kept.includes(:exam_session)`) ainsi que `classrooms_controller#index` (`@recent_subjects = current_teacher.subjects.kept.order(...)`).

**Rationale** :
- **Pas de gem** : le projet n'inclut pas `discard` dans le Gemfile (vérifié). Le pattern maison est déjà installé (colonne + scope). Ajouter une gem pour 1 ligne de code serait de la sur-ingénierie.
- **Cohérence** : `Question` a aussi un scope `kept` (`Question.kept`) — même pattern dans tout le projet.
- **Idempotence** : `update!` lève une exception si validation échoue ; un sujet déjà archivé sera protégé via `set_subject` qui filtre par `current_teacher.subjects` sans scope `kept` sur les autres actions. Pour `destroy`, on peut soit : (a) utiliser `current_teacher.subjects.kept.find_by(id: params[:id])` (idempotent — re-archivage silencieux retourne 404), (b) utiliser `current_teacher.subjects.find_by(...)` sans filtre kept et idempotent au niveau DB. **Choix (a)** pour cohérence avec les autres actions REST et retour 404 standard.

**Alternatives considered** :
- Gem `discard` : rejeté (dépendance inutile, pattern maison déjà établi).
- Hard-delete avec `dependent: :destroy` : rejeté (perte de données irréversible, cascade à travers Part/Question/ExamSession/ClassroomSubject/StudentSession — trop risqué pour scope α).
- Enum `status: archived` (déjà présent dans `Subject`) : rejeté car **conflit sémantique** — l'enum `archived` est pour le cycle de vie pédagogique (draft → pending_validation → published → archived). Utiliser `discarded_at` pour le soft-delete utilisateur est cohérent avec les autres modèles (`Question.kept`) et évite d'emprunter un state déjà utilisé par `Subject#publish!`.

---

## R3 — Indication temporelle extraction (US3)

**Question** : sur quelle colonne s'appuyer pour calculer le temps écoulé depuis le démarrage d'une extraction, sachant que `ExtractionJob` n'a ni `started_at` ni `processed_at` ?

**Colonnes disponibles** (`bin/rails runner "ExtractionJob.column_names"`) :
`["id", "created_at", "error_message", "exam_session_id", "provider_used", "raw_json", "status", "subject_id", "updated_at"]`

**Decision** : utiliser `job.updated_at` pour calculer `time_ago_in_words`. Raison : le job est créé en statut `pending` dans `subjects_controller#create` (`@subject.create_extraction_job!(status: :pending, ...)` puis `ExtractQuestionsJob.perform_later`), et passe à `processing` dans le job Sidekiq. Chaque transition met à jour `updated_at`. Affichage relatif toujours lisible.

**Rationale** :
- **Pas de migration** : on reste sur le scope α.
- **Précision suffisante** : un décalage de quelques secondes entre `created_at` du pending et `updated_at` du processing est invisible côté UX (`time_ago_in_words` arrondit à la minute la plus proche au-delà de 60s).
- **Fallback gracieux** (FR-016) : `updated_at` est toujours présent sur les records Rails — pas de cas nil en pratique. Si un jour le champ était nil (migration future), `time_ago_in_words(nil)` retournerait une exception → précautionner par `if job.updated_at` guard avant l'affichage.
- **I18n français** : Rails a déjà le locale `fr` actif (voir `config/application.rb` + `config/locales/`). `time_ago_in_words` retournera "45 secondes", "2 minutes", etc. en français natif.

**Alternatives considered** :
- Ajouter une colonne `processing_started_at` : rejeté (migration hors scope α, `updated_at` suffit).
- Utiliser `job.created_at` : rejeté (reflète la création du record en `pending`, pas le démarrage effectif de l'extraction). Moins précis si le job reste longtemps en file Sidekiq.
- Côté client, Stimulus controller qui incrémente un compteur : rejeté (complexité, non nécessaire — Turbo Stream régénère le partial).

---

## R4 — `aria-live` pour changement de statut extraction (US3 + bonus a11y)

**Question** : quel niveau de `aria-live` sur `#extraction-status` pour que le passage processing → done/failed soit annoncé sans spammer le lecteur d'écran ?

**Decision** : `aria-live="polite"` sur le wrapper `<div id="extraction-status">`. Ajouter aussi `aria-atomic="true"` pour que le contenu entier soit relu à chaque swap (et pas juste la différence).

**Rationale** :
- `polite` vs `assertive` : le changement de statut est important mais non-urgent (l'enseignant ne fait pas une action bloquante). `polite` attend une pause dans la lecture du lecteur d'écran. Convient.
- `aria-atomic="true"` : Turbo Stream remplace le partial entier. Sans `atomic`, NVDA/VoiceOver peuvent annoncer uniquement les fragments modifiés, ce qui produit des annonces confuses type "done" tout seul. Avec atomic, on a "Statut : Extraction terminée" qui est compréhensible.
- Couvre WCAG 4.1.3 (Status Messages) identifié dans l'audit a11y (B7).

**Alternatives considered** :
- `role="status"` : équivalent à `aria-live="polite"` avec implicit atomic. Acceptable. Choix de `aria-live` explicite pour lisibilité et contrôle fin de `aria-atomic`.

---

## R5 — Placement du bouton "Archiver le sujet" (US2, FR-011)

**Question** : où placer le bouton d'archivage sur `teacher/subjects/show.html.erb` pour qu'il soit visible mais pas concurrent du CTA principal ("Publier" / "Assigner aux classes") ?

**Decision** : ajouter le bouton tout en bas de la page, juste avant (ou à côté de) le lien "← Retour aux sujets" dans la zone de navigation de fin de page (ligne 107 actuelle). Variant `:ghost` + `size: :sm` + couleur rouge via override de classe ou nouvelle variant `:danger` sur `ButtonComponent` si besoin. `turbo_confirm` obligatoire.

**Rationale** :
- **Hors CTA principal** : les actions primaires ("Publier", "Assigner aux classes") sont en header et dans `_stats`. Un bouton d'archivage en bas = convention UI (destructive action bas et discrète).
- **Pas de nouveau composant** : `ButtonComponent` existe, même si la variant danger n'est pas encore définie on peut faire un override via classes. Mais pour éviter de toucher `ButtonComponent` (scope 027), on peut se contenter d'un `button_to` + classes custom dans cette feature ET documenter que la variant `:danger` dans `ButtonComponent` sera ajoutée plus tard dans 027. **Choix** : utiliser `ButtonComponent.new(variant: :ghost, size: :sm)` avec texte "Archiver le sujet" en rouge via span interne, OU plus simple : `button_to "Archiver le sujet", teacher_subject_path(@subject), method: :delete, data: { turbo_confirm: "…" }, class: "text-sm text-red-600 hover:text-red-700 underline underline-offset-2"` — style discret type lien comme la "Supprimer la session" existante en `subjects/show.html.erb:36-40`. Cohérent avec le style existant.

**Alternatives considered** :
- Bouton danger plein dans le header : rejeté (trop agressif, FR-011 dit "pas concurrent du CTA principal").
- Menu "…" (kebab menu) : rejeté (nouveau composant nécessaire, scope α minimal).
- Nouvelle variant `:danger` dans `ButtonComponent` : rejeté dans cette feature (touche le design system — périmètre 027). Reporté.

---

## R6 — Autorisation et scoping de `destroy` (US2, FR-010)

**Question** : comment garantir que seul le propriétaire peut archiver, sans introduire de policy/Pundit ?

**Decision** : utiliser le même pattern que les autres actions du `SubjectsController` — `current_teacher.subjects.kept.find_by(id: params[:id])` avec redirect si introuvable. Cohérent avec `set_subject` existant (lignes 35-38 du controller actuel).

**Rationale** :
- **Cohérence** : le projet n'utilise pas Pundit. L'autorisation se fait via scoping sur `current_teacher` (pattern Rails natif). Déjà appliqué pour `show`, `create`, `#index`.
- **kept scope** : ajoute l'idempotence (un sujet déjà archivé renvoie 404, pas une nouvelle archivation).
- **404 comme gestion d'erreur** : l'UI n'expose pas de lien vers un sujet non-possédé ou archivé, donc l'atteindre manuellement = cas adverse → redirect vers `teacher_subjects_path` avec alert "Sujet introuvable." (message déjà utilisé dans le controller).

**Alternatives considered** :
- Ajouter Pundit/Policy : rejeté (nouvelle dépendance hors scope).
- `before_action :verify_owner` custom : rejeté (doublon avec le scoping via ActiveRecord).

---

## R7 — Format du test feature pour téléchargement PDF (US1)

**Question** : Capybara/Selenium gère-t-il correctement la vérification d'un téléchargement de fichier binaire ?

**Decision** : tester uniquement la **présence** et le **lien** du bouton dans le DOM (`expect(page).to have_link("Télécharger la fiche PDF", href: teacher_classroom_export_path(classroom, format: :pdf))`). Ne pas tester le téléchargement effectif — celui-ci est déjà testé via les tests existants de `Teacher::Classrooms::ExportsController`.

**Rationale** :
- **Rapidité CI** : Capybara/Selenium pour download réel = instable et lent.
- **Séparation de responsabilité** : la feature 041 prouve que le bouton existe et pointe sur la bonne URL. L'export lui-même est testé ailleurs.
- **Constitution IV** : évite les specs Selenium locales lentes (machine de dev faible).

**Alternatives considered** :
- Test complet du download avec Capybara-Selenium + `save_and_open_page` : rejeté (fragile, lent).
- Test via request spec au lieu de feature : rejeté (on veut prouver le comportement utilisateur end-to-end, feature spec est approprié pour le scénario "après inscription d'élèves, le bouton apparaît").

---

## R8 — Test feature pour indication temporelle (US3)

**Question** : comment tester "démarrée il y a 45 secondes" de façon déterministe sans flakiness ?

**Decision** : utiliser `travel_to` (ActiveSupport) pour figer le temps dans le spec. Créer un ExtractionJob avec `updated_at: 45.seconds.ago`, puis visiter la page et vérifier le texte rendu.

```ruby
freeze_time do
  job.update_columns(updated_at: 45.seconds.ago)
  visit teacher_subject_path(subject)
  expect(page).to have_text(/démarrée il y a/)
  expect(page).to have_css('#extraction-status[aria-live="polite"]')
end
```

**Rationale** :
- `time_ago_in_words` retourne des chaînes localisées i18n — test sur regex souple.
- `freeze_time` + `update_columns` évite le callback `updated_at` du `update`.
- Le test de `aria-live` est purement DOM : rapide, robuste.

**Alternatives considered** :
- Mock `time_ago_in_words` : rejeté (trop intrusif).
- Tester exactement "45 secondes" : rejeté (fragilité i18n).

---

## Résumé

| Décision | Impact | Complexité |
|---|---|---|
| R1 : réutiliser route export existante | 1 ligne de vue | Trivial |
| R2 : `update!(discarded_at: Time.current)` maison | 1 méthode controller | Trivial |
| R3 : `updated_at` pour indication temporelle | 1 helper call | Trivial |
| R4 : `aria-live="polite"` + `aria-atomic="true"` | 2 attributs | Trivial |
| R5 : bouton archive en fin de page, style link rouge | 1 `button_to` | Trivial |
| R6 : scoping via `current_teacher.subjects.kept` | Cohérent existant | Trivial |
| R7 : test présence du bouton uniquement | 1 expect | Trivial |
| R8 : `freeze_time` + `update_columns` | Pattern standard | Trivial |

**Aucun NEEDS CLARIFICATION restant.** Phase 0 ready → Phase 1.

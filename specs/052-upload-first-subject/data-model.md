# Data Model: Upload-First Subject Creation Workflow

**Branch**: `052-upload-first-subject` | **Date**: 2026-04-27

## Existing Models — Changes Only

### Subject

No new columns. Three model-level changes:

```ruby
# Before:
enum :status, { draft: 0, pending_validation: 1, published: 2, archived: 3 }
belongs_to :exam_session
validates :specialty, presence: true

# After:
enum :status, { uploading: -1, draft: 0, pending_validation: 1, published: 2, archived: 3 }
belongs_to :exam_session, optional: true          # exam_session_id already nullable in schema
validates :specialty, presence: true, unless: :uploading?  # C1: guard for upload-first flow
```

**Lifecycle for new workflow**:
```
[upload form] → Subject.create!(status: :uploading, exam_session: nil, subject_pdf:, correction_pdf:)
                   ↓
              ExtractionJob.create!(status: :pending)
              ExtractQuestionsJob.perform_later(subject.id)
                   ↓
              [async] extraction runs → ExtractionJob.done (raw_json populated)
                   ↓
              [teacher visits validation form]
                   ↓ confirm
              ExamSession assigned or created
              Subject.update!(specialty:, status: :draft)
```

**Subject scopes**:
```ruby
scope :visible, -> { kept.where.not(status: :uploading) }  # published/draft subjects
# :uploading subjects shown separately in index as "En cours d'extraction…" (G1)
# Controller: @pending_subjects = current_teacher.subjects.kept.where(status: :uploading)
#             @subjects         = current_teacher.subjects.visible
```

**Validation change**: `exam_session_id` is no longer required at Subject creation (handled by `optional: true` at model level). The validation form is where ExamSession is assigned.

**Migration required**: `subjects.specialty` has `null: false, default: 0` in the DB. Since `:uploading` subjects have no specialty, we must allow NULL: `change_column_null :subjects, :specialty, true` + `change_column_default :subjects, :specialty, nil`. Migration: `20260427211523_allow_null_specialty_on_subjects.rb`. ✅ Applied.

**Abandonment cleanup**:
```ruby
# Rake task: subjects:cleanup_uploading
# Find subjects stuck in :uploading for >24h → soft-delete (discarded_at = now)
Subject.where(status: :uploading).where("created_at < ?", 24.hours.ago).update_all(discarded_at: Time.current)
```

### ExamSession

No changes. Already correct.

### ExtractionJob

No changes. Already `belongs_to :subject` (required). The subject exists before extraction runs.

### PersistExtractedData — Guard for `:uploading` subjects (C2)

When `subject.uploading?`, skip these 5 paths:

```ruby
# SKIP when subject.uploading?:
exam_session.update!(common_presentation: ...)   # exam_session is nil
exam_session.update!(variante: ...)
exam_session.update!(region: ...)
exam_session.update!(exam: ...)
exam_session.common_parts.create!(...)           # common parts need exam_session
subject.update_column(:status, :pending_validation)  # status managed by ValidationController

# KEEP when subject.uploading?:
subject.update_column(:code, metadata["code"])        # safe, subject exists
subject.update_column(:specific_presentation, ...)    # safe, subject exists
@subject.parts.specific.destroy_all + specific parts create  # DB constraint allows subject-only parts
```

The `parts_owner_check` DB constraint (`exam_session_id IS NULL AND subject_id IS NOT NULL OR ...`) is satisfied for specific parts (they belong to subject, not exam_session).

### BuildExtractionPrompt — nil specialty fallback (C3)

When `specialty` is nil (`:uploading` subject), replace specialty-specific prompt lines with:
> "Spécialité inconnue — extrait toutes les parties (communes et spécifiques) sans filtrage par spécialité."

Claude returns both common and specific parts; `MapExtractedMetadata` extracts the specialty from the result; the validation form pre-fills it for teacher confirmation.

---

## New Services

### `MapExtractedMetadata`

```ruby
# app/services/map_extracted_metadata.rb
class MapExtractedMetadata
  SPECIALTY_VALUES = %w[sin itec ee ac].freeze
  EXAM_VALUES      = %w[bac bts autre].freeze
  REGION_VALUES    = %w[metropole reunion polynesie candidat_libre].freeze
  VARIANTE_VALUES  = %w[normale remplacement].freeze

  def self.call(raw_json) = new(raw_json).call

  def initialize(raw_json)
    @meta = (raw_json || {}).fetch("metadata", {})
  end

  def call
    {
      title:    string_or_nil(@meta["title"]),
      year:     string_or_nil(@meta["year"]),
      exam:     enum_or_nil(@meta["exam"], EXAM_VALUES),
      specialty: enum_or_nil(@meta["specialty"], SPECIALTY_VALUES),
      region:   enum_or_nil(@meta["region"], REGION_VALUES),
      variante: enum_or_nil(@meta["variante"], VARIANTE_VALUES)
    }
  end

  private

  def string_or_nil(val)
    val.presence&.strip
  end

  def enum_or_nil(val, allowed)
    normalized = val.to_s.downcase.strip
    normalized if allowed.include?(normalized)
  end
end
```

### `MatchExamSession`

```ruby
# app/services/match_exam_session.rb
class MatchExamSession
  def self.call(owner:, title:, year:) = new(owner:, title:, year:).call

  def initialize(owner:, title:, year:)
    @owner = owner
    @title = title&.strip
    @year  = year&.strip
  end

  def call
    return nil if @title.blank? || @year.blank?

    @owner.exam_sessions
          .where("LOWER(TRIM(title)) = ?", @title.downcase)
          .find_by(year: @year)
  end
end
```

---

## New Controller

### `Teacher::Subjects::ValidationController`

```ruby
# app/controllers/teacher/subjects/validation_controller.rb
class Teacher::Subjects::ValidationController < Teacher::BaseController
  before_action :set_subject

  def show
    extraction_job = @subject.extraction_job
    raw_json = extraction_job&.raw_json

    @metadata = MapExtractedMetadata.call(raw_json)
    @existing_session = MatchExamSession.call(
      owner: current_teacher,
      title: @metadata[:title],
      year:  @metadata[:year]
    )
    @extraction_failed = extraction_job&.failed?
  end

  def update
    exam_session = resolve_exam_session
    @subject.assign_attributes(
      specialty: validation_params[:specialty],
      status: :draft,
      exam_session: exam_session
    )

    if exam_session&.valid? && @subject.save
      redirect_to teacher_subject_path(@subject),
                  notice: "Sujet créé avec succès."
    else
      # Re-render show with errors
      @metadata = validation_params.to_h.symbolize_keys
      @existing_session = resolve_existing_session_if_any
      @extraction_failed = false
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_subject
    @subject = current_teacher.subjects.find_by(id: params[:subject_id])
    redirect_to teacher_subjects_path, alert: "Sujet introuvable." unless @subject
  end

  def validation_params
    params.require(:subject).permit(
      :title, :year, :exam, :region, :variante, :specialty, :exam_session_choice, :exam_session_id
    )
  end

  def resolve_exam_session
    if validation_params[:exam_session_choice] == "attach" && validation_params[:exam_session_id].present?
      current_teacher.exam_sessions.find(validation_params[:exam_session_id])
    else
      current_teacher.exam_sessions.build(
        title:   validation_params[:title],
        year:    validation_params[:year],
        exam:    validation_params[:exam],
        region:  validation_params[:region],
        variante: validation_params[:variante] || "normale",
        owner:   current_teacher
      )
    end
  end
end
```

---

## Routing Change

```ruby
# config/routes.rb — inside namespace :teacher
resources :subjects, only: [:index, :new, :create, :show, :destroy] do
  resource :validation, only: [:show, :update], module: "subjects"  # NEW
  resources :parts, only: [:show] do
    resources :questions, only: [:update, :destroy], shallow: true do
      resource :validation, only: [:create, :destroy], module: "questions"
    end
  end
  resource :publication, only: [:create, :destroy], module: "subjects"
  resource :extraction,  only: [:create], module: "subjects"
  resource :assignment,  only: [:edit, :update], module: "subjects"
end
```

Note: `resource :validation` under subjects is distinct from `resource :validation` under questions (different modules: `subjects` vs `questions`). Rails resolves them correctly.

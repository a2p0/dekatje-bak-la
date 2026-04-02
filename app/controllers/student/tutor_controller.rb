class Student::TutorController < Student::BaseController
  before_action :set_subject
  before_action :set_question, only: [ :verify_spotting, :skip_spotting ]
  before_action :set_session_record, only: [ :verify_spotting, :skip_spotting ]
  before_action :require_tutored_mode, only: [ :verify_spotting, :skip_spotting ]

  def activate
    session_record = current_student.student_sessions.find_or_create_by!(subject: @subject) do |s|
      s.mode = :tutored
      s.progression = {}
      s.started_at = Time.current
      s.last_activity_at = Time.current
      s.tutor_state = {}
    end

    unless session_record.tutored?
      session_record.tutor_state = {} if session_record.tutor_state.blank?
      session_record.update!(mode: :tutored, tutor_state: session_record.tutor_state)
    end

    redirect_to student_subject_path(access_code: params[:access_code], id: @subject.id),
                notice: "Mode tuteur activé. Le tuteur IA vous accompagnera à chaque question."
  end

  def verify_spotting
    answer = @question.answer

    # Validate task type
    task_type_answer = params[:task_type]
    task_type_correct = task_type_answer == @question.answer_type

    # Normalize and validate sources
    correct_sources = normalize_sources(answer&.data_hints || [])
    sources_answer = (params[:sources] || []).reject(&:blank?)
    sources_missed = correct_sources - sources_answer
    sources_extra = sources_answer - correct_sources

    # Build feedback data with location info for missed sources
    missed_with_location = sources_missed.map do |src|
      hint = (answer&.data_hints || []).find { |h| normalize_source(h["source"]) == src }
      { "source" => src, "location" => hint&.dig("location") }
    end

    spotting_data = {
      "task_type_answer" => task_type_answer,
      "task_type_correct" => task_type_correct,
      "sources_answer" => sources_answer,
      "sources_correct" => correct_sources,
      "sources_missed" => missed_with_location,
      "sources_extra" => sources_extra,
      "completed_at" => Time.current.iso8601
    }

    @session_record.store_spotting!(@question.id, spotting_data)
    @session_record.set_question_step!(@question.id, "feedback")

    render turbo_stream: turbo_stream.replace(
      "spotting_question_#{@question.id}",
      partial: "student/tutor/spotting_feedback",
      locals: { question: @question, spotting: spotting_data }
    )
  end

  def skip_spotting
    return if @session_record.spotting_completed?(@question.id)

    @session_record.set_question_step!(@question.id, "skipped")

    render turbo_stream: turbo_stream.replace(
      "spotting_question_#{@question.id}",
      partial: "student/tutor/spotting_skipped",
      locals: { question: @question }
    )
  end

  private

  def set_subject
    @subject = @classroom.subjects.find(params[:subject_id])
  end

  def set_question
    @question = Question.kept.joins(:part)
                        .where(parts: { subject_id: @subject.id })
                        .find(params[:question_id])
  end

  def set_session_record
    @session_record = current_student.student_sessions.find_by!(subject: @subject)
  end

  def require_tutored_mode
    unless @session_record.tutored?
      head :forbidden
    end
  end

  def normalize_sources(data_hints)
    data_hints.map { |h| normalize_source(h["source"]) }.compact.uniq
  end

  def normalize_source(source)
    case source.to_s
    when /\ADT/i then "dt"
    when /\ADR/i then "dr"
    when "enonce", "question_context" then "enonce"
    when "mise_en_situation", "tableau_sujet" then "mise_en_situation"
    end
  end
end

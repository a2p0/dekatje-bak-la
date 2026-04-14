class Student::ConversationsController < Student::BaseController
  before_action :set_conversation, only: [ :messages, :confidence ]

  def create
    subject = Subject.kept.find(params[:subject_id])

    conversation = current_student.conversations.find_or_initialize_by(subject: subject)

    unless conversation.persisted?
      conversation.tutor_state = TutorState.default
      conversation.save!
    end

    conversation.activate! unless conversation.active?

    render json: { conversation_id: conversation.id }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Sujet introuvable." }, status: :not_found
  rescue AASM::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def messages
    content = params[:content].to_s.strip
    if content.blank?
      return render json: { error: "Le message ne peut pas être vide." },
                    status: :unprocessable_entity
    end

    question = Question.kept.find(params[:question_id])

    ProcessTutorMessageJob.perform_later(
      @conversation.id,
      content,
      question.id
    )

    render json: { status: "ok" }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Question introuvable." }, status: :not_found
  end

  def confidence
    level = params[:level].to_i
    unless (1..5).cover?(level)
      return render json: { error: "Niveau invalide (1-5 requis)." },
                    status: :unprocessable_entity
    end

    q_id = @conversation.tutor_state.current_question_id
    state = @conversation.tutor_state.question_states[q_id.to_s] if q_id
    unless state
      return render json: { error: "Question courante introuvable." },
                    status: :unprocessable_entity
    end

    updated_state = state.with(last_confidence: level)
    new_ts = @conversation.tutor_state.with(
      question_states: @conversation.tutor_state.question_states.merge(q_id.to_s => updated_state)
    )
    @conversation.update!(tutor_state: new_ts)

    @conversation.give_feedback! if @conversation.may_give_feedback?

    @question_id = q_id
    render "student/conversations/confidence", formats: [ :turbo_stream ]
  end

  private

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation introuvable." }, status: :not_found
  end
end

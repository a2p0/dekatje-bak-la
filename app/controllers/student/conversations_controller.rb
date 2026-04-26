class Student::ConversationsController < Student::BaseController
  before_action :require_api_key, only: [ :create, :messages ]
  before_action :set_conversation, only: [ :messages, :confidence, :mark_intro_seen ]

  def create
    @subject = Subject.kept.find(params[:subject_id])

    @conversation = current_student.conversations.find_or_initialize_by(subject: @subject)

    unless @conversation.persisted?
      @conversation.tutor_state = TutorState.default
      @conversation.save!
    end

    @conversation.activate! unless @conversation.active?

    last_at = @conversation.tutor_state.last_activity_at
    if Tutor::BuildWelcomeMessage.should_greet?(conversation: @conversation, last_activity_at: last_at)
      api_key_data = resolve_api_key_data
      Tutor::BuildWelcomeMessage.call(
        subject:      @subject,
        conversation: @conversation,
        api_key_data: api_key_data
      )
      @conversation.reload
    end

    if params[:question_id].present?
      @intro_question = Question.kept.find_by(id: params[:question_id].to_i)
      Tutor::BuildIntroMessage.call(question: @intro_question, conversation: @conversation) if @intro_question
      @conversation.reload
    end

    respond_to do |format|
      format.turbo_stream do
        streams = []

        if params[:question_id].present?
          @question_for_drawer = Question.kept.find_by(id: params[:question_id].to_i)
          streams << turbo_stream.replace(
            "tutor-chat-drawer",
            partial: "student/conversations/drawer",
            locals:  {
              conversation: @conversation,
              question:     @question_for_drawer || @subject.questions.first,
              access_code:  params[:access_code]
            }
          )
        else
          streams << turbo_stream.replace(
            "tutor-activation-banner",
            partial: "student/tutor/tutor_activated",
            locals:  { subject: @subject, access_code: params[:access_code] }
          )
        end

        render turbo_stream: streams
      end
      format.json { render json: { conversation_id: @conversation.id } }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Sujet introuvable." }, status: :not_found
  rescue AASM::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def mark_intro_seen
    question_id = params[:question_id].to_i
    current_qs  = @conversation.tutor_state.question_states
    existing_qs = current_qs[question_id.to_s] || QuestionState.new(
      phase: "enonce", step: nil, hints_used: 0, last_confidence: nil,
      error_types: [], completed_at: nil, intro_seen: false
    )
    updated_qs  = existing_qs.with(intro_seen: true)
    new_ts      = @conversation.tutor_state.with(
      question_states: current_qs.merge(question_id.to_s => updated_qs)
    )
    Tutor::UpdateTutorState.call(conversation: @conversation, tutor_state: new_ts)
    head :ok
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

  def require_api_key
    ResolveTutorApiKey.new(
      student:   current_student,
      classroom: current_student.classroom
    ).call
  rescue Tutor::NoApiKeyError
    render json: {
      error: "Configurez votre clé IA dans les réglages, ou demandez à votre enseignant d'activer le mode gratuit.",
      settings_url: student_settings_path(access_code: params[:access_code])
    }, status: :unprocessable_entity
  end

  def resolve_api_key_data
    ResolveTutorApiKey.new(
      student:   current_student,
      classroom: current_student.classroom
    ).call
  rescue Tutor::NoApiKeyError
    { api_key: nil, provider: nil, model: nil }
  end
end

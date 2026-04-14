class Student::ConversationsController < Student::BaseController
  before_action :set_conversation, only: [ :messages ]

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

  private

  def set_conversation
    @conversation = current_student.conversations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation introuvable." }, status: :not_found
  end
end

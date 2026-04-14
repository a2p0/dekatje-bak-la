class ProcessTutorMessageJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, student_input, question_id)
    conversation = Conversation.find(conversation_id)
    question     = Question.find(question_id)

    result = Tutor::ProcessMessage.call(
      conversation:  conversation,
      student_input: student_input,
      question:      question
    )

    unless result.ok?
      ActionCable.server.broadcast(
        "conversation_#{conversation_id}",
        { error: result.error }
      )
    end
  end
end

# Returns or creates the (student, subject) Conversation in :disabled state
# with TutorState.default. Used to back silent event recording before any
# tutor activation.
class Student::EnsureConversation
  def self.call(student:, subject:)
    student.conversations.find_or_create_by!(subject: subject) do |c|
      c.tutor_state = TutorState.default
    end
  end
end

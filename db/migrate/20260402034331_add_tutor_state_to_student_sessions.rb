class AddTutorStateToStudentSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :student_sessions, :tutor_state, :jsonb, default: {}, null: false
  end
end

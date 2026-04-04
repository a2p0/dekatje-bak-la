class AddScopeSelectedToStudentSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :student_sessions, :scope_selected, :boolean, default: false, null: false
  end
end

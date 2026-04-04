class AddPartFilterToStudentSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :student_sessions, :part_filter, :integer, null: false, default: 0
  end
end

class CreateStudentSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :student_sessions do |t|
      t.references :student, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.integer :mode, default: 0, null: false
      t.jsonb :progression, default: {}, null: false
      t.datetime :started_at
      t.datetime :last_activity_at

      t.timestamps
    end

    add_index :student_sessions, [ :student_id, :subject_id ], unique: true
  end
end

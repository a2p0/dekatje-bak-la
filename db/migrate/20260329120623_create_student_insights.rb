class CreateStudentInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :student_insights do |t|
      t.references :student, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.references :question, null: true, foreign_key: true
      t.string :insight_type, null: false
      t.string :concept, null: false
      t.text :text
      t.timestamps
    end

    add_index :student_insights, [ :student_id, :subject_id ]
  end
end

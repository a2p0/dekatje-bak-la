class CreateClassroomSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :classroom_subjects do |t|
      t.references :classroom, null: false, foreign_key: true
      t.references :subject,   null: false, foreign_key: true
      t.timestamps
    end

    add_index :classroom_subjects, [ :classroom_id, :subject_id ], unique: true
  end
end

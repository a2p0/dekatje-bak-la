class AddExamSessionToSubjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :subjects, :exam_session, foreign_key: true, null: true
  end
end

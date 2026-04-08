class RestructureExamSessions < ActiveRecord::Migration[8.1]
  def change
    rename_column :exam_sessions, :exam_type, :exam
    rename_column :exam_sessions, :presentation_text, :common_presentation
    add_column :exam_sessions, :variante, :integer, default: 0, null: false
  end
end

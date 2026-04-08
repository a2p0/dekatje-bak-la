class RestructureSubjects < ActiveRecord::Migration[8.1]
  def change
    rename_column :subjects, :presentation_text, :specific_presentation
    add_column :subjects, :code, :string
  end
end

class AddDtDrReferencesToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :dt_references, :jsonb, default: []
    add_column :questions, :dr_references, :jsonb, default: []
  end
end

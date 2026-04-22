class AddStructuredCorrectionToAnswers < ActiveRecord::Migration[8.1]
  def change
    add_column :answers, :structured_correction, :jsonb
  end
end

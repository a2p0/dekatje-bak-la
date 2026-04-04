class UpdateExtractionJobs < ActiveRecord::Migration[8.1]
  def change
    add_reference :extraction_jobs, :exam_session, foreign_key: true, null: true
  end
end

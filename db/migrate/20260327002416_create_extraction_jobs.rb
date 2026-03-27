class CreateExtractionJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :extraction_jobs do |t|
      t.integer    :status,        null: false, default: 0
      t.jsonb      :raw_json
      t.text       :error_message
      t.integer    :provider_used, null: false, default: 0
      t.references :subject,       null: false, foreign_key: true
      t.timestamps
    end

    add_index :extraction_jobs, :status
  end
end

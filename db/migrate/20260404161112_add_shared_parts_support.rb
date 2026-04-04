class AddSharedPartsSupport < ActiveRecord::Migration[8.1]
  def change
    add_reference :parts, :exam_session, foreign_key: true, null: true
    change_column_null :parts, :subject_id, true
    add_column :parts, :specialty, :integer
    add_column :parts, :document_references, :jsonb, default: []

    # Ensure exactly one of exam_session_id or subject_id is set
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE parts
          ADD CONSTRAINT parts_owner_check
          CHECK (
            (exam_session_id IS NOT NULL AND subject_id IS NULL) OR
            (exam_session_id IS NULL AND subject_id IS NOT NULL)
          )
          NOT VALID;
        SQL
      end

      dir.down do
        execute "ALTER TABLE parts DROP CONSTRAINT IF EXISTS parts_owner_check"
      end
    end
  end
end

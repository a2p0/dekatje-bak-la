class RenameEcToEe < ActiveRecord::Migration[8.1]
  def up
    # EC was stored as integer 3 in the specialty enum.
    # We keep the same integer value (3) but rename the Ruby symbol to :EE.
    # No data migration needed since the integer value doesn't change.
    # This migration exists as a marker for the enum rename.

    # Update any string references in classroom.specialty (stored as string)
    execute "UPDATE classrooms SET specialty = 'EE' WHERE specialty = 'EC'"
  end

  def down
    execute "UPDATE classrooms SET specialty = 'EC' WHERE specialty = 'EE'"
  end
end

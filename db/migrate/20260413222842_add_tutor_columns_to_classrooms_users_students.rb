class AddTutorColumnsToClassroomsUsersStudents < ActiveRecord::Migration[8.1]
  def change
    # Classroom: allow teacher to enable key-free tutor mode for their class
    add_column :classrooms, :tutor_free_mode_enabled, :boolean,
               default: false, null: false

    # User: OpenRouter key used when tutor_free_mode_enabled on one of their classrooms.
    # Encrypted via `encrypts :openrouter_api_key` in the User model (Rails native encryption
    # stores ciphertext in the same column — matches the existing `api_key` pattern).
    add_column :users, :openrouter_api_key, :string

    # Student: whether this student uses their own API key (true) or the classroom
    # free-mode key provided by the teacher (false).
    add_column :students, :use_personal_key, :boolean,
               default: true, null: false
  end
end

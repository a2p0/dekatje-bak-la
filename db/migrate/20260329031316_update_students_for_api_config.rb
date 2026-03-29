class UpdateStudentsForApiConfig < ActiveRecord::Migration[8.1]
  def change
    remove_column :students, :encrypted_api_key, :string
    remove_column :students, :encrypted_api_key_iv, :string
    add_column :students, :api_key, :string
    add_column :students, :api_model, :string
    add_column :students, :default_mode, :integer, default: 0, null: false
  end
end

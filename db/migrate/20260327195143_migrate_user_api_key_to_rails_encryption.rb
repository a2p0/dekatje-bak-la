class MigrateUserApiKeyToRailsEncryption < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :api_key, :string
    remove_column :users, :encrypted_api_key, :string
    remove_column :users, :encrypted_api_key_iv, :string
  end
end

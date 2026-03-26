# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_26_144427) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "classrooms", force: :cascade do |t|
    t.string "access_code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "school_year", null: false
    t.string "specialty"
    t.datetime "updated_at", null: false
    t.index ["access_code"], name: "index_classrooms_on_access_code", unique: true
    t.index ["owner_id"], name: "index_classrooms_on_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "api_provider", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_api_key"
    t.string "encrypted_api_key_iv"
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "classrooms", "users", column: "owner_id"
end

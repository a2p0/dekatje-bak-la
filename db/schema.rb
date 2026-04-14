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

ActiveRecord::Schema[8.1].define(version: 2026_04_13_225715) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "answers", force: :cascade do |t|
    t.text "correction_text"
    t.datetime "created_at", null: false
    t.jsonb "data_hints", default: []
    t.text "explanation_text"
    t.jsonb "key_concepts", default: []
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_answers_on_question_id"
  end

  create_table "classroom_subjects", force: :cascade do |t|
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.bigint "subject_id", null: false
    t.datetime "updated_at", null: false
    t.index ["classroom_id", "subject_id"], name: "index_classroom_subjects_on_classroom_id_and_subject_id", unique: true
    t.index ["classroom_id"], name: "index_classroom_subjects_on_classroom_id"
    t.index ["subject_id"], name: "index_classroom_subjects_on_subject_id"
  end

  create_table "classrooms", force: :cascade do |t|
    t.string "access_code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "school_year", null: false
    t.string "specialty"
    t.boolean "tutor_free_mode_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["access_code"], name: "index_classrooms_on_access_code", unique: true
    t.index ["owner_id"], name: "index_classrooms_on_owner_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lifecycle_state", default: "disabled", null: false
    t.string "provider_used"
    t.bigint "student_id", null: false
    t.bigint "subject_id", null: false
    t.integer "tokens_used", default: 0, null: false
    t.jsonb "tutor_state", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "subject_id"], name: "index_conversations_on_student_id_and_subject_id", unique: true
    t.index ["student_id"], name: "index_conversations_on_student_id"
    t.index ["subject_id"], name: "index_conversations_on_subject_id"
  end

  create_table "exam_sessions", force: :cascade do |t|
    t.text "common_presentation"
    t.datetime "created_at", null: false
    t.integer "exam", default: 0, null: false
    t.bigint "owner_id", null: false
    t.integer "region", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "variante", default: 0, null: false
    t.string "year", null: false
    t.index ["owner_id", "year", "region"], name: "idx_exam_sessions_lookup"
    t.index ["owner_id"], name: "index_exam_sessions_on_owner_id"
  end

  create_table "extraction_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "exam_session_id"
    t.integer "provider_used", default: 0, null: false
    t.jsonb "raw_json"
    t.integer "status", default: 0, null: false
    t.bigint "subject_id", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_session_id"], name: "index_extraction_jobs_on_exam_session_id"
    t.index ["status"], name: "index_extraction_jobs_on_status"
    t.index ["subject_id"], name: "index_extraction_jobs_on_subject_id"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "chunk_index", default: 0, null: false
    t.text "content", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "question_id"
    t.integer "role", null: false
    t.datetime "streaming_finished_at"
    t.integer "tokens_in", default: 0, null: false
    t.integer "tokens_out", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["question_id"], name: "index_messages_on_question_id"
  end

  create_table "parts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "document_references", default: []
    t.bigint "exam_session_id"
    t.string "number", null: false
    t.text "objective_text"
    t.integer "position", default: 0, null: false
    t.integer "section_type", default: 0, null: false
    t.integer "specialty"
    t.bigint "subject_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_session_id"], name: "index_parts_on_exam_session_id"
    t.index ["subject_id", "position"], name: "index_parts_on_subject_id_and_position"
    t.index ["subject_id"], name: "index_parts_on_subject_id"
  end

  add_check_constraint "parts", "exam_session_id IS NOT NULL AND subject_id IS NULL OR exam_session_id IS NULL AND subject_id IS NOT NULL", name: "parts_owner_check", validate: false

  create_table "questions", force: :cascade do |t|
    t.integer "answer_type", default: 0, null: false
    t.text "context_text"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.jsonb "dr_references", default: []
    t.jsonb "dt_references", default: []
    t.text "label", null: false
    t.string "number", null: false
    t.bigint "part_id", null: false
    t.decimal "points"
    t.integer "position", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_questions_on_discarded_at"
    t.index ["part_id", "position"], name: "index_questions_on_part_id_and_position"
    t.index ["part_id"], name: "index_questions_on_part_id"
  end

  create_table "student_insights", force: :cascade do |t|
    t.string "concept", null: false
    t.datetime "created_at", null: false
    t.string "insight_type", null: false
    t.bigint "question_id"
    t.bigint "student_id", null: false
    t.bigint "subject_id", null: false
    t.text "text"
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_student_insights_on_question_id"
    t.index ["student_id", "subject_id"], name: "index_student_insights_on_student_id_and_subject_id"
    t.index ["student_id"], name: "index_student_insights_on_student_id"
    t.index ["subject_id"], name: "index_student_insights_on_subject_id"
  end

  create_table "student_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_activity_at"
    t.integer "mode", default: 0, null: false
    t.integer "part_filter", default: 0, null: false
    t.jsonb "progression", default: {}, null: false
    t.boolean "scope_selected", default: false, null: false
    t.datetime "started_at"
    t.bigint "student_id", null: false
    t.bigint "subject_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "subject_id"], name: "index_student_sessions_on_student_id_and_subject_id", unique: true
    t.index ["student_id"], name: "index_student_sessions_on_student_id"
    t.index ["subject_id"], name: "index_student_sessions_on_subject_id"
  end

  create_table "students", force: :cascade do |t|
    t.string "api_key"
    t.string "api_model"
    t.integer "api_provider", default: 0, null: false
    t.bigint "classroom_id", null: false
    t.datetime "created_at", null: false
    t.integer "default_mode", default: 0, null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.integer "specialty"
    t.datetime "updated_at", null: false
    t.boolean "use_personal_key", default: true, null: false
    t.string "username", null: false
    t.index ["classroom_id"], name: "index_students_on_classroom_id"
    t.index ["username", "classroom_id"], name: "index_students_on_username_and_classroom_id", unique: true
  end

  create_table "subjects", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "exam_session_id"
    t.bigint "owner_id", null: false
    t.integer "specialty", default: 0, null: false
    t.text "specific_presentation"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_subjects_on_discarded_at"
    t.index ["exam_session_id"], name: "index_subjects_on_exam_session_id"
    t.index ["owner_id"], name: "index_subjects_on_owner_id"
    t.index ["status"], name: "index_subjects_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_key"
    t.integer "api_provider", default: 0, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "openrouter_api_key"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.text "tutor_prompt_template"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "answers", "questions"
  add_foreign_key "classroom_subjects", "classrooms"
  add_foreign_key "classroom_subjects", "subjects"
  add_foreign_key "classrooms", "users", column: "owner_id"
  add_foreign_key "conversations", "students"
  add_foreign_key "conversations", "subjects"
  add_foreign_key "exam_sessions", "users", column: "owner_id"
  add_foreign_key "extraction_jobs", "exam_sessions"
  add_foreign_key "extraction_jobs", "subjects"
  add_foreign_key "messages", "conversations", on_delete: :cascade
  add_foreign_key "messages", "questions", on_delete: :nullify
  add_foreign_key "parts", "exam_sessions"
  add_foreign_key "parts", "subjects"
  add_foreign_key "questions", "parts"
  add_foreign_key "student_insights", "questions"
  add_foreign_key "student_insights", "students"
  add_foreign_key "student_insights", "subjects"
  add_foreign_key "student_sessions", "students"
  add_foreign_key "student_sessions", "subjects"
  add_foreign_key "students", "classrooms"
  add_foreign_key "subjects", "exam_sessions"
  add_foreign_key "subjects", "users", column: "owner_id"
end

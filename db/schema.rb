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

ActiveRecord::Schema[8.1].define(version: 2026_10_14_030000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.string "category", default: "Genel"
    t.integer "views_count", default: 0
    t.boolean "published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "helpful_count", default: 0, null: false
    t.integer "unhelpful_count", default: 0, null: false
    t.index ["category"], name: "index_articles_on_category"
    t.index ["published"], name: "index_articles_on_published"
  end

  create_table "automation_audit_logs", force: :cascade do |t|
    t.integer "automation_rule_id"
    t.string "rule_name", null: false
    t.string "trigger_type", null: false
    t.string "executed_by", default: "system", null: false
    t.integer "records_scanned", default: 0
    t.integer "records_modified", default: 0
    t.integer "records_skipped", default: 0
    t.string "status", default: "success"
    t.text "summary"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["automation_rule_id"], name: "index_automation_audit_logs_on_automation_rule_id"
    t.index ["created_at"], name: "index_automation_audit_logs_on_created_at"
  end

  create_table "automation_rules", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "trigger_type", default: "event", null: false
    t.text "conditions"
    t.text "actions"
    t.boolean "active", default: true, null: false
    t.integer "priority_order", default: 0
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_automation_rules_on_active"
    t.index ["trigger_type"], name: "index_automation_rules_on_trigger_type"
  end

  create_table "canned_responses", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.string "category", default: "Genel"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_canned_responses_on_category"
  end

  create_table "community_answers", force: :cascade do |t|
    t.integer "community_question_id", null: false
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_solution", default: false, null: false
    t.integer "upvotes_count", default: 0, null: false
    t.index ["community_question_id"], name: "index_community_answers_on_community_question_id"
    t.index ["is_solution"], name: "index_community_answers_on_is_solution"
  end

  create_table "community_questions", force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.string "author_name", null: false
    t.string "author_email", null: false
    t.string "category", default: "Genel", null: false
    t.integer "answers_count", default: 0, null: false
    t.boolean "converted_to_ticket", default: false, null: false
    t.datetime "converted_at"
    t.integer "ticket_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "solved", default: false, null: false
    t.index ["converted_to_ticket"], name: "index_community_questions_on_converted_to_ticket"
    t.index ["created_at"], name: "index_community_questions_on_created_at"
    t.index ["solved"], name: "index_community_questions_on_solved"
    t.index ["ticket_id"], name: "index_community_questions_on_ticket_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "notifiable_type"
    t.integer "notifiable_id"
    t.boolean "read", default: false, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "sent_emails", force: :cascade do |t|
    t.string "to_email", null: false
    t.string "subject", null: false
    t.text "body", null: false
    t.string "mail_type", default: "ticket_notification", null: false
    t.integer "ticket_id"
    t.string "status", default: "delivered", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sent_emails_on_created_at"
    t.index ["ticket_id"], name: "index_sent_emails_on_ticket_id"
    t.index ["to_email"], name: "index_sent_emails_on_to_email"
  end

  create_table "ticket_comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.string "author_name", null: false
    t.string "author_role", default: "agent", null: false
    t.text "body", null: false
    t.boolean "is_internal_note", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["ticket_id"], name: "index_ticket_comments_on_ticket_id"
    t.index ["user_id"], name: "index_ticket_comments_on_user_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "ticket_number", null: false
    t.string "subject", null: false
    t.text "description", null: false
    t.string "customer_name", null: false
    t.string "customer_email", null: false
    t.string "status", default: "new", null: false
    t.string "priority", default: "medium", null: false
    t.datetime "sla_due_at", null: false
    t.boolean "sla_breached", default: false, null: false
    t.datetime "first_responded_at"
    t.datetime "solved_at"
    t.integer "community_question_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "assigned_to_id"
    t.integer "user_id"
    t.string "category", default: "Genel Destek"
    t.string "tags", default: ""
    t.integer "merged_into_ticket_id"
    t.datetime "closed_at"
    t.string "e_invoice_status", default: "not_applicable", null: false
    t.string "tax_number"
    t.string "invoice_number"
    t.datetime "first_response_due_at"
    t.boolean "first_response_breached", default: false, null: false
    t.datetime "sla_paused_at"
    t.integer "total_paused_seconds", default: 0, null: false
    t.string "channel", default: "web", null: false
    t.string "customer_phone"
    t.boolean "use_business_hours", default: false, null: false
    t.text "ai_summary"
    t.string "ai_sentiment", default: "neutral"
    t.integer "solved_by_id"
    t.index ["assigned_to_id"], name: "index_tickets_on_assigned_to_id"
    t.index ["category"], name: "index_tickets_on_category"
    t.index ["channel"], name: "index_tickets_on_channel"
    t.index ["community_question_id"], name: "index_tickets_on_community_question_id"
    t.index ["e_invoice_status"], name: "index_tickets_on_e_invoice_status"
    t.index ["first_response_breached"], name: "index_tickets_on_first_response_breached"
    t.index ["first_response_due_at"], name: "index_tickets_on_first_response_due_at"
    t.index ["merged_into_ticket_id"], name: "index_tickets_on_merged_into_ticket_id"
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["sla_due_at"], name: "index_tickets_on_sla_due_at"
    t.index ["solved_by_id"], name: "index_tickets_on_solved_by_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["ticket_number"], name: "index_tickets_on_ticket_number", unique: true
    t.index ["use_business_hours"], name: "index_tickets_on_use_business_hours"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "customer", null: false
    t.string "department", default: "Destek"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "email_notifications_enabled", default: true, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "automation_audit_logs", "automation_rules"
  add_foreign_key "community_answers", "community_questions"
  add_foreign_key "notifications", "users"
  add_foreign_key "ticket_comments", "tickets"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_10_12_200003) do
  create_table "community_answers", force: :cascade do |t|
    t.integer "community_question_id", null: false
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["community_question_id"], name: "index_community_answers_on_community_question_id"
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
    t.index ["converted_to_ticket"], name: "index_community_questions_on_converted_to_ticket"
    t.index ["created_at"], name: "index_community_questions_on_created_at"
    t.index ["ticket_id"], name: "index_community_questions_on_ticket_id"
  end

  create_table "ticket_comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.string "author_name", null: false
    t.string "author_role", default: "agent", null: false
    t.text "body", null: false
    t.boolean "is_internal_note", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_ticket_comments_on_ticket_id"
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
    t.index ["community_question_id"], name: "index_tickets_on_community_question_id"
    t.index ["priority"], name: "index_tickets_on_priority"
    t.index ["sla_due_at"], name: "index_tickets_on_sla_due_at"
    t.index ["status"], name: "index_tickets_on_status"
    t.index ["ticket_number"], name: "index_tickets_on_ticket_number", unique: true
  end

  add_foreign_key "community_answers", "community_questions"
  add_foreign_key "ticket_comments", "tickets"
end

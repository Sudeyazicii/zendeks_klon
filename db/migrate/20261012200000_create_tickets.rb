class CreateTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :tickets do |t|
      t.string :ticket_number, null: false
      t.string :subject, null: false
      t.text :description, null: false
      t.string :customer_name, null: false
      t.string :customer_email, null: false
      t.string :status, null: false, default: "new"
      t.string :priority, null: false, default: "medium"
      t.datetime :sla_due_at, null: false
      t.boolean :sla_breached, null: false, default: false
      t.datetime :first_responded_at
      t.datetime :solved_at
      t.integer :community_question_id

      t.timestamps
    end

    add_index :tickets, :ticket_number, unique: true
    add_index :tickets, :status
    add_index :tickets, :priority
    add_index :tickets, :community_question_id
    add_index :tickets, :sla_due_at
  end
end

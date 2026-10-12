class CreateTicketComments < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_comments do |t|
      t.references :ticket, null: false, foreign_key: true
      t.string :author_name, null: false
      t.string :author_role, null: false, default: "agent"
      t.text :body, null: false
      t.boolean :is_internal_note, null: false, default: false

      t.timestamps
    end
  end
end

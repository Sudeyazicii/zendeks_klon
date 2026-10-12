class EnhanceTicketsAndComments < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :assigned_to_id, :integer
    add_column :tickets, :user_id, :integer
    add_column :tickets, :category, :string, default: "Genel Destek"
    add_column :tickets, :tags, :string, default: ""
    add_column :tickets, :merged_into_ticket_id, :integer
    add_column :tickets, :closed_at, :datetime

    add_index :tickets, :assigned_to_id
    add_index :tickets, :user_id
    add_index :tickets, :category
    add_index :tickets, :merged_into_ticket_id

    add_column :ticket_comments, :user_id, :integer
    add_index :ticket_comments, :user_id
  end
end

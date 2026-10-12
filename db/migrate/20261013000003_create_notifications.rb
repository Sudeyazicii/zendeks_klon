class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :message, null: false
      t.string :notifiable_type
      t.integer :notifiable_id
      t.boolean :read, null: false, default: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :read]
    add_index :notifications, :created_at
  end
end

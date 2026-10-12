class CreateCommunityQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :community_questions do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :author_name, null: false
      t.string :author_email, null: false
      t.string :category, null: false, default: "Genel"
      t.integer :answers_count, null: false, default: 0
      t.boolean :converted_to_ticket, null: false, default: false
      t.datetime :converted_at
      t.integer :ticket_id

      t.timestamps
    end

    add_index :community_questions, :converted_to_ticket
    add_index :community_questions, :ticket_id
    add_index :community_questions, :created_at
  end
end

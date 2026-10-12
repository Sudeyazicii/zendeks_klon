class CreateCannedResponsesAndArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :canned_responses do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.string :category, default: "Genel"
      t.integer :created_by_id

      t.timestamps
    end

    add_index :canned_responses, :category

    create_table :articles do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :category, default: "Genel"
      t.integer :views_count, default: 0
      t.boolean :published, default: true

      t.timestamps
    end

    add_index :articles, :category
    add_index :articles, :published
  end
end

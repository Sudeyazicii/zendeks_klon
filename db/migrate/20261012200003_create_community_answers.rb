class CreateCommunityAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :community_answers do |t|
      t.references :community_question, null: false, foreign_key: true
      t.string :author_name, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end

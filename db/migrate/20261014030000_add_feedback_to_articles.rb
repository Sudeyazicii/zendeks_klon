class AddFeedbackToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :helpful_count, :integer, default: 0, null: false
    add_column :articles, :unhelpful_count, :integer, default: 0, null: false
  end
end

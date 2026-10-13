class AddSolvedByToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :solved_by_id, :integer
    add_index :tickets, :solved_by_id
  end
end

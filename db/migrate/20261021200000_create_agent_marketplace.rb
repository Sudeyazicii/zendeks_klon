class CreateAgentMarketplace < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_agents do |t|
      t.string :name, null: false
      t.string :code_name, null: false
      t.string :role_title, null: false
      t.string :avatar, null: false, default: "🤖"
      t.string :badge_color, default: "#6366f1"
      t.string :specialty, null: false
      t.string :category_focus, null: false
      t.text :bio, null: false
      t.string :llm_model_name, default: "gpt-4o-mini"
      t.decimal :hourly_rate, precision: 8, scale: 2, default: 45.0
      t.decimal :daily_rate, precision: 8, scale: 2, default: 250.0
      t.decimal :rating, precision: 3, scale: 2, default: 4.95
      t.integer :reviews_count, default: 120
      t.integer :accuracy_rate, default: 98
      t.integer :human_in_the_loop_threshold, default: 80
      t.text :system_prompt
      t.string :skills_tags
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :ai_agents, :code_name, unique: true
    add_index :ai_agents, :category_focus

    create_table :agent_rentals do |t|
      t.references :ai_agent, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :package_name, default: "Standart Kiralama", null: false
      t.integer :rental_duration_days, default: 7, null: false
      t.string :status, default: "active", null: false
      t.datetime :rented_at, null: false
      t.datetime :expires_at, null: false
      t.integer :tickets_processed_count, default: 0, null: false
      t.integer :tickets_solved_count, default: 0, null: false
      t.integer :sla_violations_prevented, default: 0, null: false
      t.decimal :total_cost, precision: 10, scale: 2, default: 0.0
      t.boolean :auto_pilot_enabled, default: true, null: false
      t.boolean :require_human_approval, default: false, null: false

      t.timestamps
    end
    add_index :agent_rentals, :status

    create_table :agent_execution_logs do |t|
      t.references :agent_rental, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.string :action_taken, null: false
      t.integer :confidence_score, default: 95
      t.text :reasoning
      t.text :suggested_reply
      t.boolean :human_approved
      t.integer :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end
    add_index :agent_execution_logs, :action_taken
    add_index :agent_execution_logs, :human_approved

    add_column :tickets, :assigned_ai_agent_id, :integer
    add_column :tickets, :needs_human_review, :boolean, default: false, null: false
    add_column :tickets, :ai_agent_reasoning, :text
    add_index :tickets, :assigned_ai_agent_id
    add_index :tickets, :needs_human_review
  end
end

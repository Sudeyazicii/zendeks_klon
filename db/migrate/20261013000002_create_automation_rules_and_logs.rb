class CreateAutomationRulesAndLogs < ActiveRecord::Migration[8.0]
  def change
    drop_table :automation_audit_logs, if_exists: true
    drop_table :automation_rules, if_exists: true

    create_table :automation_rules do |t|
      t.string :name, null: false
      t.text :description
      t.string :trigger_type, null: false, default: "event"
      t.text :conditions
      t.text :actions
      t.boolean :active, null: false, default: true
      t.integer :priority_order, default: 0
      t.datetime :last_run_at

      t.timestamps
    end

    add_index :automation_rules, :active
    add_index :automation_rules, :trigger_type

    create_table :automation_audit_logs do |t|
      t.references :automation_rule, foreign_key: true, null: true
      t.string :rule_name, null: false
      t.string :trigger_type, null: false
      t.string :executed_by, null: false, default: "system"
      t.integer :records_scanned, default: 0
      t.integer :records_modified, default: 0
      t.integer :records_skipped, default: 0
      t.string :status, default: "success"
      t.text :summary
      t.text :details

      t.timestamps
    end

    add_index :automation_audit_logs, :created_at
  end
end

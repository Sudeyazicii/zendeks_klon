class AddAdvancedFeaturesAndEinvoice < ActiveRecord::Migration[8.1]
  def change
    # e-Fatura Durumu, Vergi Bilgileri & Gelişmiş SLA (İlk Yanıt + Duraklatma)
    add_column :tickets, :e_invoice_status, :string, default: "not_applicable", null: false
    add_column :tickets, :tax_number, :string
    add_column :tickets, :invoice_number, :string
    add_column :tickets, :first_response_due_at, :datetime
    add_column :tickets, :first_response_breached, :boolean, default: false, null: false
    add_column :tickets, :sla_paused_at, :datetime
    add_column :tickets, :total_paused_seconds, :integer, default: 0, null: false

    add_index :tickets, :e_invoice_status
    add_index :tickets, :first_response_due_at
    add_index :tickets, :first_response_breached

    # Topluluk Forumu: Çözüm Olarak İşaretleme & Faydalı Oy (Upvote)
    add_column :community_answers, :is_solution, :boolean, default: false, null: false
    add_column :community_answers, :upvotes_count, :integer, default: 0, null: false
    add_column :community_questions, :solved, :boolean, default: false, null: false

    add_index :community_answers, :is_solution
    add_index :community_questions, :solved
  end
end

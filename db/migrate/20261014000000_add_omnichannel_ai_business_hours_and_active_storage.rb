class AddOmnichannelAiBusinessHoursAndActiveStorage < ActiveRecord::Migration[8.1]
  def change
    # 1. Omnichannel, Mesai Saati SLA ve AI Alanları
    add_column :tickets, :channel, :string, default: "web", null: false
    add_column :tickets, :customer_phone, :string
    add_column :tickets, :use_business_hours, :boolean, default: false, null: false
    add_column :tickets, :ai_summary, :text
    add_column :tickets, :ai_sentiment, :string, default: "neutral"

    add_index :tickets, :channel
    add_index :tickets, :use_business_hours

    # 2. Kullanıcı E-posta Bildirim Tercihi
    add_column :users, :email_notifications_enabled, :boolean, default: true, null: false

    # 3. Giden E-posta Günlüğü / Outbox Tablosu
    create_table :sent_emails do |t|
      t.string :to_email, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.string :mail_type, default: "ticket_notification", null: false
      t.integer :ticket_id
      t.string :status, default: "delivered", null: false
      t.timestamps
    end
    add_index :sent_emails, :to_email
    add_index :sent_emails, :ticket_id
    add_index :sent_emails, :created_at

    # 4. Active Storage Tabloları (Dosya Ekleri)
    create_table :active_storage_blobs do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum

      t.datetime :created_at, precision: 6, null: false

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false
      t.references :blob,     null: false

      t.datetime :created_at, precision: 6, null: false

      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end
end

class SentEmail < ApplicationRecord
  belongs_to :ticket, optional: true

  validates :to_email, :subject, :body, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.log_email!(to_email:, subject:, body:, mail_type: "notification", ticket_id: nil)
    create!(
      to_email: to_email,
      subject: subject,
      body: body,
      mail_type: mail_type,
      ticket_id: ticket_id,
      status: "delivered"
    )
  end
end

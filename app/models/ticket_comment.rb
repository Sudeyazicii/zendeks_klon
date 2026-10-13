class TicketComment < ApplicationRecord
  ROLES = %w[agent customer].freeze

  belongs_to :ticket
  has_many_attached :attachments

  validates :body, presence: true
  validates :author_name, presence: true
  validates :author_role, inclusion: { in: ROLES }

  after_create_commit :update_ticket_status_on_reply
  after_create_commit :send_reply_email_notification

  private

  def update_ticket_status_on_reply
    if author_role == "agent"
      if ticket.first_responded_at.nil?
        ticket.update_column(:first_responded_at, created_at)
      end

      if ticket.status == "new"
        ticket.transition_to!("open")
      end
    end
  end

  def send_reply_email_notification
    return if is_internal_note?
    TicketMailer.new_reply(ticket, self).deliver_now
  rescue StandardError => e
    Rails.logger.error("TicketComment mail error: #{e.message}")
  end
end

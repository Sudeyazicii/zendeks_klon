class AgentExecutionLog < ApplicationRecord
  belongs_to :agent_rental, optional: true
  belongs_to :ai_agent
  belongs_to :ticket
  belongs_to :reviewed_by, class_name: "User", optional: true

  ACTIONS = %w[resolved replied_pending escalated_human sla_triaged].freeze

  validates :action_taken, inclusion: { in: ACTIONS }
  validates :confidence_score, numericality: { in: 0..100 }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending_review, -> { where(human_approved: nil, action_taken: "escalated_human") }
  scope :approved, -> { where(human_approved: true) }

  def pending_review?
    human_approved.nil? && action_taken == "escalated_human"
  end

  def approve_and_send!(reviewer_user)
    transaction do
      update!(
        human_approved: true,
        reviewed_by: reviewer_user,
        reviewed_at: Time.current
      )

      # Bilete onaylanan yorumu ekle
      comment = ticket.ticket_comments.create!(
        author_name: "🤖 #{ai_agent.name} (Kiralık AI Destek Ajanı)",
        author_role: "agent",
        body: suggested_reply.presence || "Ajan önerisi insan temsilci tarafından onaylandı ve uygulandı."
      )

      ticket.update_columns(
        needs_human_review: false,
        status: "solved",
        solved_at: Time.current,
        solved_by_id: reviewer_user.id
      )

      agent_rental&.increment_metrics!(solved: true, sla_saved: true)
    end
  end

  def reject_and_takeover!(reviewer_user, internal_note: "İnsan temsilci devraldı.")
    transaction do
      update!(
        human_approved: false,
        reviewed_by: reviewer_user,
        reviewed_at: Time.current
      )

      ticket.ticket_comments.create!(
        author_name: reviewer_user.name,
        author_role: "agent",
        is_internal_note: true,
        body: "⚠️ Ajan önerisi reddedildi. #{internal_note}"
      )

      ticket.update_columns(
        needs_human_review: false,
        assigned_to_id: reviewer_user.id,
        status: "open"
      )
    end
  end
end

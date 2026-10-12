class Ticket < ApplicationRecord
  STATUSES = %w[new open pending solved].freeze
  PRIORITIES = %w[low medium high urgent].freeze

  ALLOWED_TRANSITIONS = {
    "new"     => %w[open pending],
    "open"    => %w[pending solved],
    "pending" => %w[open solved],
    "solved"  => %w[open] # Çözülen talep sadece yeniden açılabilir (open)
  }.freeze

  SLA_DURATIONS = {
    "urgent" => 2.hours,
    "high"   => 4.hours,
    "medium" => 8.hours,
    "low"    => 24.hours
  }.freeze

  has_many :ticket_comments, -> { order(created_at: :asc) }, dependent: :destroy
  belongs_to :community_question, optional: true

  validates :subject, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :ticket_number, presence: true, uniqueness: true

  validate :validate_status_transition, on: :update

  before_validation :generate_ticket_number, on: :create
  before_validation :calculate_sla_due_at, on: :create

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unresolved, -> { where.not(status: "solved") }
  scope :breached, -> { where(sla_breached: true).or(where("status != 'solved' AND sla_due_at < ?", Time.current)) }

  def breached?
    return true if sla_breached?
    return false if solved?

    Time.current > sla_due_at
  end

  def check_sla_breach!
    if breached? && !sla_breached?
      update_column(:sla_breached, true)
    end
  end

  def solved?
    status == "solved"
  end

  def reopen!
    transition_to!("open")
  end

  def transition_to!(new_status)
    self.status = new_status
    if new_status == "solved"
      self.solved_at = Time.current
    elsif status_was == "solved" && new_status == "open"
      self.solved_at = nil
    end
    save!
  end

  def can_transition_to?(new_status)
    return true if status == new_status
    ALLOWED_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  private

  def generate_ticket_number
    return if ticket_number.present?

    last_id = Ticket.maximum(:id) || 0
    self.ticket_number = sprintf("PD-%04d", last_id + 1001)
  end

  def calculate_sla_due_at
    return if sla_due_at.present?

    duration = SLA_DURATIONS.fetch(priority, 8.hours)
    self.sla_due_at = (created_at || Time.current) + duration
  end

  def validate_status_transition
    return unless will_save_change_to_status?

    old_status = status_was
    new_status = status

    unless ALLOWED_TRANSITIONS.fetch(old_status, []).include?(new_status)
      errors.add(:status, "Geçersiz durum geçişi: '#{old_status}' durumundan '#{new_status}' durumuna doğrudan geçilemez.")
    end
  end
end

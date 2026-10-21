class AgentRental < ApplicationRecord
  belongs_to :ai_agent
  belongs_to :user, optional: true
  has_many :agent_execution_logs, dependent: :nullify

  STATUSES = %w[active paused expired].freeze

  validates :package_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rental_duration_days, numericality: { greater_than: 0 }
  validates :rented_at, presence: true
  validates :expires_at, presence: true

  scope :active_now, -> { where(status: "active").where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ? OR status = 'expired'", Time.current) }

  def active?
    status == "active" && expires_at > Time.current
  end

  def remaining_days
    [((expires_at - Time.current) / 1.day).ceil, 0].max
  end

  def remaining_hours
    [((expires_at - Time.current) / 1.hour).round(1), 0.0].max
  end

  # İnsan saatine kıyasla tasarruf edilen maliyet (insan saatlik 180 TL kabulü ile)
  def human_cost_saved
    # Her çözülen bilet ortalama 25 dk (0.42 saat) insan temsilci süresi tasarrufu sağlar
    (tickets_solved_count * 0.42 * 180.0).round(2)
  end

  def increment_metrics!(solved: false, sla_saved: false)
    updates = { tickets_processed_count: tickets_processed_count + 1 }
    updates[:tickets_solved_count] = tickets_solved_count + 1 if solved
    updates[:sla_violations_prevented] = sla_violations_prevented + 1 if sla_saved
    update_columns(updates)
  end
end

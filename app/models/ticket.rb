class Ticket < ApplicationRecord
  STATUSES = %w[new open pending solved closed].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  CATEGORIES = ["Genel Destek", "Fatura & Ödeme", "Teknik Hata", "Entegrasyon & API", "Hesap & Güvenlik"].freeze

  ALLOWED_TRANSITIONS = {
    "new"     => %w[open pending],
    "open"    => %w[pending solved closed],
    "pending" => %w[open solved closed],
    "solved"  => %w[open closed], # Çözülen talep kapatılabilir veya yeniden açılabilir
    "closed"  => %w[open]         # Kapatılan talep sadece yeniden açılabilir
  }.freeze

  SLA_DURATIONS = {
    "urgent" => 2.hours,
    "high"   => 4.hours,
    "medium" => 8.hours,
    "low"    => 24.hours
  }.freeze

  has_many :ticket_comments, -> { order(created_at: :asc) }, dependent: :destroy
  belongs_to :community_question, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :user, optional: true
  belongs_to :merged_into_ticket, class_name: "Ticket", optional: true
  has_many :merged_tickets, class_name: "Ticket", foreign_key: "merged_into_ticket_id", dependent: :nullify

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
  scope :unresolved, -> { where.not(status: %w[solved closed]) }
  scope :active_tickets, -> { where(status: %w[new open pending]) }
  scope :breached, -> { where(sla_breached: true).or(where("status NOT IN ('solved', 'closed') AND sla_due_at < ?", Time.current)) }
  scope :unassigned, -> { where(assigned_to_id: nil) }

  def breached?
    return true if sla_breached?
    return false if solved? || closed?

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

  def closed?
    status == "closed"
  end

  def reopen!
    transition_to!("open")
  end

  def close!
    transition_to!("closed")
  end

  def transition_to!(new_status)
    self.status = new_status
    if new_status == "solved"
      self.solved_at = Time.current
    elsif new_status == "closed"
      self.closed_at = Time.current
    elsif (status_was == "solved" || status_was == "closed") && new_status == "open"
      self.solved_at = nil
      self.closed_at = nil
    end
    save!
  end

  def can_transition_to?(new_status)
    return true if status == new_status
    ALLOWED_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  # Benzer ve Mükerrer Talep Tespiti (G2 Müşteri Şikâyeti Çözümü)
  def similar_tickets
    return Ticket.none if new_record?

    # Aynı e-posta veya benzer başlık kelimeleri
    words = subject.to_s.downcase.gsub(/[^a-z0-9ğüşıöç\s]/i, "").split(/\s+/).reject { |w| w.length < 4 }
    
    scope = Ticket.where.not(id: id).where.not(status: "closed")
    
    if words.any?
      conditions = words.take(3).map { "LOWER(subject) LIKE ?" }
      values = words.take(3).map { |w| "%#{w}%" }
      query_str = (["customer_email = ?"] + conditions).join(" OR ")
      scope.where(query_str, customer_email, *values).limit(5)
    else
      scope.where(customer_email: customer_email).limit(5)
    end
  end

  # Mükerrer Talep Birleştirme (Merge)
  def merge_into!(target_ticket, agent_name: "Destek Uzmanı")
    raise ArgumentError, "Talep kendisiyle birleştirilemez." if target_ticket.id == id

    transaction do
      self.merged_into_ticket_id = target_ticket.id
      transition_to!("closed")

      # Ana talebe dahili not ekle
      target_ticket.ticket_comments.create!(
        author_name: agent_name,
        author_role: "agent",
        is_internal_note: true,
        body: "ℹ️ [Birleştirme Bilgisi] ##{ticket_number} ('#{subject}') numaralı talep bu taleple birleştirildi."
      )

      # Bu talebe de kapatma notu ekle
      ticket_comments.create!(
        author_name: agent_name,
        author_role: "agent",
        is_internal_note: true,
        body: "ℹ️ Bu talep ##{target_ticket.ticket_number} numaralı ana taleple birleştirilerek kapatılmıştır."
      )
    end
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

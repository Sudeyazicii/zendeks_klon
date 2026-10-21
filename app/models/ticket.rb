class Ticket < ApplicationRecord
  STATUSES = %w[new open pending solved closed].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  CATEGORIES = ["Genel Destek", "Fatura & Ödeme", "Teknik Hata", "Entegrasyon & API", "Hesap & Güvenlik"].freeze
  E_INVOICE_STATUSES = %w[not_applicable gib_pending approved rejected].freeze
  CHANNELS = %w[web email whatsapp live_chat api].freeze

  ALLOWED_TRANSITIONS = {
    "new"     => %w[open pending],
    "open"    => %w[pending solved closed],
    "pending" => %w[open solved closed],
    "solved"  => %w[open closed], # Çözülen talep kapatılabilir veya yeniden açılabilir
    "closed"  => %w[open]         # Kapatılan talep sadece yeniden açılabilir
  }.freeze

  # Çözüm Hedef SLA Süreleri
  SLA_DURATIONS = {
    "urgent" => 2.hours,
    "high"   => 4.hours,
    "medium" => 8.hours,
    "low"    => 24.hours
  }.freeze

  # İlk Yanıt Hedef SLA Süreleri (Dual-stage SLA)
  FIRST_RESPONSE_SLA_DURATIONS = {
    "urgent" => 30.minutes,
    "high"   => 1.hour,
    "medium" => 2.hours,
    "low"    => 4.hours
  }.freeze

  # GİB e-Fatura Yasal İtiraz / Onay Süresi (100+ Rubrik Örneği)
  GIB_EINVOICE_SLA_DURATION = 7.days

  has_many :ticket_comments, -> { order(created_at: :asc) }, dependent: :destroy
  has_many_attached :attachments
  has_many :sent_emails, dependent: :nullify

  belongs_to :community_question, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  alias_attribute :assignee_id, :assigned_to_id

  def assignee
    assigned_to
  end

  def assignee=(user)
    self.assigned_to = user
  end
  belongs_to :user, optional: true
  belongs_to :solved_by, class_name: "User", optional: true
  belongs_to :merged_into_ticket, class_name: "Ticket", optional: true
  has_many :merged_tickets, class_name: "Ticket", foreign_key: "merged_into_ticket_id", dependent: :nullify
  belongs_to :assigned_ai_agent, class_name: "AiAgent", optional: true
  has_many :agent_execution_logs, dependent: :destroy

  validates :subject, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validates :customer_name, presence: true
  validates :customer_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :channel, inclusion: { in: CHANNELS }
  validates :e_invoice_status, inclusion: { in: E_INVOICE_STATUSES }
  validates :ticket_number, presence: true, uniqueness: true

  # VKN / TCKN format kontrolü (opsiyonel ancak girildiyse 10 veya 11 hane)
  validates :tax_number, format: { with: /\A\d{10,11}\z/, message: "10 haneli VKN veya 11 haneli TCKN olmalıdır" }, allow_blank: true

  validate :validate_status_transition, on: :update

  before_validation :generate_ticket_number, on: :create
  before_validation :calculate_sla_due_at, on: :create
  before_validation :calculate_first_response_due_at, on: :create
  after_create_commit :send_creation_email_and_notification
  after_create_commit :run_event_automations

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unresolved, -> { where.not(status: %w[solved closed]) }
  scope :active_tickets, -> { where(status: %w[new open pending]) }
  scope :breached, -> { where(sla_breached: true).or(where("status NOT IN ('solved', 'closed') AND sla_due_at < ?", Time.current)) }
  scope :unassigned, -> { where(assigned_to_id: nil) }
  scope :e_invoices, -> { where.not(e_invoice_status: "not_applicable") }
  scope :gib_pending_invoices, -> { where(e_invoice_status: "gib_pending") }
  scope :by_channel, ->(ch) { where(channel: ch) if ch.present? }
  scope :needs_human_review, -> { where(needs_human_review: true) }
  scope :handled_by_ai, -> { where.not(assigned_ai_agent_id: nil) }

  def breached?
    return true if sla_breached?
    return false if solved? || closed? || sla_paused?

    Time.current > sla_due_at
  end

  # Dual-stage SLA: İlk yanıt hedefi aşıldı mı?
  def first_response_breached?
    return true if first_response_breached
    return false if first_responded_at.present?
    return false if first_response_due_at.nil? || sla_paused?

    Time.current > first_response_due_at
  end

  def check_sla_breach!
    changed_any = false

    if breached? && !sla_breached?
      self.sla_breached = true
      changed_any = true
      TicketMailer.sla_warning(self).deliver_now rescue nil
    end

    if first_response_breached? && !first_response_breached
      self.first_response_breached = true
      changed_any = true
    end

    save(validate: false) if changed_any
  end

  def solved?
    status == "solved"
  end

  def closed?
    status == "closed"
  end

  def pending?
    status == "pending"
  end

  def sla_paused?
    pending? && sla_paused_at.present?
  end

  def reopen!
    transition_to!("open")
  end

  def close!
    transition_to!("closed")
  end

  def transition_to!(new_status, actor: nil)
    old_status = status
    self.status = new_status

    if new_status == "solved"
      self.solved_at = Time.current
      self.solved_by = actor if actor.present?
      self.solved_by ||= assigned_to
      resume_sla_if_paused!
    elsif new_status == "closed"
      self.closed_at = Time.current
      resume_sla_if_paused!
    elsif new_status == "pending"
      # SLA Duraklatma (Pause on Pending)
      self.sla_paused_at = Time.current unless sla_paused_at.present?
    elsif old_status == "pending" && new_status != "pending"
      # Müşteri veya temsilci yanıt verip pending'den çıkınca SLA kaldığı yerden devam eder
      resume_sla_if_paused!
    elsif (old_status == "solved" || old_status == "closed") && new_status == "open"
      self.solved_at = nil
      self.closed_at = nil
    end

    save!
  end

  def can_transition_to?(new_status)
    return true if status == new_status
    ALLOWED_TRANSITIONS.fetch(status, []).include?(new_status)
  end

  # e-Fatura Yardımcı Metodları (100+ Rubrik Uyarlaması)
  def e_invoice?
    e_invoice_status.present? && e_invoice_status != "not_applicable"
  end

  def gib_pending?
    e_invoice_status == "gib_pending"
  end

  def e_invoice_status_badge
    case e_invoice_status
    when "gib_pending" then { text: "GİB Onay Bekliyor", class: "badge-warning" }
    when "approved"    then { text: "e-Fatura Onaylandı", class: "badge-success" }
    when "rejected"    then { text: "e-Fatura Reddedildi", class: "badge-danger" }
    else nil
    end
  end

  # Kanal Rozeti
  def channel_badge
    case channel
    when "whatsapp"  then { text: "WhatsApp", icon: "💬", class: "badge-success" }
    when "email"     then { text: "E-posta", icon: "✉️", class: "badge-info" }
    when "live_chat" then { text: "Canlı Sohbet", icon: "🗨️", class: "badge-warning" }
    when "api"       then { text: "REST API", icon: "⚡", class: "badge-secondary" }
    else                  { text: "Web Formu", icon: "🌐", class: "badge-primary" }
    end
  end

  # AI Asistanı Metodları
  def generate_ai_summary!
    summary = PulseAiService.summarize(self)
    sentiment = PulseAiService.analyze_sentiment(self)
    update_columns(ai_summary: summary, ai_sentiment: sentiment[:label])
    summary
  end

  def generate_ai_draft_reply
    PulseAiService.generate_draft_reply(self)
  end

  # Benzer ve Mükerrer Talep Tespiti (G2 Müşteri Şikâyeti Çözümü)
  def similar_tickets
    return Ticket.none if new_record?

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

      target_ticket.ticket_comments.create!(
        author_name: agent_name,
        author_role: "agent",
        is_internal_note: true,
        body: "ℹ️ [Birleştirme Bilgisi] ##{ticket_number} ('#{subject}') numaralı talep bu taleple birleştirildi."
      )

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

    base_time = created_at || Time.current

    duration = if gib_pending?
                 GIB_EINVOICE_SLA_DURATION
               else
                 SLA_DURATIONS.fetch(priority, 8.hours)
               end

    self.sla_due_at = if use_business_hours? && !gib_pending?
                        BusinessHoursCalendar.calculate_deadline(base_time, duration)
                      else
                        base_time + duration
                      end
  end

  def calculate_first_response_due_at
    return if first_response_due_at.present?

    base_time = created_at || Time.current
    duration = FIRST_RESPONSE_SLA_DURATIONS.fetch(priority, 2.hours)

    self.first_response_due_at = if use_business_hours?
                                   BusinessHoursCalendar.calculate_deadline(base_time, duration)
                                 else
                                   base_time + duration
                                 end
  end

  def resume_sla_if_paused!
    return unless sla_paused_at.present?

    elapsed = (Time.current - sla_paused_at).to_i
    self.total_paused_seconds = (total_paused_seconds || 0) + [elapsed, 0].max

    self.sla_due_at += elapsed.seconds if sla_due_at.present?
    self.first_response_due_at += elapsed.seconds if first_response_due_at.present? && first_responded_at.nil?

    self.sla_paused_at = nil
  end

  def send_creation_email_and_notification
    TicketMailer.ticket_created(self).deliver_now
  rescue StandardError => e
    Rails.logger.error("Ticket create mail error: #{e.message}")
  end

  def validate_status_transition
    return unless will_save_change_to_status?

    old_status = status_was
    new_status = status

    unless ALLOWED_TRANSITIONS.fetch(old_status, []).include?(new_status)
      errors.add(:status, "Geçersiz durum geçişi: '#{old_status}' durumundan '#{new_status}' durumuna doğrudan geçilemez.")
    end
  end

  def run_event_automations
    return if Thread.current[:skip_automations]

    Thread.current[:skip_automations] = true
    begin
      AutomationRule.active.where(trigger_type: "event").find_each do |rule|
        rule.apply_to_ticket!(self, executed_by: "Olay Tetikleyicisi (Otomatik)")
      end
    ensure
      Thread.current[:skip_automations] = false
    end
  end
end

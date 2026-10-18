class CommunityQuestion < ApplicationRecord
  has_many :community_answers, -> { order(is_solution: :desc, upvotes_count: :desc, created_at: :asc) }, dependent: :destroy
  has_one :accepted_solution, -> { where(is_solution: true) }, class_name: "CommunityAnswer"
  belongs_to :ticket, optional: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true
  validates :author_name, presence: true
  validates :author_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :unanswered, -> { where(answers_count: 0) }
  scope :answered, -> { where("answers_count > 0") }
  scope :solved, -> { where(solved: true) }
  scope :not_converted, -> { where(converted_to_ticket: false) }
  scope :eligible_for_auto_conversion, -> { unanswered.not_converted.where("created_at <= ?", 24.hours.ago) }

  def eligible_for_conversion?
    !converted_to_ticket? && answers_count.zero? && created_at <= 24.hours.ago
  end

  def convert_to_ticket!(reason: "auto")
    with_lock do
      return ticket if converted_to_ticket? && ticket.present?

      # Otomatik çalıştırmada 24 saati dolmamış veya cevabı olan sorular dönüştürülmez
      if reason.to_s.start_with?("auto") && !eligible_for_conversion?
        return nil
      end

      new_ticket = Ticket.create!(
        subject: "[Topluluk Forumu ##{id}] #{title}",
        description: "Bu destek talebi, topluluk forumunda 24 saattir cevapsız kalan soru için otomatik olarak açılmıştır.\n\nOrijinal Soru Detayı:\n#{body}",
        customer_name: author_name,
        customer_email: author_email,
        priority: "high",
        status: "new",
        category: "Topluluk Forumu",
        community_question_id: id
      )

      update!(
        converted_to_ticket: true,
        converted_at: Time.current,
        ticket_id: new_ticket.id
      )

      new_ticket
    end
  end

  def self.auto_convert_unanswered!(executed_by: "Sistem (24h Zamanlayıcı)")
    eligible = eligible_for_auto_conversion.to_a
    total_unanswered = unanswered.not_converted.count
    converted = []

    eligible.each do |question|
      ticket = question.convert_to_ticket!(reason: "auto_24h")
      converted << ticket if ticket.present?
    end

    # Denetim Günlüğü Kaydet
    AutomationAuditLog.create!(
      rule_name: "24 Saat Cevapsız Forum Sorularını Destek Talebine Dönüştür", 
      trigger_type: "time_based",
      executed_by: executed_by,
      records_scanned: total_unanswered,
      records_modified: converted.size,
      records_skipped: total_unanswered - converted.size,
      status: "success",
      summary: "#{converted.size} adet 24 saati aşmış cevapsız soru destek talebine dönüştürüldü. #{total_unanswered - converted.size} adet soru henüz 24 saat sınırını doldurmadığı için atlandı.",
      details: {
        converted_ticket_numbers: converted.map(&:ticket_number),
        eligible_count: eligible.size
      }.to_json
    )

    converted
  end
end

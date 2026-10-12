require "csv"

class ReportsController < ApplicationController
  before_action :require_agent!

  def index
    @total_tickets     = Ticket.count
    @open_tickets      = Ticket.active_tickets.count
    @solved_tickets    = Ticket.where(status: %w[solved closed]).count
    @breached_tickets  = Ticket.breached.count

    @compliance_rate = @total_tickets.positive? ? (((@total_tickets - @breached_tickets).to_f / @total_tickets) * 100).round(1) : 100.0

    # Ortalama ilk yanıt süresi (Yalnızca yanıtlanmış kayıtlar üzerinden)
    responded_tickets = Ticket.where.not(first_responded_at: nil)
    @responded_count = responded_tickets.count
    @avg_first_response_minutes = if @responded_count.positive?
      (responded_tickets.sum { |t| t.first_responded_at - t.created_at } / @responded_count / 60.0).round(1)
    else
      nil
    end

    # Ortalama çözüm süresi (Yalnızca çözülmüş kayıtlar üzerinden)
    solved_tickets = Ticket.where.not(solved_at: nil)
    @solved_count = solved_tickets.count
    @avg_resolution_hours = if @solved_count.positive?
      (solved_tickets.sum { |t| t.solved_at - t.created_at } / @solved_count / 3600.0).round(1)
    else
      nil
    end

    # Temsilci başına iş yükü
    @agents = User.agents.map do |agent|
      {
        name: agent.name,
        department: agent.department,
        assigned_count: Ticket.where(assigned_to_id: agent.id).active_tickets.count,
        solved_count: Ticket.where(assigned_to_id: agent.id, status: %w[solved closed]).count
      }
    end

    # Kategori dağılımı
    @category_stats = Ticket.group(:category).count

    # Forum 24h dönüşüm istatistiği
    @total_forum_questions = CommunityQuestion.count
    @converted_questions   = CommunityQuestion.where(converted_to_ticket: true).count
    @conversion_rate       = @total_forum_questions.positive? ? ((@converted_questions.to_f / @total_forum_questions) * 100).round(1) : 0.0
  end

  def export_csv
    tickets = Ticket.recent_first

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "Talep No",
        "Konu",
        "Müşteri Adı",
        "Müşteri E-posta",
        "Durum",
        "Öncelik",
        "Kategori",
        "Atanan Temsilci",
        "SLA İhlali",
        "Oluşturulma Tarihi",
        "İlk Yanıt Tarihi",
        "Çözülme Tarihi"
      ]

      tickets.each do |t|
        csv << [
          t.ticket_number,
          t.subject,
          t.customer_name,
          t.customer_email,
          t.status.upcase,
          t.priority.upcase,
          t.category,
          t.assigned_to&.name || "Atanmamış",
          t.sla_breached ? "İHLAL" : "Zamanında",
          t.created_at.strftime("%Y-%m-%d %H:%M"),
          t.first_responded_at&.strftime("%Y-%m-%d %H:%M") || "Yanıt Yok",
          t.solved_at&.strftime("%Y-%m-%d %H:%M") || "Çözülmedi"
        ]
      end
    end

    send_data csv_data, filename: "pulsedesk-rapor-#{Date.today}.csv", type: "text/csv; charset=utf-8"
  end
end

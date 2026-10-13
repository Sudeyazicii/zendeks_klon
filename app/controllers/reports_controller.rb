require "csv"

class ReportsController < ApplicationController
  before_action :require_agent!

  def index
    # Tarih aralığı filtresi
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @end_date   = params[:end_date].present? ? Date.parse(params[:end_date]) : nil

    base_scope = Ticket.all
    if @start_date.present?
      base_scope = base_scope.where("created_at >= ?", @start_date.beginning_of_day)
    end
    if @end_date.present?
      base_scope = base_scope.where("created_at <= ?", @end_date.end_of_day)
    end

    @total_tickets    = base_scope.count
    @open_tickets     = base_scope.active_tickets.count
    @solved_tickets   = base_scope.where(status: %w[solved closed]).count
    @breached_tickets = base_scope.breached.count

    @compliance_rate = @total_tickets.positive? ? (((@total_tickets - @breached_tickets).to_f / @total_tickets) * 100).round(1) : 100.0

    # Ortalama ilk yanıt süresi (yalnızca yanıtlanmış kayıtlar)
    responded_tickets = base_scope.where.not(first_responded_at: nil)
    @responded_count = responded_tickets.count
    @avg_first_response_minutes = if @responded_count.positive?
      (responded_tickets.sum { |t| t.first_responded_at - t.created_at } / @responded_count / 60.0).round(1)
    else
      nil
    end

    # Ortalama çözüm süresi (yalnızca çözülmüş kayıtlar)
    solved_tickets_scope = base_scope.where.not(solved_at: nil)
    @solved_count = solved_tickets_scope.count
    @avg_resolution_hours = if @solved_count.positive?
      (solved_tickets_scope.sum { |t| t.solved_at - t.created_at } / @solved_count / 3600.0).round(1)
    else
      nil
    end

    # Temsilci başına iş yükü
    @agents = User.agents.map do |agent|
      assigned = base_scope.where(assigned_to_id: agent.id)
      {
        name: agent.name,
        department: agent.department,
        assigned_count: assigned.active_tickets.count,
        solved_count: assigned.where(status: %w[solved closed]).count
      }
    end

    # Kategori dağılımı
    @category_stats = base_scope.group(:category).count

    # Forum 24h dönüşüm istatistiği
    @total_forum_questions = CommunityQuestion.count
    @converted_questions   = CommunityQuestion.where(converted_to_ticket: true).count
    @conversion_rate       = @total_forum_questions.positive? ? ((@converted_questions.to_f / @total_forum_questions) * 100).round(1) : 0.0

    # Tarih filtresi aktifse bilgi mesajı
    @date_filter_active = @start_date.present? || @end_date.present?
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

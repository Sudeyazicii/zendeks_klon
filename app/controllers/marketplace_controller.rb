class MarketplaceController < ApplicationController
  before_action :ensure_user_logged_in!

  def index
    AiAgent.seed_default_agents! if AiAgent.count == 0

    @agents = AiAgent.active.order(id: :asc)
    @active_rentals = AgentRental.active_now.includes(:ai_agent)
    @bayram_pack_active = @active_rentals.count >= 5

    # Genel Metrikler
    @total_rented_count = @active_rentals.count
    @total_tickets_processed = AgentRental.sum(:tickets_processed_count)
    @total_tickets_solved = AgentRental.sum(:tickets_solved_count)
    @total_sla_saved = AgentRental.sum(:sla_violations_prevented)
    @total_cost_saved = AgentRental.all.sum(&:human_cost_saved)

    # İnsan Onayı Bekleyen Biletler (Human-in-the-Loop Queue)
    @pending_reviews = AgentExecutionLog.pending_review.includes(:ai_agent, :ticket).order(created_at: :desc)

    # Canlı Ajan İşlem Akışı (Live Audit Stream)
    @recent_logs = AgentExecutionLog.recent_first.includes(:ai_agent, :ticket).limit(10)
  end

  def hire_bayram_pack
    duration_days = (params[:duration_days] || 7).to_i
    rentals = AgentOrchestratorService.hire_bayram_pack!(current_user, duration_days: duration_days)

    redirect_to marketplace_path, notice: "🌙 Bayram Yoğunluk Kalkanı başarıyla aktifleştirildi! 5 uzman destek ajanı göreve başladı."
  end

  def rent_agent
    agent = AiAgent.find(params[:id])
    duration_days = (params[:duration_days] || 7).to_i
    require_human_approval = params[:require_human_approval] == "1"

    rental = AgentOrchestratorService.rent_single_agent!(agent, current_user, duration_days: duration_days, require_human_approval: require_human_approval)
    redirect_to marketplace_path, notice: "#{agent.name} (#{agent.role_title}) başarıyla kiralandı ve göreve başladı."
  end

  def cancel_rental
    rental = AgentRental.find(params[:id])
    agent_name = rental.ai_agent.name
    AgentOrchestratorService.terminate_rental!(rental)

    redirect_to marketplace_path, notice: "#{agent_name} kiralama sözleşmesi sonlandırıldı."
  end

  def simulate_surge
    count = (params[:count] || 10).to_i
    tickets = AgentOrchestratorService.simulate_bayram_surge!(current_user, count)

    redirect_to marketplace_path, notice: "⚡ #{tickets.size} biletlik Bayram Fırtınası Simülasyonu tamamlandı! Ajanlar talepleri otonom karşıladı."
  end

  def review_queue
    @pending_reviews = AgentExecutionLog.pending_review.includes(:ai_agent, :ticket).order(created_at: :desc)
  end

  def approve_log
    log = AgentExecutionLog.find(params[:id])
    log.approve_and_send!(current_user)

    redirect_back fallback_location: marketplace_path, notice: "✓ ##{log.ticket.ticket_number} için #{log.ai_agent.name} yanıtı onaylandı ve müşteriye gönderildi."
  end

  def reject_log
    log = AgentExecutionLog.find(params[:id])
    note = params[:internal_note].presence || "Temsilci bilet kontrolünü manuel devraldı."
    log.reject_and_takeover!(current_user, internal_note: note)

    redirect_back fallback_location: marketplace_path, alert: "##{log.ticket.ticket_number} için ajan önerisi reddedildi ve bilet üzerinize atandı."
  end

  private

  def ensure_user_logged_in!
    redirect_to login_path, alert: "Pazaryerine erişmek için giriş yapmalısınız." unless current_user
  end
end

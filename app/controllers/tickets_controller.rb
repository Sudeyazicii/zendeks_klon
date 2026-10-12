class TicketsController < ApplicationController
  before_action :set_ticket, only: [:show, :update_status, :reopen, :close, :merge, :assign]

  def index
    # Her listelemede SLA ihlallerini kontrol et
    Ticket.unresolved.find_each(&:check_sla_breach!)

    @status_filter = params[:status]
    @priority_filter = params[:priority]
    @category_filter = params[:category]

    @tickets = Ticket.recent_first

    case @status_filter
    when "new", "open", "pending", "solved", "closed"
      @tickets = @tickets.where(status: @status_filter)
    when "breached"
      @tickets = @tickets.breached
    when "unassigned"
      @tickets = @tickets.unassigned
    end

    if @priority_filter.present? && Ticket::PRIORITIES.include?(@priority_filter)
      @tickets = @tickets.where(priority: @priority_filter)
    end

    if @category_filter.present?
      @tickets = @tickets.where(category: @category_filter)
    end

    if params[:query].present?
      q = "%#{params[:query]}%"
      @tickets = @tickets.where("ticket_number LIKE ? OR subject LIKE ? OR customer_name LIKE ?", q, q, q)
    end

    @total_count      = Ticket.count
    @new_count        = Ticket.where(status: "new").count
    @open_count       = Ticket.where(status: "open").count
    @pending_count    = Ticket.where(status: "pending").count
    @solved_count     = Ticket.where(status: "solved").count
    @closed_count     = Ticket.where(status: "closed").count
    @breached_count   = Ticket.breached.count
    @unassigned_count = Ticket.unassigned.active_tickets.count
  end

  def show
    @ticket.check_sla_breach!
    @comments = @ticket.ticket_comments
    @new_comment = TicketComment.new(
      author_role: current_user.staff? ? "agent" : "customer",
      author_name: current_user.name
    )
    @canned_responses = CannedResponse.all
    @relevant_articles = Article.search_relevant(@ticket.subject)
    @similar_tickets = @ticket.similar_tickets
    @agents = User.agents
  end

  def new
    @ticket = Ticket.new(
      priority: "medium",
      category: "Genel Destek",
      customer_name: current_user.customer? ? current_user.name : "",
      customer_email: current_user.customer? ? current_user.email : ""
    )
    @agents = User.agents
  end

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.user = current_user if current_user.customer?

    if @ticket.save
      # Temsilcilere bildirim oluştur
      User.agents.find_each do |agent|
        agent.notifications.create(
          title: "Yeni Destek Talebi: ##{@ticket.ticket_number}",
          message: "#{@ticket.customer_name} tarafından yeni bir talep açıldı: '#{@ticket.subject}'",
          notifiable: @ticket
        )
      end

      redirect_to @ticket, notice: "Destek talebi ##{@ticket.ticket_number} başarıyla oluşturuldu."
    else
      @agents = User.agents
      render :new, status: :unprocessable_entity
    end
  end

  def update_status
    target_status = params[:status].to_s

    if @ticket.can_transition_to?(target_status)
      @ticket.transition_to!(target_status)
      redirect_to @ticket, notice: "Talep durumu '#{target_status.upcase}' olarak güncellendi."
    else
      redirect_to @ticket, alert: "Geçersiz durum geçişi: '#{@ticket.status.upcase}' durumundan '#{target_status.upcase}' durumuna doğrudan geçilemez."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @ticket, alert: e.record.errors.full_messages.join(", ")
  end

  def reopen
    if %w[solved closed].include?(@ticket.status)
      @ticket.reopen!
      redirect_to @ticket, notice: "Talep başarıyla yeniden açıldı (AÇIK)."
    else
      redirect_to @ticket, alert: "Yalnızca çözülmüş veya kapatılmış talepler yeniden açılabilir."
    end
  end

  def close
    if @ticket.can_transition_to?("closed")
      @ticket.close!
      redirect_to @ticket, notice: "Talep başarıyla kapatıldı."
    else
      redirect_to @ticket, alert: "Bu talep doğrudan kapatılamaz."
    end
  end

  def merge
    target_ticket = Ticket.find(params[:target_ticket_id])
    if target_ticket.id == @ticket.id
      redirect_to @ticket, alert: "Bir talep kendisiyle birleştirilemez."
    else
      @ticket.merge_into!(target_ticket, agent_name: current_user.name)
      redirect_to target_ticket, notice: "##{@ticket.ticket_number} numaralı talep başarıyla bu taleple birleştirildi ve kapatıldı."
    end
  end

  def assign
    agent = User.find(params[:agent_id])
    @ticket.update!(assigned_to: agent)
    agent.notifications.create(
      title: "Talep Size Atandı",
      message: "##{@ticket.ticket_number} ('#{@ticket.subject}') talebi size atandı.",
      notifiable: @ticket
    )
    redirect_to @ticket, notice: "Talep #{agent.name} personeline başarıyla atandı."
  end

  def sla_dashboard
    Ticket.unresolved.find_each(&:check_sla_breach!)

    @total_tickets     = Ticket.count
    @breached_tickets  = Ticket.breached.count
    @on_time_tickets   = Ticket.where(status: %w[solved closed], sla_breached: false).count
    @active_sla_risk   = Ticket.unresolved.where("sla_due_at <= ? AND sla_breached = ?", Time.current + 1.hour, false).count
    @auto_converted    = CommunityQuestion.where(converted_to_ticket: true).count
    @unanswered_forum  = CommunityQuestion.unanswered.count
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def ticket_params
    params.require(:ticket).permit(:subject, :description, :customer_name, :customer_email, :priority, :category, :tags, :assigned_to_id)
  end
end

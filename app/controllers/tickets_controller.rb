class TicketsController < ApplicationController
  before_action :set_ticket, only: [:show, :update_status, :reopen]

  def index
    # Her listelemede SLA ihlallerini kontrol et
    Ticket.unresolved.find_each(&:check_sla_breach!)

    @status_filter = params[:status]
    @priority_filter = params[:priority]

    @tickets = Ticket.recent_first

    case @status_filter
    when "new", "open", "pending", "solved"
      @tickets = @tickets.where(status: @status_filter)
    when "breached"
      @tickets = @tickets.breached
    end

    if @priority_filter.present? && Ticket::PRIORITIES.include?(@priority_filter)
      @tickets = @tickets.where(priority: @priority_filter)
    end

    if params[:query].present?
      q = "%#{params[:query]}%"
      @tickets = @tickets.where("ticket_number LIKE ? OR subject LIKE ? OR customer_name LIKE ?", q, q, q)
    end

    @total_count    = Ticket.count
    @new_count      = Ticket.where(status: "new").count
    @open_count     = Ticket.where(status: "open").count
    @pending_count  = Ticket.where(status: "pending").count
    @solved_count   = Ticket.where(status: "solved").count
    @breached_count = Ticket.breached.count
  end

  def show
    @ticket.check_sla_breach!
    @comments = @ticket.ticket_comments
    @new_comment = TicketComment.new(author_role: "agent")
  end

  def new
    @ticket = Ticket.new(priority: "medium")
  end

  def create
    @ticket = Ticket.new(ticket_params)

    if @ticket.save
      redirect_to @ticket, notice: "Destek talebi ##{@ticket.ticket_number} başarıyla oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update_status
    target_status = params[:status].to_s

    if @ticket.can_transition_to?(target_status)
      @ticket.transition_to!(target_status)
      redirect_to @ticket, notice: "Talep durumu '#{I18n.t("statuses.#{target_status}", default: target_status.upcase)}' olarak güncellendi."
    else
      redirect_to @ticket, alert: "Geçersiz durum geçişi: '#{@ticket.status.upcase}' durumundan '#{target_status.upcase}' durumuna doğrudan geçilemez."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @ticket, alert: e.record.errors.full_messages.join(", ")
  end

  def reopen
    if @ticket.status == "solved"
      @ticket.reopen!
      redirect_to @ticket, notice: "Talep başarıyla yeniden açıldı (AÇIK)."
    else
      redirect_to @ticket, alert: "Yalnızca çözülmüş talepler yeniden açılabilir."
    end
  end

  def sla_dashboard
    Ticket.unresolved.find_each(&:check_sla_breach!)

    @total_tickets     = Ticket.count
    @breached_tickets  = Ticket.breached.count
    @on_time_tickets   = Ticket.where(status: "solved", sla_breached: false).count
    @active_sla_risk   = Ticket.unresolved.where("sla_due_at <= ? AND sla_breached = ?", Time.current + 1.hour, false).count
    @auto_converted    = CommunityQuestion.where(converted_to_ticket: true).count
    @unanswered_forum  = CommunityQuestion.unanswered.count
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def ticket_params
    params.require(:ticket).permit(:subject, :description, :customer_name, :customer_email, :priority)
  end
end

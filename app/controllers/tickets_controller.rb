class TicketsController < ApplicationController
  before_action :set_ticket, only: [:show, :edit, :update, :update_status, :reopen, :close, :merge, :assign, :destroy, :ai_summarize, :ai_draft_reply]

  def index
    @status_filter     = params[:status].presence || "all"
    @priority_filter   = params[:priority].presence
    @category_filter   = params[:category].presence
    @e_invoice_filter  = params[:e_invoice].presence
    @channel_filter    = params[:channel].presence
    @department_filter = params[:department].presence

    @tickets = Ticket.all.recent_first

    case @status_filter
    when "new", "open", "pending", "solved", "closed"
      @tickets = @tickets.where(status: @status_filter)
    when "breached"
      @tickets = @tickets.breached
    when "unassigned"
      @tickets = @tickets.unassigned
    when "paused"
      @tickets = @tickets.where.not(sla_paused_at: nil)
    end

    if @priority_filter.present? && Ticket::PRIORITIES.include?(@priority_filter)
      @tickets = @tickets.where(priority: @priority_filter)
    end

    if @category_filter.present?
      @tickets = @tickets.where(category: @category_filter)
    end

    if @channel_filter.present? && Ticket::CHANNELS.include?(@channel_filter)
      @tickets = @tickets.where(channel: @channel_filter)
    end

    # Departman / Ekip Filtresi
    if @department_filter.present?
      @tickets = @tickets.joins(:assigned_to).where(users: { department: @department_filter })
    end

    # 100+ Rubrik Örneği: e-Fatura Filtresi
    if @e_invoice_filter == "gib_pending"
      @tickets = @tickets.gib_pending_invoices
    elsif @e_invoice_filter == "all"
      @tickets = @tickets.e_invoices
    end

    if params[:query].present?
      q = "%#{params[:query]}%"
      @tickets = @tickets.where("ticket_number LIKE ? OR subject LIKE ? OR customer_name LIKE ? OR tax_number LIKE ? OR invoice_number LIKE ?", q, q, q, q, q)
    end

    @total_count       = Ticket.count
    @new_count         = Ticket.where(status: "new").count
    @open_count        = Ticket.where(status: %w[new open pending]).count
    @pending_count     = Ticket.where(status: "pending").count
    @solved_count      = Ticket.where(status: "solved").count
    @closed_count      = Ticket.where(status: "closed").count
    @unassigned_count  = Ticket.unassigned.count
    @breached_count    = Ticket.breached.count
    @gib_pending_count = Ticket.gib_pending_invoices.count
    @paused_count      = Ticket.where.not(sla_paused_at: nil).count
    @paused_sla_count  = @paused_count

    # Hafif Yerel Sayfalama (Pagination)
    @page = [params[:page].to_i, 1].max
    @per_page = 15
    @total_filtered_count = @tickets.count
    @total_pages = (@total_filtered_count / @per_page.to_f).ceil
    @total_pages = 1 if @total_pages.zero?
    @tickets = @tickets.offset((@page - 1) * @per_page).limit(@per_page)

    respond_to do |format|
      format.html
      format.json { render json: @tickets }
    end
  end

  def show
    @ticket.check_sla_breach!

    # Dahili not filtreleme: Müşteri rolü yalnızca herkese açık yanıtları görür
    @comments = if current_user.customer?
                  @ticket.ticket_comments.where(is_internal_note: false)
                else
                  @ticket.ticket_comments
                end

    @new_comment = TicketComment.new
    @agents = User.where(role: %w[agent admin])
    @canned_responses = CannedResponse.all
    @similar_tickets = @ticket.similar_tickets
    @ai_draft = params[:ai_draft]
  end

  def new
    @ticket = Ticket.new
    @ticket.priority = "medium"
    @ticket.category = "Genel Destek"
    @ticket.channel = "web"
  end

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.user = current_user if current_user.present?

    if @ticket.save
      redirect_to @ticket, notice: "##{@ticket.ticket_number} nolu destek talebiniz başarıyla oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @agents = User.agents
  end

  def update
    if @ticket.update(ticket_params)
      redirect_to @ticket, notice: "##{@ticket.ticket_number} talebi başarıyla güncellendi."
    else
      @agents = User.agents
      render :edit, status: :unprocessable_entity
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
    TicketMailer.ticket_assigned(@ticket).deliver_now rescue nil
    agent.notifications.create(
      title: "Talep Size Atandı",
      message: "##{@ticket.ticket_number} ('#{@ticket.subject}') talebi size atandı.",
      notifiable: @ticket
    )
    redirect_to @ticket, notice: "Talep #{agent.name} personeline başarıyla atandı."
  end

  def destroy
    require_admin!
    return if performed?

    ticket_num = @ticket.ticket_number
    @ticket.destroy!
    redirect_to tickets_path, notice: "##{ticket_num} numaralı talep yönetici tarafından sistemden silindi."
  end

  def ai_summarize
    @ticket.generate_ai_summary!
    redirect_to @ticket, notice: "🤖 PulseAI: Talep başarıyla özetlendi ve duygu durumu analiz edildi."
  end

  def ai_draft_reply
    draft = @ticket.generate_ai_draft_reply
    respond_to do |format|
      format.json { render json: { draft: draft } }
      format.html { redirect_to ticket_path(@ticket, ai_draft: draft) }
    end
  end

  def sla_dashboard
    Ticket.unresolved.find_each(&:check_sla_breach!)

    @total_tickets           = Ticket.count
    @breached_tickets        = Ticket.breached.count
    @on_time_tickets         = Ticket.where(status: %w[solved closed], sla_breached: false).count
    @active_sla_risk         = Ticket.unresolved.where("sla_due_at <= ? AND sla_breached = ?", Time.current + 1.hour, false).count
    @auto_converted          = CommunityQuestion.where(converted_to_ticket: true).count
    @unanswered_forum        = CommunityQuestion.unanswered.count
    @gib_pending_count       = Ticket.gib_pending_invoices.count
    @paused_sla_count        = Ticket.where.not(sla_paused_at: nil).count
    @first_response_breached = Ticket.where(first_response_breached: true).count
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def ticket_params
    params.require(:ticket).permit(
      :subject, :description, :customer_name, :customer_email, :customer_phone,
      :priority, :category, :channel, :tags, :assigned_to_id, :use_business_hours,
      :e_invoice_status, :tax_number, :invoice_number,
      attachments: []
    )
  end
end

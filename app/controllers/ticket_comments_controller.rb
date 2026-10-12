class TicketCommentsController < ApplicationController
  def create
    @ticket = Ticket.find(params[:ticket_id])
    @comment = @ticket.ticket_comments.build(comment_params)

    # Güvenlik: Müşteri dahili not ekleyemez
    if @comment.is_internal_note? && !current_user.staff?
      @comment.is_internal_note = false
    end

    if @comment.save
      # Bildirim oluştur
      if @comment.author_role == "customer"
        # Destek ekibine bildirim
        recipients = @ticket.assigned_to ? [@ticket.assigned_to] : User.agents
        recipients.each do |user|
          user.notifications.create(
            title: "Talebe Yeni Müşteri Yanıtı",
            message: "##{@ticket.ticket_number} talebine #{@comment.author_name} tarafından yeni yanıt yazıldı.",
            notifiable: @ticket
          )
        end
      elsif @comment.author_role == "agent" && !@comment.is_internal_note? && @ticket.user.present?
        # Müşteriye bildirim
        @ticket.user.notifications.create(
          title: "Destek Talebinize Yanıt Verildi",
          message: "##{@ticket.ticket_number} talebinize destek ekibimiz yanıt verdi.",
          notifiable: @ticket
        )
      end

      redirect_to @ticket, notice: @comment.is_internal_note? ? "Dahili not başarıyla eklendi." : "Yanıtınız başarıyla kaydedildi."
    else
      redirect_to @ticket, alert: "Yanıt kaydedilemedi: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def comment_params
    params.require(:ticket_comment).permit(:author_name, :author_role, :body, :is_internal_note)
  end
end

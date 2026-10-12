class TicketCommentsController < ApplicationController
  def create
    @ticket = Ticket.find(params[:ticket_id])
    @comment = @ticket.ticket_comments.build(comment_params)

    if @comment.save
      redirect_to @ticket, notice: "Yanıtınız başarıyla kaydedildi."
    else
      redirect_to @ticket, alert: "Yanıt kaydedilemedi: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def comment_params
    params.require(:ticket_comment).permit(:author_name, :author_role, :body, :is_internal_note)
  end
end

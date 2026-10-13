class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:incoming_message]

  # POST /webhooks/incoming_message
  # Omnichannel: WhatsApp, Live Chat, Harici E-posta veya API'den gelen mesajları işler
  def incoming_message
    channel = params[:channel].presence_in(Ticket::CHANNELS) || "whatsapp"
    sender_name = params[:sender_name].presence || "WhatsApp Müşterisi"
    sender_contact = params[:sender_contact].presence || params[:phone].presence || "bilinmeyen@harici.com"
    subject = params[:subject].presence || "#{channel.capitalize} Kanalından Yeni Mesaj"
    message_body = params[:message].presence || params[:body].presence

    if message_body.blank?
      return render json: { error: "Mesaj içeriği (message/body) boş olamaz." }, status: :unprocessable_entity
    end

    # Mevcut açık bir bilet var mı kontrol et (telefon veya e-posta eşleşmesi)
    existing_ticket = if params[:ticket_number].present?
                        Ticket.find_by(ticket_number: params[:ticket_number])
                      else
                        Ticket.where(status: %w[new open pending])
                              .where("customer_email = :contact OR customer_phone = :contact", contact: sender_contact)
                              .order(created_at: :desc)
                              .first
                      end

    if existing_ticket
      # Açık bilete yeni yanıt olarak ekle
      comment = existing_ticket.ticket_comments.create!(
        author_name: sender_name,
        author_role: "customer",
        body: "[#{channel.upcase} Mesajı]: #{message_body}"
      )
      render json: {
        status: "success",
        action: "comment_added",
        ticket_number: existing_ticket.ticket_number,
        comment_id: comment.id
      }, status: :ok
    else
      # Yeni bilet aç
      email = sender_contact.include?("@") ? sender_contact : "#{sender_contact.gsub(/\D/, '')}@whatsapp.pulsedesk.local"
      phone = sender_contact unless sender_contact.include?("@")

      ticket = Ticket.create!(
        subject: subject,
        description: message_body,
        customer_name: sender_name,
        customer_email: email,
        customer_phone: phone,
        channel: channel,
        priority: "medium",
        category: "Genel Destek"
      )

      # Müşteriye bildirim / mail
      TicketMailer.ticket_created(ticket).deliver_now rescue nil

      render json: {
        status: "success",
        action: "ticket_created",
        ticket_number: ticket.ticket_number,
        ticket_id: ticket.id
      }, status: :created
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end

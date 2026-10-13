class TicketMailer < ApplicationMailer
  default from: "destek@pulsedesk.local"

  def ticket_created(ticket)
    @ticket = ticket
    @recipient_email = ticket.customer_email
    subject = "[PulseDesk ##{ticket.ticket_number}] Destek Talebiniz Alındı: #{ticket.subject}"

    body_text = "Merhaba #{ticket.customer_name},\n\n##{ticket.ticket_number} numaralı destek talebiniz başarıyla oluşturulmuştur.\nÖncelik: #{ticket.priority.upcase}\nKategori: #{ticket.category}\n\nEkibimiz en kısa sürede talebinizi inceleyecektir."

    SentEmail.log_email!(
      to_email: @recipient_email,
      subject: subject,
      body: body_text,
      mail_type: "ticket_created",
      ticket_id: ticket.id
    )

    mail(to: @recipient_email, subject: subject)
  end

  def ticket_assigned(ticket)
    return unless ticket.assignee&.email

    @ticket = ticket
    @recipient_email = ticket.assignee.email
    subject = "[PulseDesk Atama] ##{ticket.ticket_number} Talebi Size Atandı"
    body_text = "Merhaba #{ticket.assignee.name},\n\n##{ticket.ticket_number} numaralı bilet (#{ticket.subject}) size atanmıştır.\nÖncelik: #{ticket.priority.upcase}"

    SentEmail.log_email!(
      to_email: @recipient_email,
      subject: subject,
      body: body_text,
      mail_type: "ticket_assigned",
      ticket_id: ticket.id
    )

    mail(to: @recipient_email, subject: subject)
  end

  def new_reply(ticket, comment)
    @ticket = ticket
    @comment = comment

    # Müşteri yorum yaptıysa atanan çalışana, çalışan yanıtladıysa müşteriye gönder
    recipient = comment.author_role == "customer" ? ticket.assignee&.email : ticket.customer_email
    recipient ||= ticket.customer_email

    @recipient_email = recipient
    subject = "[PulseDesk ##{ticket.ticket_number}] Yeni Yanıt: #{ticket.subject}"
    body_text = "Merhaba,\n\n##{ticket.ticket_number} numaralı talebe yeni bir yanıt eklendi:\n\n\"#{comment.body}\"\n\n— #{comment.author_name}"

    SentEmail.log_email!(
      to_email: @recipient_email,
      subject: subject,
      body: body_text,
      mail_type: "new_reply",
      ticket_id: ticket.id
    )

    mail(to: @recipient_email, subject: subject)
  end

  def sla_warning(ticket)
    @ticket = ticket
    @recipient_email = ticket.assignee&.email || "destek-yonetici@pulsedesk.local"
    subject = "[PulseDesk SLA UYARISI] ##{ticket.ticket_number} Süresi Yaklaşıyor / İhlal Edildi"
    body_text = "DİKKAT: ##{ticket.ticket_number} nolu biletin SLA süresi dolmak üzeredir veya aşılmıştır.\nKonu: #{ticket.subject}\nÖncelik: #{ticket.priority.upcase}"

    SentEmail.log_email!(
      to_email: @recipient_email,
      subject: subject,
      body: body_text,
      mail_type: "sla_warning",
      ticket_id: ticket.id
    )

    mail(to: @recipient_email, subject: subject)
  end
end

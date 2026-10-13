require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "WhatsApp webhook üzerinden yeni talep başarıyla açılır" do
    assert_difference("Ticket.count", 1) do
      post "/webhooks/incoming_message", params: {
        channel: "whatsapp",
        sender_name: "Ali Can",
        sender_contact: "05551234567",
        subject: "WhatsApp Sipariş Sorusu",
        message: "Merhaba kargom nerede kaldı acaba?"
      }
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "success", json["status"]
    assert_equal "ticket_created", json["action"]

    ticket = Ticket.find_by(ticket_number: json["ticket_number"])
    assert_equal "whatsapp", ticket.channel
    assert_equal "05551234567", ticket.customer_phone
    assert_equal "Ali Can", ticket.customer_name
  end

  test "Aynı WhatsApp numarasından gelen ikinci mesaj mevcut açık bilete yorum olarak eklenir (Mükerrer engelleme)" do
    ticket = Ticket.create!(
      subject: "İlk WhatsApp Talebi",
      description: "İlk mesaj",
      customer_name: "Ayşe Kaya",
      customer_email: "ayse@whatsapp.pulsedesk.local",
      customer_phone: "05329876543",
      channel: "whatsapp"
    )

    assert_no_difference("Ticket.count") do
      assert_difference("TicketComment.count", 1) do
        post "/webhooks/incoming_message", params: {
          channel: "whatsapp",
          sender_name: "Ayşe Kaya",
          sender_contact: "05329876543",
          message: "Ayrıca faturamı da e-posta atabilir misiniz?"
        }
      end
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "comment_added", json["action"]
    assert_equal ticket.ticket_number, json["ticket_number"]
  end
end

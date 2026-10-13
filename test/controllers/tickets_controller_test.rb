require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ticket = Ticket.create!(
      subject: "Fatura kesim hatası",
      description: "Son faturada vergi oranı yanlış hesaplanmış görünüyor.",
      customer_name: "Zeynep Kaya",
      customer_email: "zeynep@example.com",
      priority: "high"
    )
  end

  test "destek talepleri ana sayfası başarıyla açılır" do
    get tickets_url
    assert_response :success
    assert_select "h1", "Destek Talepleri"
  end

  test "belirli bir talep detayı başarıyla görüntülenir" do
    get ticket_url(@ticket)
    assert_response :success
    assert_select "h1", @ticket.subject
  end

  test "yeni destek talebi formu açılır" do
    get new_ticket_url
    assert_response :success
  end

  test "yeni destek talebi başarıyla oluşturulur ve yönlendirilir" do
    assert_difference("Ticket.count", 1) do
      post tickets_url, params: {
        ticket: {
          subject: "Yeni API anahtarı talebi",
          description: "Staging ortamı için ikinci bir secret key oluşturmak istiyoruz.",
          customer_name: "Ali Vural",
          customer_email: "ali@vural.com",
          priority: "urgent"
        }
      }
    end

    new_ticket = Ticket.last
    assert_redirected_to ticket_url(new_ticket)
    assert_equal "urgent", new_ticket.priority
    assert_match(/^PD-\d{4}$/, new_ticket.ticket_number)
  end

  test "geçerli durum geçişi veritabanında güncellenir (new -> open)" do
    assert_equal "new", @ticket.status
    patch update_status_ticket_url(@ticket), params: { status: "open" }

    assert_redirected_to ticket_url(@ticket)
    assert_equal "open", @ticket.reload.status
  end

  test "geçersiz durum geçişi engellenir ve hata mesajı gösterilir (new -> solved)" do
    assert_equal "new", @ticket.status
    patch update_status_ticket_url(@ticket), params: { status: "solved" }

    assert_redirected_to ticket_url(@ticket)
    assert_equal "new", @ticket.reload.status, "new doğrudan solved olamamalı"
    assert_match(/Geçersiz durum geçişi/i, flash[:alert])
  end

  test "çözülmüş talep başarıyla yeniden açılır (solved -> open)" do
    @ticket.transition_to!("open")
    @ticket.transition_to!("solved")
    assert_equal "solved", @ticket.status

    post reopen_ticket_url(@ticket)
    assert_redirected_to ticket_url(@ticket)
    assert_equal "open", @ticket.reload.status
  end

  test "talep yanıtı kaydedilir ve 'new' talep otomatik olarak 'open' yapılır" do
    assert_equal "new", @ticket.status

    assert_difference("@ticket.ticket_comments.count", 1) do
      post ticket_ticket_comments_url(@ticket), params: {
        ticket_comment: {
          author_name: "Destek Sorumlusu",
          author_role: "agent",
          body: "Talebinizi aldık, fatura departmanına iletiyoruz."
        }
      }
    end

    assert_redirected_to ticket_url(@ticket)
    assert_equal "open", @ticket.reload.status
    assert_not_nil @ticket.first_responded_at
  end

  test "SLA & Otomasyon paneli başarıyla açılır" do
    get sla_dashboard_url
    assert_response :success
    assert_select "h1", "SLA & Otomasyon Takip Paneli"
  end

  test "yönetici yetkisi ile destek talebi silinebilir" do
    # Yönetici rolüne geç
    post switch_role_url, params: { role: "admin" }

    assert_difference("Ticket.count", -1) do
      delete ticket_url(@ticket)
    end
    assert_redirected_to tickets_url
  end

  test "müşteri yetkisi ile destek talebi silinemez" do
    # Müşteri rolüne geç
    post switch_role_url, params: { role: "customer" }

    assert_no_difference("Ticket.count") do
      delete ticket_url(@ticket)
    end
    assert_redirected_to root_url
  end

  test "e-Fatura alanları ile yeni destek talebi oluşturulur ve 7 günlük GİB SLA süresi tanımlanır" do
    post switch_role_url, params: { role: "agent" }

    assert_difference("Ticket.count", 1) do
      post tickets_url, params: {
        ticket: {
          subject: "GİB e-Fatura onayında bekleme",
          description: "e-Fatura portalında onay kodu bekleniyor.",
          customer_name: "Metin Muhasebe",
          customer_email: "metin@muhasebe.com",
          priority: "high",
          e_invoice_status: "gib_pending",
          tax_number: "9876543210",
          invoice_number: "GIB2026000001"
        }
      }
    end

    new_t = Ticket.last
    assert_equal "gib_pending", new_t.e_invoice_status
    assert_equal "9876543210", new_t.tax_number
    assert_in_delta new_t.created_at + 7.days, new_t.sla_due_at, 2.seconds
  end

  test "PulseAI ile talep özetleme endpoint'i başarıyla çalışır" do
    post switch_role_url, params: { role: "agent" }

    post ai_summarize_ticket_url(@ticket)
    assert_redirected_to ticket_url(@ticket)
    assert_not_nil @ticket.reload.ai_summary
  end

  test "PulseAI ile yanıt taslağı üretme endpoint'i JSON taslak döner" do
    post switch_role_url, params: { role: "agent" }

    post ai_draft_reply_ticket_url(@ticket), as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json["draft"], "Merhaba"
  end
end


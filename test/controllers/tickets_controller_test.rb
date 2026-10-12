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
end

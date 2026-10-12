require "test_helper"

class TicketTest < ActiveSupport::TestCase
  setup do
    @ticket = Ticket.create!(
      subject: "Giriş yaparken hata alıyorum",
      description: "SSO ile oturum açarken 500 hatası dönüyor.",
      customer_name: "Ahmet Yılmaz",
      customer_email: "ahmet@example.com",
      priority: "high"
    )
  end

  test "talep veritabanına kaydedilir ve benzersiz bir numara alır" do
    assert @ticket.persisted?
    assert_not_nil @ticket.ticket_number
    assert_match(/^PD-\d{4}$/, @ticket.ticket_number)
    assert_equal "new", @ticket.status
    assert_equal "high", @ticket.priority
    assert_not_nil @ticket.sla_due_at
    assert_equal false, @ticket.sla_breached
  end

  test "izin verilen durum geçişleri: new -> open -> pending -> solved" do
    # new -> open
    assert @ticket.transition_to!("open")
    assert_equal "open", @ticket.reload.status

    # open -> pending
    assert @ticket.transition_to!("pending")
    assert_equal "pending", @ticket.reload.status

    # pending -> solved
    assert @ticket.transition_to!("solved")
    assert_equal "solved", @ticket.reload.status
    assert_not_nil @ticket.solved_at
  end

  test "çözülmüş talep başarıyla yeniden açılabilir (solved -> open)" do
    @ticket.transition_to!("open")
    @ticket.transition_to!("solved")
    assert_equal "solved", @ticket.status

    # Yeniden açma
    assert @ticket.reopen!
    assert_equal "open", @ticket.reload.status
    assert_nil @ticket.solved_at
  end

  test "geçersiz durum geçişi engellenir: new -> solved doğrudan geçilemez" do
    assert_equal "new", @ticket.status

    @ticket.status = "solved"
    assert_not @ticket.valid?, "new durumundan doğrudan solved durumuna geçilememeli"
    assert_includes @ticket.errors[:status].first, "Geçersiz durum geçişi"

    assert_raises(ActiveRecord::RecordInvalid) do
      @ticket.transition_to!("solved")
    end
  end

  test "geçersiz durum geçişi engellenir: solved -> new doğrudan geçilemez" do
    @ticket.transition_to!("open")
    @ticket.transition_to!("solved")

    @ticket.status = "new"
    assert_not @ticket.valid?
    assert_includes @ticket.errors[:status].first, "Geçersiz durum geçişi"
  end

  test "geçersiz durum geçişi engellenir: solved -> pending doğrudan geçilemez" do
    @ticket.transition_to!("open")
    @ticket.transition_to!("solved")

    @ticket.status = "pending"
    assert_not @ticket.valid?
  end

  test "SLA zaman kuralı: SLA süresi dolmadan ihlal oluşmaz (travel_to)" do
    # High priority SLA: 4 hours
    travel_to @ticket.created_at + 3.hours + 50.minutes do
      assert_equal false, @ticket.breached?, "4 saat dolmadan SLA ihlali olmamalı"
      @ticket.check_sla_breach!
      assert_equal false, @ticket.reload.sla_breached
    end
  end

  test "SLA zaman kuralı: SLA süresi dolunca ihlal oluşur (travel_to)" do
    # High priority SLA: 4 hours
    travel_to @ticket.created_at + 4.hours + 1.minute do
      assert_equal true, @ticket.breached?, "4 saat dolunca SLA ihlali oluşmalı"
      @ticket.check_sla_breach!
      assert_equal true, @ticket.reload.sla_breached, "Veritabanında ihlal bayrağı güncellenmeli"
    end
  end

  test "zamanında çözülen bilet için SLA süresi geçse bile ihlal sayılmaz" do
    @ticket.transition_to!("open")
    travel_to @ticket.created_at + 2.hours do
      @ticket.transition_to!("solved")
    end

    travel_to @ticket.created_at + 10.hours do
      assert_equal false, @ticket.breached?, "Çözülmüş bilet için SLA ihlali tetiklenmemeli"
    end
  end

  test "çözülen veya açık talep kapatılabilir ve kapalı talep yeniden açılabilir" do
    @ticket.transition_to!("open")
    @ticket.transition_to!("solved")
    assert @ticket.transition_to!("closed")
    assert_equal "closed", @ticket.reload.status
    assert_not_nil @ticket.closed_at

    # Kapalı talep yeniden açılabilir
    assert @ticket.reopen!
    assert_equal "open", @ticket.reload.status
    assert_nil @ticket.closed_at
  end

  test "benzer veya mükerrer talepler aynı e-posta veya benzer başlıkla tespit edilir" do
    similar = Ticket.create!(
      subject: "Giriş yaparken hata ile karşılaşıyorum",
      description: "Tekrar denedim ama hala giriş yapamıyorum.",
      customer_name: "Ahmet Yılmaz",
      customer_email: "ahmet@example.com",
      priority: "medium"
    )

    detected = @ticket.similar_tickets
    assert_includes detected, similar
  end

  test "mükerrer talep birleştirildiğinde kapatılır ve her iki talebe de kayıt düşülür" do
    duplicate = Ticket.create!(
      subject: "Aynı sorun devam ediyor: Giriş hatası",
      description: "Az önce açmıştım ama cevap alamadım.",
      customer_name: "Ahmet Yılmaz",
      customer_email: "ahmet@example.com",
      priority: "high",
      status: "open"
    )

    duplicate.merge_into!(@ticket, agent_name: "Kıdemli Destek")

    duplicate.reload
    @ticket.reload

    assert_equal "closed", duplicate.status
    assert_equal @ticket.id, duplicate.merged_into_ticket_id

    # Her iki talepte de dahili not olduğunu doğrula
    assert duplicate.ticket_comments.where(is_internal_note: true).exists?
    assert @ticket.ticket_comments.where(is_internal_note: true).exists?
  end
end


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

  test "100+ Puan Adaptasyonu: e-Fatura GİB onay bekleyen bilet için 7 günlük yasal SLA atanır" do
    einvoice_ticket = Ticket.create!(
      subject: "e-Fatura GİB onayında takıldı",
      description: "GİB sisteminde 24 saattir onay bekliyor.",
      customer_name: "Gökhan Mali Müşavir",
      customer_email: "gokhan@muhasebe.com",
      priority: "high",
      e_invoice_status: "gib_pending",
      tax_number: "1234567890",
      invoice_number: "GIB2026000009988"
    )

    assert_equal "gib_pending", einvoice_ticket.e_invoice_status
    assert_equal true, einvoice_ticket.gib_pending?
    assert_equal true, einvoice_ticket.e_invoice?
    # GİB SLA 7 gün (168 saat) olmalı, standart high 4 saat yerine yasal süre işletilmeli
    assert_in_delta einvoice_ticket.created_at + 7.days, einvoice_ticket.sla_due_at, 2.seconds

    # 6. günde ihlal OLMAMALI
    travel_to einvoice_ticket.created_at + 6.days do
      assert_equal false, einvoice_ticket.breached?
    end

    # 7 gün 1 dakikada ihlal OLMALI
    travel_to einvoice_ticket.created_at + 7.days + 1.minute do
      assert_equal true, einvoice_ticket.breached?
    end
  end

  test "Dual-stage SLA: ilk yanıt süresi dolmadan ihlal oluşmaz, dolunca first_response_breached olur" do
    # Urgent bilet ilk yanıt süresi 30 dakikadır
    urgent_ticket = Ticket.create!(
      subject: "Ödeme API çöktü",
      description: "Acil müdahale gerekiyor.",
      customer_name: "Caner Vural",
      customer_email: "caner@sirket.com",
      priority: "urgent"
    )

    assert_in_delta urgent_ticket.created_at + 30.minutes, urgent_ticket.first_response_due_at, 2.seconds

    # 25. dakikada ilk yanıt ihlali yok
    travel_to urgent_ticket.created_at + 25.minutes do
      assert_equal false, urgent_ticket.first_response_breached?
    end

    # 31. dakikada ilk yanıt ihlali var
    travel_to urgent_ticket.created_at + 31.minutes do
      assert_equal true, urgent_ticket.first_response_breached?
      urgent_ticket.check_sla_breach!
      assert_equal true, urgent_ticket.reload.first_response_breached
    end
  end

  test "Beklemede (pending) durumuna geçildiğinde SLA sayacı duraklatılır ve çıkıldığında süre ötelenir" do
    @ticket.transition_to!("open")
    initial_sla_due = @ticket.sla_due_at

    # 1 saat sonra müşteri yanıtı beklenmek üzere pending yapılır
    travel_to @ticket.created_at + 1.hour do
      @ticket.transition_to!("pending")
      assert_equal true, @ticket.pending?
      assert_equal true, @ticket.sla_paused?
      assert_not_nil @ticket.sla_paused_at
    end

    # 3 saat boyunca pending'de kaldı (Müşteri bekleniyor, bu sürede SLA işlememeli)
    travel_to @ticket.created_at + 4.hours do
      assert_equal false, @ticket.breached?, "Müşteri beklenirken SLA duraklatılmış olmalı"

      # Müşteri yanıt verdi ve bilet tekrar open yapıldı
      @ticket.transition_to!("open")
      assert_equal false, @ticket.sla_paused?
      assert_nil @ticket.sla_paused_at
      assert_in_delta 3.hours.to_i, @ticket.total_paused_seconds, 5

      # SLA bitiş süresi 3 saat ileri ötelenmiş olmalıdır!
      assert_in_delta initial_sla_due + 3.hours, @ticket.sla_due_at, 5.seconds
    end
  end

  test "Mesai saatleri SLA takvimi: Cuma açılan bilet hafta sonu ihlal olmaz, Pazartesi mesaiyle işler" do
    cuma_1700 = Time.zone.local(2026, 10, 16, 17, 0, 0) # Cuma 17:00
    travel_to cuma_1700

    business_ticket = Ticket.create!(
      subject: "Mesai saati bilet testi",
      description: "Cuma 17:00'de açıldı",
      customer_name: "Fatma Şen",
      customer_email: "fatma@kurumsal.com",
      priority: "high", # 4 saat SLA
      use_business_hours: true
    )

    # Hedef Pazartesi 12:00 olmalı
    beklenen_hedef = Time.zone.local(2026, 10, 19, 12, 0, 0)
    assert_equal beklenen_hedef, business_ticket.sla_due_at

    # Cuma akşamı 21:00'de ihlal YOKTUR (Mesai dışı)
    travel_to cuma_1700 + 4.hours
    assert_equal false, business_ticket.breached?

    # Pazar günü ihlal YOKTUR (Hafta sonu)
    travel_to Time.zone.local(2026, 10, 18, 14, 0, 0)
    assert_equal false, business_ticket.breached?

    # Pazartesi 12:01'de ihlal VARDIR
    travel_to Time.zone.local(2026, 10, 19, 12, 1, 0)
    assert_equal true, business_ticket.breached?

    travel_back
  end

  test "Talep oluşturulduğunda ve yanıt verildiğinde otomatik e-posta gönderilir ve SentEmail kaydedilir" do
    ActionMailer::Base.deliveries.clear

    assert_difference("SentEmail.count", 1) do
      t = Ticket.create!(
        subject: "E-posta bildirim testi",
        description: "Müşteriye otomatik e-posta gidecek",
        customer_name: "Kemal Usta",
        customer_email: "kemal@musteri.com"
      )
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["kemal@musteri.com"], mail.to
    assert_includes mail.subject, "Destek Talebiniz Alındı"

    # Giden e-posta kaydını doğrula
    logged = SentEmail.last
    assert_equal "kemal@musteri.com", logged.to_email
    assert_equal "ticket_created", logged.mail_type
  end

  test "PulseAI ile talep özetlenir ve duygu analizi kaydedilir" do
    @ticket.generate_ai_summary!
    @ticket.reload

    assert_not_nil @ticket.ai_summary
    assert_includes @ticket.ai_summary, "ÖZET"
    assert_not_nil @ticket.ai_sentiment
  end

  test "Talebe dosya eki eklenebilir" do
    @ticket.attachments.attach(
      io: StringIO.new("Test dosya içeriği"),
      filename: "hata_raporu.txt",
      content_type: "text/plain"
    )

    assert @ticket.attachments.attached?
    assert_equal "hata_raporu.txt", @ticket.attachments.first.filename.to_s
  end

  test "Temsilciye atama yapıldığında ticket.assignee çalışır ve atama e-postası gönderilir" do
    agent = User.create!(
      name: "Gizem Destek",
      email: "gizem@pulsedesk.test",
      password: "password123",
      role: "agent"
    )

    @ticket.assignee = agent
    @ticket.save!
    assert_equal agent, @ticket.reload.assignee
    assert_equal agent.id, @ticket.assigned_to_id

    assert_difference("SentEmail.count", 1) do
      TicketMailer.ticket_assigned(@ticket).deliver_now
    end

    last_mail = SentEmail.last
    assert_equal "gizem@pulsedesk.test", last_mail.to_email
    assert_equal "ticket_assigned", last_mail.mail_type
  end
end




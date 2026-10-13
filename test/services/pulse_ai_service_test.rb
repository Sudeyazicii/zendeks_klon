require "test_helper"

class PulseAiServiceTest < ActiveSupport::TestCase
  setup do
    @ticket = Ticket.create!(
      subject: "Ödeme sisteminde acil hata çöktü",
      description: "Ödeme yaparken sistem çöktü ve param kesildi, lütfen acil yardım!",
      customer_name: "Mehmet Demir",
      customer_email: "mehmet@test.com",
      category: "Fatura & Ödeme",
      priority: "urgent"
    )
  end

  test "müşteri duygu durumunu ve aciliyetini doğru analiz eder" do
    analysis = PulseAiService.analyze_sentiment(@ticket)
    assert_equal :urgent_negative, analysis[:tone]
    assert_includes analysis[:label], "Acil"
    assert_includes analysis[:detected_keywords], "acil"
    assert_includes analysis[:detected_keywords], "çöktü"
  end

  test "talep için profesyonel ve empatik yanıt taslağı üretir" do
    draft = PulseAiService.generate_draft_reply(@ticket)
    assert_includes draft, "Merhaba Mehmet,"
    assert_includes draft, "Yaşadığınız aksaklık ve gecikme nedeniyle çok üzgünüz"
    assert_includes draft, "fatura ve ödeme"
    assert_includes draft, "PulseDesk Destek Ekibi"
  end

  test "talep için Türkçe yapılandırılmış özet çıkarır" do
    summary = PulseAiService.summarize(@ticket)
    assert_includes summary, "📌 [ÖZET]:"
    assert_includes summary, "Mehmet Demir"
    assert_includes summary, "Ödeme sisteminde acil hata çöktü"
  end
end

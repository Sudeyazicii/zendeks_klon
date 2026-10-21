require "test_helper"

class AgentOrchestratorServiceTest < ActiveSupport::TestCase
  setup do
    AiAgent.seed_default_agents!
    @rentals = AgentOrchestratorService.hire_bayram_pack!(duration_days: 7)
  end

  test "bayram paketi 5 ajanı da 7 günlüğüne kiralar" do
    assert_equal 5, @rentals.size
    assert_equal 5, AgentRental.active_now.count
  end

  test "e-fatura ve GİB konularında Atlas seçilir" do
    ticket = Ticket.new(
      subject: "e-Faturada VKN uyuşmazlığı var",
      description: "GİB 7 günlük itiraz süresi içinde düzeltilmeli",
      category: "Fatura & Ödeme"
    )
    agent = AgentOrchestratorService.best_agent_for(ticket)
    assert_equal "atlas_invoice", agent.code_name
  end

  test "teknik 502 Bad Gateway ve webhook konularında Nova seçilir" do
    ticket = Ticket.new(
      subject: "Ödeme sayfasında 502 Bad Gateway hatası",
      description: "Webhook secret HMAC imza hatası veriyor",
      category: "Teknik Hata"
    )
    agent = AgentOrchestratorService.best_agent_for(ticket)
    assert_equal "nova_tech", agent.code_name
  end

  test "öfkeli ve dava açacağını söyleyen müşteride Seren seçilir" do
    ticket = Ticket.new(
      subject: "Rezalet bir hizmet, dava açacağım paramı verin!",
      description: "Tüketici hakem heyetine vereceğim bayramım zehir oldu",
      category: "Genel Destek"
    )
    agent = AgentOrchestratorService.best_agent_for(ticket)
    assert_equal "seren_sentiment", agent.code_name
  end

  test "standart kargo gecikmesi biletini Aura otonom çözer" do
    ticket = Ticket.create!(
      subject: "Kargom bayramdan önce teslim edilecek mi?",
      description: "YK-991203 takip no'lu paketim şubede görünüyor",
      customer_name: "Ayşe Hanım",
      customer_email: "ayse@test.com",
      category: "Genel Destek",
      priority: "high"
    )

    log = AgentOrchestratorService.process_ticket_with_agent!(ticket)
    ticket.reload

    assert_equal "resolved", log.action_taken
    assert_equal "solved", ticket.status
    assert_not ticket.needs_human_review?
    assert ticket.ticket_comments.any?
    assert_includes ticket.ticket_comments.last.body, "Aura"
  end

  test "yüksek tutarlı kurumsal zarar ve dava riskinde Human-in-the-Loop onayı devreye girer" do
    ticket = Ticket.create!(
      subject: "25.000 TL Kurumsal siparişte hasar ve tazminat protokolü",
      description: "Şirketimiz için alınan hediyelerin tamamı hasarlı geldi. 25.000 TL iade ve tazminat istiyoruz.",
      customer_name: "Holding Temsilcisi",
      customer_email: "kurumsal@holding.com",
      category: "Fatura & Ödeme",
      priority: "urgent"
    )

    log = AgentOrchestratorService.process_ticket_with_agent!(ticket)
    ticket.reload

    assert_equal "escalated_human", log.action_taken
    assert ticket.needs_human_review?
    assert_nil log.human_approved
    assert log.reasoning.include?("Finansal Yetki")
  end

  test "bayram simülasyonu 10 gerçekçi bilet oluşturup ajanlara başarıyla dağıtır" do
    tickets = AgentOrchestratorService.simulate_bayram_surge!(nil, 5)

    assert_equal 5, tickets.size
    tickets.each do |t|
      assert_not_nil t.assigned_ai_agent_id
      assert t.agent_execution_logs.any?
    end
  end
end

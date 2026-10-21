require "test_helper"

class AiAgentTest < ActiveSupport::TestCase
  test "5 varsayılan bayram ajanı başarıyla tohumlanır" do
    AiAgent.seed_default_agents!

    assert_equal 5, AiAgent.count
    assert AiAgent.exists?(code_name: "aura_returns")
    assert AiAgent.exists?(code_name: "atlas_invoice")
    assert AiAgent.exists?(code_name: "volt_sla_guardian")
    assert AiAgent.exists?(code_name: "nova_tech")
    assert AiAgent.exists?(code_name: "seren_sentiment")
  end

  test "ajan yetenek etiketlerini dizi olarak döndürür" do
    agent = AiAgent.new(skills_tags: "Kargo, İade, 7/24 SLA")
    assert_equal ["Kargo", "İade", "7/24 SLA"], agent.skills_list
  end

  test "kiralama durumu ve aktiflik sorgusu doğru çalışır" do
    AiAgent.seed_default_agents!
    agent = AiAgent.find_by(code_name: "aura_returns")

    assert_not agent.currently_rented?

    AgentRental.create!(
      ai_agent: agent,
      package_name: "Test Kiralama",
      rental_duration_days: 7,
      rented_at: Time.current,
      expires_at: 7.days.from_now,
      status: "active"
    )

    assert agent.currently_rented?
    assert_not_nil agent.current_rental
  end
end

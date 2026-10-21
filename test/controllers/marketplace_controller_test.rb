require "test_helper"

class MarketplaceControllerTest < ActionDispatch::IntegrationTest
  setup do
    AiAgent.seed_default_agents!
    @agent = AiAgent.first
  end

  test "marketplace ana sayfası başarıyla açılır ve 5 ajanı listeler" do
    get marketplace_url
    assert_response :success
    assert_select "h1", /Bayramda 5 Uzman Destek Ajanı Kirala/
    assert_select "h3", @agent.name
  end

  test "bayram paketini 1 tıkla kiralama aksiyonu çalışır" do
    post hire_bayram_pack_marketplace_url, params: { duration_days: 7 }
    assert_redirected_to marketplace_url
    assert_equal 5, AgentRental.active_now.count
  end

  test "tekil ajan kiralama ve iptal etme aksiyonları çalışır" do
    post rent_agent_marketplace_url(@agent), params: { duration_days: 7 }
    assert_redirected_to marketplace_url
    assert @agent.currently_rented?

    rental = @agent.current_rental
    delete cancel_rental_marketplace_url(rental)
    assert_redirected_to marketplace_url
    assert_not @agent.currently_rented?
  end

  test "bayram bilet fırtınası simülasyonu çalışır" do
    post simulate_surge_marketplace_url, params: { count: 3 }
    assert_redirected_to marketplace_url
    assert Ticket.count >= 3
  end

  test "HITL onay kuyruğu sayfası başarıyla açılır" do
    get review_queue_marketplace_url
    assert_response :success
    assert_select "h1", "Human-in-the-Loop Onay Kuyruğu"
  end
end

require "test_helper"

class AgentRentalTest < ActiveSupport::TestCase
  setup do
    AiAgent.seed_default_agents!
    @agent = AiAgent.first
  end

  test "kiralama süresi, kalan gün ve saat hesabı doğrudur" do
    rental = AgentRental.create!(
      ai_agent: @agent,
      package_name: "Bayram Paketi",
      rental_duration_days: 7,
      rented_at: Time.current,
      expires_at: 7.days.from_now,
      status: "active"
    )

    assert rental.active?
    assert_equal 7, rental.remaining_days
    assert rental.remaining_hours > 160.0
  end

  test "metrik güncelleme ve insan maliyet tasarrufu doğru hesaplanır" do
    rental = AgentRental.create!(
      ai_agent: @agent,
      package_name: "Bayram Paketi",
      rental_duration_days: 7,
      rented_at: Time.current,
      expires_at: 7.days.from_now,
      status: "active",
      tickets_processed_count: 0,
      tickets_solved_count: 0,
      sla_violations_prevented: 0
    )

    rental.increment_metrics!(solved: true, sla_saved: true)
    rental.reload

    assert_equal 1, rental.tickets_processed_count
    assert_equal 1, rental.tickets_solved_count
    assert_equal 1, rental.sla_violations_prevented
    assert rental.human_cost_saved > 0.0
  end
end

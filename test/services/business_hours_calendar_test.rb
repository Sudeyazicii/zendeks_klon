require "test_helper"

class BusinessHoursCalendarTest < ActiveSupport::TestCase
  test "hafta sonu ve resmi tatilleri doğru tespit eder" do
    pazartesi = Date.new(2026, 10, 12) # Pazartesi
    pazar = Date.new(2026, 10, 18)     # Pazar
    cumhuriyet_bayrami = Date.new(2026, 10, 29) # Resmi Tatil (Perşembe)

    assert BusinessHoursCalendar.workday?(pazartesi)
    assert_not BusinessHoursCalendar.workday?(pazar)
    assert_not BusinessHoursCalendar.workday?(cumhuriyet_bayrami)
  end

  test "mesai saatleri dışındaysa en yakın mesai başlangıcını verir" do
    # Cuma akşamı 20:00 -> Pazartesi sabahı 09:00
    cuma_aksam = Time.zone.local(2026, 10, 16, 20, 0, 0)
    beklenen_pazartesi = Time.zone.local(2026, 10, 19, 9, 0, 0)

    assert_equal beklenen_pazartesi, BusinessHoursCalendar.next_business_start(cuma_aksam)
  end

  test "Cuma 17:00'de açılan 4 saatlik biletin hedefi Pazartesi 12:00 olur (Mesai SLA Takvimi)" do
    # Cuma 17:00 -> Cuma günü 1 saat mesai kalır (17:00 - 18:00)
    # Kalan 3 saat Pazartesi 09:00'dan itibaren işletilir -> Pazartesi 12:00
    cuma_1700 = Time.zone.local(2026, 10, 16, 17, 0, 0)
    beklenen_bitis = Time.zone.local(2026, 10, 19, 12, 0, 0)

    hedef = BusinessHoursCalendar.calculate_deadline(cuma_1700, 4.hours)
    assert_equal beklenen_bitis, hedef
  end

  test "Resmi tatil gününü atlayarak mesai hedefi hesaplar" do
    # 28 Ekim Çarşamba 17:00 (1 saat kullanılır)
    # 29 Ekim Perşembe Resmi Tatil (Cumhuriyet Bayramı) -> Tamamen atlanır!
    # Kalan 3 saat 30 Ekim Cuma 09:00 - 12:00 arası işletilir.
    carsamba_1700 = Time.zone.local(2026, 10, 28, 17, 0, 0)
    beklenen_cuma = Time.zone.local(2026, 10, 30, 12, 0, 0)

    hedef = BusinessHoursCalendar.calculate_deadline(carsamba_1700, 4.hours)
    assert_equal beklenen_cuma, hedef
  end
end

class BusinessHoursCalendar
  START_HOUR = 9
  END_HOUR = 18
  WORK_HOURS_PER_DAY = END_HOUR - START_HOUR # 9 saat

  OFFICIAL_HOLIDAYS = [
    [1, 1],   # Yılbaşı
    [4, 23],  # Ulusal Egemenlik ve Çocuk Bayramı
    [5, 1],   # Emek ve Dayanışma Günü
    [5, 19],  # Atatürk'ü Anma, Gençlik ve Spor Bayramı
    [7, 15],  # Demokrasi ve Milli Birlik Günü
    [8, 30],  # Zafer Bayramı
    [10, 29]  # Cumhuriyet Bayramı
  ].freeze

  def self.holiday?(date)
    OFFICIAL_HOLIDAYS.any? { |month, day| date.month == month && date.day == day }
  end

  def self.workday?(date)
    date = date.to_date
    (1..5).cover?(date.wday) && !holiday?(date)
  end

  def self.business_time?(time)
    return false unless workday?(time)
    time.hour >= START_HOUR && time.hour < END_HOUR
  end

  # Mesai saatleri dışındaysa en yakın mesai başlangıcını döndürür
  def self.next_business_start(time)
    current = time
    loop do
      if workday?(current)
        if current.hour < START_HOUR
          return current.change(hour: START_HOUR, min: 0, sec: 0)
        elsif current.hour >= END_HOUR
          # Gün sonu mesaisi bitmiş, sonraki güne geç
          current = (current + 1.day).change(hour: START_HOUR, min: 0, sec: 0)
        else
          return current # Zaten mesai saatleri içinde
        end
      else
        # Hafta sonu veya resmi tatil, sonraki güne geç
        current = (current + 1.day).change(hour: START_HOUR, min: 0, sec: 0)
      end
    end
  end

  # Belirli bir başlangıç anından itibaren mesai saatleri üzerinden hedef süre hesaplar
  def self.calculate_deadline(start_time, duration)
    remaining_seconds = duration.to_i
    current = next_business_start(start_time)

    while remaining_seconds > 0
      current = next_business_start(current) unless business_time?(current)

      # Günün mesai bitimine kadar kalan saniye
      end_of_day = current.change(hour: END_HOUR, min: 0, sec: 0)
      available_seconds = (end_of_day - current).to_i

      if remaining_seconds <= available_seconds
        return current + remaining_seconds.seconds
      else
        remaining_seconds -= available_seconds
        # Ertesi gün 09:00'a atla
        current = (current + 1.day).change(hour: START_HOUR, min: 0, sec: 0)
        current = next_business_start(current)
      end
    end

    current
  end
end

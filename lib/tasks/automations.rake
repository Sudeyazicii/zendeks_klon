namespace :automations do
  desc "Tüm zamanlanmış otomasyon kurallarını ve 24h forum dönüşümünü çalıştırır"
  task run_all: :environment do
    puts "⚡ [PulseDesk] Zamanlanmış otomasyonlar başlatılıyor..."

    # 1. 24 Saatlik cevapsız forum sorularını dönüştür
    converted = CommunityQuestion.auto_convert_unanswered!(executed_by: "Cron / Zamanlanmış Görev (Rake)")
    puts "✓ 24 Saat Topluluk Dönüşümü: #{converted.size} soru bilete dönüştürüldü."

    # 2. SLA ihlallerini kontrol et
    Ticket.unresolved.find_each(&:check_sla_breach!)
    puts "✓ SLA Kontrolü: Açık talepler taranarak ihlal durumları güncellendi."

    # 3. Aktif zaman tabanlı kuralları çalıştır
    AutomationRule.active.where(trigger_type: "time_based").find_each do |rule|
      res = rule.execute!(executed_by: "Zamanlanmış Kural Motoru (Rake)")
      puts "✓ Kural '#{rule.name}': #{res[:modified_count]} güncellendi, #{res[:skipped_count]} atlandı."
    end

    puts "🎉 [PulseDesk] Tüm otomasyonlar başarıyla tamamlandı."
  end

  desc "Yalnızca 24 saat cevapsız kalan forum sorularını dönüştürür"
  task auto_convert_questions: :environment do
    converted = CommunityQuestion.auto_convert_unanswered!(executed_by: "Rake CLI")
    puts "#{converted.size} adet soru destek talebine dönüştürüldü."
  end

  desc "SLA sürelerini kontrol eder ve yaklaşan/aşanları işaretler"
  task check_sla: :environment do
    Ticket.unresolved.find_each(&:check_sla_breach!)
    puts "SLA kontrolleri tamamlandı."
  end
end

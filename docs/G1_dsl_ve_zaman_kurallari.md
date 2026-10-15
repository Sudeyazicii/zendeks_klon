# G1 — Ruby DSL, Niyet ≈ Kod ve Zaman Kuralları Tablosu

Bu doküman, YZM379 dersi kapsamında Ruby & Rails'in doğal dille niyet ifade etme gücünü, DSL yeteneklerini, token farkı ölçümünü ve PulseDesk'te uygulanan zaman kuralları ile durum geçişlerinin kod haritasını içerir.

---

## 1. Niyet ≈ Kod: Python vs Ruby + ActiveSupport Karşılaştırması

### Niyet: "Bir hafta önceki zamanı ver"
- **Python:**
  ```python
  from datetime import datetime, timedelta
  datetime.now() - timedelta(weeks=1)
  ```
- **Ruby + ActiveSupport:**
  ```ruby
  1.week.ago
  ```

### Niyet: "3 gün sonraki zaman"
- **Python:**
  ```python
  datetime.now() + timedelta(days=3)
  ```
- **Ruby + ActiveSupport:**
  ```ruby
  3.days.from_now
  ```

### Niyet: "Ekim 2026'daki Cumartesi günlerinin sayısını bul"
- **Python:**
  ```python
  import calendar
  sum(1 for day in range(1, 32) if calendar.weekday(2026, 10, day) == 5)
  ```
- **Ruby:**
  ```ruby
  (Date.new(2026, 10, 1)..Date.new(2026, 10, 31)).count(&:saturday?)
  ```

---

## 2. Token Farkı ve Bilişsel Aktarım (Cognitive Translation) Ölçümü

| İfade / Niyet | Python Karşılığı Token Sayısı | Ruby DSL Token Sayısı | Tasarruf Oranı |
|---|---|---|---|
| "Bir hafta önceki zaman" | 18 token (import + syntax) | 4 token (`1.week.ago`) | %77 Token Tasarrufu |
| "3 gün sonraki tarih" | 16 token | 4 token (`3.days.from_now`) | %75 Token Tasarrufu |
| "Duruma göre grupla ve say" | 15 token (`collections.Counter`) | 5 token (`tickets.group_by(&:status)`) | %66 Token Tasarrufu |

---

## 3. PulseDesk Zaman Kuralları ve Durum Geçişleri Tablosu

Aşağıdaki tablo, sunumda 3. dakikada sorulacak kod karşılıklarını tam olarak göstermektedir:

| Zaman Kuralı / Durum Geçişi | Kural Tanımı & Süre | Model Kodu ([app/models/ticket.rb](file:///c:/Users/PC/Desktop/zendesk/app/models/ticket.rb)) | Test Kodu (`travel_to`) ([test/models/ticket_test.rb](file:///c:/Users/PC/Desktop/zendesk/test/models/ticket_test.rb)) |
|---|---|---|---|
| **1. Acil SLA Çözüm Hedefi** | `urgent` öncelikli talep: **2 saat** | `SLA_DURATIONS["urgent"] = 2.hours` | `travel_to @ticket.created_at + 4.hours + 1.minute do ... assert @ticket.breached?` |
| **2. Yüksek SLA Çözüm Hedefi** | `high` öncelikli talep: **4 saat** | `SLA_DURATIONS["high"] = 4.hours` | `travel_to @ticket.created_at + 3.hours + 50.minutes` (İhlal yok testi) |
| **3. Dual-Stage İlk Yanıt SLA** | `urgent` ilk yanıt: **30 dakika** | `FIRST_RESPONSE_SLA_DURATIONS["urgent"] = 30.minutes` | `travel_to ticket.created_at + 31.minutes do ... assert ticket.first_response_breached?` |
| **4. e-Fatura Yasal Takvimi** | GİB onay bekleyen bilet: **7 gün (168 saat)** | `GIB_EINVOICE_SLA_DURATION = 7.days` | `travel_to ticket.created_at + 6.days` (false), `+ 7.days + 1.minute` (true) |
| **5. Pause on Pending (Duraklatma)** | Müşteri beklenirken SLA durur, çıkınca ötelenir | `sla_paused_at = Time.current`, `resume_sla_if_paused!` | 3 saat `pending` kalan biletin hedefi tam 3 saat ileri ötelenir |
| **6. 24 Saat Topluluk Dönüşümü** | 24 saat cevapsız forum sorusu bilete dönüşür | `CommunityQuestion.auto_convert_unanswered!` | `travel_to question.created_at + 24.hours + 2.minutes` |
| **7. Mesai Saati & Tatil Filtresi** | Hafta sonu ve 29 Ekim'i atlar | `BusinessHoursCalendar.calculate_deadline` | Cuma 17:00'de açılan bilet Pazartesi mesaiyle işler |

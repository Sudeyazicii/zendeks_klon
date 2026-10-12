# AGENT.md — PulseDesk Geliştirici & Ajan Kılavuzu

Bu belge, **PulseDesk** SaaS uygulamasının mimarisi, tasarım ilkeleri, geliştirme kuralları, test çalıştırma yönergeleri ve yapay zeka ajanlarıyla çalışma standartlarını içerir.

---

## 1. Proje Mimarisi & Teknoloji Yığını

- **Uygulama Adı:** PulseDesk
- **İlham Kaynağı:** Zendesk temel müşteri destek iş akışı (Zendesk marka ismi ve logosu kesinlikle kullanılmaz).
- **Teknoloji:** Ruby on Rails 8.1+ / Ruby 3.2+
- **Veritabanı:** 
  - Geliştirme & Test: SQLite 3 (WAL mode)
  - Canlı Ortam (Render): PostgreSQL (`pg` gem)
- **Frontend Yaklaşımı:** Rails Server-Rendered ERB + Vanilla CSS + Hotwire / Turbo (Ayrı JS framework'ü yok).
- **Arka Plan İşleri:** Solid Queue / ActiveJob.
- **CI / CD:** GitHub Actions (`.github/workflows/ci.yml`), Render (`render.yaml`).

### Temel Veri Modelleri & İlişkiler
1. **`Ticket`**: Destek talebi. Benzersiz `ticket_number` (`#PD-XXXX`), durum makinesi (`new` → `open` → `pending` → `solved`), SLA zamanı (`sla_due_at`), ihlal bayrağı (`sla_breached`).
2. **`TicketComment`**: Talebe ait yazışma geçmişi (`author_role`: agent/customer). Destek görevlisi yanıt yazdığında talep `new` ise otomatik olarak `open` durumuna geçer.
3. **`CommunityQuestion`**: Topluluk forumu sorusu. 24 saat boyunca yanıt almazsa (`answers_count == 0`), otomatik olarak yüksek öncelikli bir `Ticket`'a dönüştürülür.
4. **`CommunityAnswer`**: Topluluk sorusuna verilen cevap (`counter_cache: :answers_count`).

---

## 2. Kodlama & Tasarım İlkeleri

1. **Durum Makinesi Bütünlüğü (State Machine):**
   - İzin verilen geçişler:
     - `new` → `open`, `pending`
     - `open` → `pending`, `solved`
     - `pending` → `open`, `solved`
     - `solved` → `open` (yalnızca yeniden açılabilir)
   - Yasak geçişler: `new` → `solved` doğrudan kapatılamaz, `solved` → `new` yapılamaz. Geçersiz geçişler `ActiveRecord::RecordInvalid` fırlatır.
2. **SLA Süreleri & İhlal Yönetimi:**
   - Öncelik süreleri: Acil (2 saat), Yüksek (4 saat), Orta (8 saat), Düşük (24 saat).
   - Zaman tabanlı kontrollerde Rails'in `ActiveSupport::Testing::TimeHelpers` (`travel_to`) araçları kullanılır.
3. **100+ Puan Diferansiyatörü (Topluluk Otomasyonu):**
   - G2 kullanıcı incelemesindeki eksikliği çözer: Unutulan forum soruları 24 saat sonra biletleşir.
   - Idempotent mimari: Aynı soru asla 2 kez dönüştürülmez.
   - İlişki korunumu: `question.ticket` ve `ticket.community_question` iki yönlü bağlıdır.
4. **Tasarım:** Türkçe arayüz, temiz B2B SaaS estetiği, özgün PulseDesk logosu, responsive layout.

---

## 3. Test & Doğrulama Komutları

Testleri çalıştırmadan önce test veritabanını hazırlayın:
```bash
bin/rails db:test:prepare
```

Tüm test paketini çalıştırma:
```bash
bin/rails test
```

Yalnızca model ve SLA/zaman kurallarını test etme:
```bash
bin/rails test test/models/
```

Yalnızca kontrolcü ve entegrasyon testlerini çalıştırma:
```bash
bin/rails test test/controllers/
```

Doğrulanan 3 Temel Zaman Kuralı:
1. `SLA süresi dolmadan ihlal oluşmaz` (`travel_to created_at + 3.hours + 50.minutes`)
2. `SLA süresi dolunca ihlal oluşur` (`travel_to created_at + 4.hours + 1.minute`)
3. `24 saat dolmadan dönüştürülmez, 24 saat dolunca otomatik dönüştürülür` (`travel_to created_at + 24.hours + 2.minutes`)

---

## 4. Güvenlik Kuralları

- Strong Parameters kullanımı zorunludur (`ticket_params`, `comment_params`).
- Kullanıcı girdileri ERB içinde otomatik escape edilir (XSS koruması).
- CSRF koruması aktiftir (`protect_from_forgery`).
- `config/master.key` gizli tutulmalı, repoya commit edilmemelidir.

---

## 5. Ajanla Çalışma Standartları

- Var olan dosyaları gereksiz yere silmeyin veya ezmeyin.
- Bir özelliğin bittiğini söylemeden önce mutlaka gerçek testlerle (`bin/rails test`) doğrulayın.
- Gerçekçi olmayan veya sahte arayüz butonları üretmeyin; tüm aksiyonlar veritabanına kaydedilmelidir.
- Şeffaf olun: Yapılamayan veya canlı ortam kısıtları olan özellikleri gizlemeyin, `Yapamadıklarım` bölümünde listeleyin.

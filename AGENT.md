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
1. **`Ticket`**: Destek talebi. Benzersiz `ticket_number` (`#PD-XXXX`), durum makinesi (`new` → `open` → `pending` → `solved` → `closed`), iki aşamalı SLA (`first_response_due_at`, `sla_due_at`), duraklatma (`sla_paused_at`, `total_paused_seconds`) ve e-Fatura adaptasyonu (`e_invoice_status`: `gib_pending`, `tax_number`, `invoice_number`).
2. **`TicketComment`**: Talebe ait yazışma geçmişi (`author_role`: agent/customer). Temsilci ilk yanıt verdiğinde talep `new` ise otomatik olarak `open` durumuna geçer ve `first_responded_at` atanır.
3. **`CommunityQuestion`**: Topluluk forumu sorusu. 24 saat boyunca yanıt almazsa (`answers_count == 0`), otomatik olarak yüksek öncelikli bir `Ticket`'a dönüştürülür (`solved` alanı ve kabul edilen çözüm ilişkisi).
4. **`CommunityAnswer`**: Topluluk cevabı (`is_solution`, `upvotes_count`, `counter_cache: :answers_count`).
5. **`Article`**: Bilgi Bankası self-servis makalesi (`Article.search_relevant` bilet başlığına göre otomatik öneri).
6. **`AutomationRule` & `AutomationAuditLog`**: Kural motoru (`preview` dry-run simülasyonu, idempotency kontrolü, kural çakışma tespiti `detect_conflicts`).

---

## 2. Kodlama & Tasarım İlkeleri

1. **Durum Makinesi Bütünlüğü (State Machine):**
   - İzin verilen geçişler: `new` → `open`, `pending`; `open` → `pending`, `solved`, `closed`; `pending` → `open`, `solved`, `closed`; `solved`/`closed` → `open`.
   - Yasak geçişler: `new` → `solved` doğrudan kapatılamaz, `solved` → `new` yapılamaz. Geçersiz geçişler `ActiveRecord::RecordInvalid` fırlatır.
2. **SLA Süreleri & e-Fatura Yasal Takvimi (100+ Rubrik Uyarlaması):**
   - Standart öncelik süreleri: Acil (2 saat), Yüksek (4 saat), Orta (8 saat), Düşük (24 saat).
   - e-Fatura GİB onay/itiraz süreci: 7 gün (168 saat) yasal SLA motoru.
   - İki aşamalı (dual-stage) ilk yanıt SLA'sı: Acil (30 dk), Yüksek (1 sa), Normal (2 sa).
   - Müşteri beklenirken SLA duraklatma (`Pause on Pending`): Geçen süre kadar SLA bitiş tarihi otomatik ötelenir.
3. **100+ Puan Diferansiyatörleri:**
   - 24 saat cevapsız forum sorularını otomatik dönüştürme (G2 şikayeti çözümü).
   - Güvenli dry-run önizlemesi (Zendesk kural karmaşası çözümü).
   - Mükerrer bilet tespiti ve tek tıkla birleştirme (merge).
   - Topluluk doğru çözüm rozeti ve faydalı oy mekanizması.
   - Bilgi Bankası CMS yönetimi.
4. **Tasarım:** Türkçe B2B SaaS estetiği, özgün PulseDesk logosu, responsive layout.

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

Doğrulanan 6 Temel Zaman Kuralı (`travel_to`):
1. `SLA süresi dolmadan ihlal oluşmaz` (`travel_to created_at + 3.hours + 50.minutes`)
2. `SLA süresi dolunca ihlal oluşur` (`travel_to created_at + 4.hours + 1.minute`)
3. `24 saat dolmadan dönüştürülmez, 24 saat dolunca otomatik dönüştürülür` (`travel_to created_at + 24.hours + 2.minutes`)
4. `e-Fatura GİB onay bekleyen bilet için 7 günlük yasal SLA takvimi işletilir` (`travel_to created_at + 6.days` false, `+ 7.days + 1.minute` true)
5. `Beklemede (pending) durumunda SLA duraklatılır ve çıkılınca ötelenir` (`total_paused_seconds` doğrulaması)
6. `Dual-stage SLA: ilk yanıt süresi (30 dk) aşıldığında first_response_breached işaretlenir`

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

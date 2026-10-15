# G4 — Aort Dilimi & Durum Makinesi Mimarisi

Bu doküman, Zendesk'in para ödenen ana iş akışının (**Aort Dilimi**) PulseDesk üzerindeki durum makinesi kurallarını, yasak geçişlerini ve koruma mekanizmalarını içerir.

---

## 1. Aort Dilimi İş Akışı Şeması

```text
[Müşteri Talebi (Web / WhatsApp / API)]
             ↓
[Durum: YENİ (new)] ──(Temsilci İlk Yanıtı / Atama)──→ [Durum: AÇIK (open)]
             ↓                                                   ↓
    (SLA Sayacı Aktif)                                (Müşteri Detayı Bekleniyor)
             ↓                                                   ↓
[SLA İhlal Takibi (Dual-Stage)]                       [Durum: BEKLEMEDE (pending)]
             ↓                                        (SLA Sayacı Dondurulur!)
             ↓                                                   ↓
[Çözüm Yanıtı + PulseAI] ──(Kapanış Onayı)─────────→ [Durum: ÇÖZÜLDÜ (solved)]
                                                                 ↓
                                                      [Durum: KAPATILDI (closed)]
```

---

## 2. İzin Verilen ve Yasak Durum Geçişleri

Model seviyesinde tanımlanan geçiş kuralları ([app/models/ticket.rb](file:///c:/Users/PC/Desktop/zendesk/app/models/ticket.rb)):

```ruby
ALLOWED_TRANSITIONS = {
  "new"     => %w[open pending],
  "open"    => %w[pending solved closed],
  "pending" => %w[open solved closed],
  "solved"  => %w[open closed],
  "closed"  => %w[open]
}.freeze
```

### Koruma & Yasak Geçiş Testleri:
1. **`new` → `solved` Geçilemez:** Henüz açılmamış ve işlem görmemiş talep doğrudan çözüldü yapılamaz.
2. **`solved` → `new` Geçilemez:** Çözülen bilet tekrar yeni durumuna alınamaz, ancak `open` olarak yeniden açılabilir (`reopen!`).
3. **`solved` → `pending` Geçilemez:** Çözülmüş bilet doğrudan beklemede durumuna alınamaz.
4. **Geçersiz geçişlerde fırlatılan hata:** `ActiveRecord::RecordInvalid` (Test doğrulaması: [test/models/ticket_test.rb](file:///c:/Users/PC/Desktop/zendesk/test/models/ticket_test.rb)).

---

## 3. Pause on Pending (Beklemede Duraklatma) Mekanizması

Müşteriden ek log, ekran görüntüsü veya yanıt beklenirken destek personelinin SLA ihlaliyle cezalandırılmasını önler:
- Talep `pending` durumuna geçtiğinde: `sla_paused_at = Time.current`.
- Talep tekrar `open` olduğunda: `resume_sla_if_paused!` metodu çalışır, aradaki fark `total_paused_seconds` alanına eklenir ve `sla_due_at` hedef tarihi geçen süre kadar ileri ötelenir.

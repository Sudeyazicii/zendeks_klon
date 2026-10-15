# G5 — Kullanıcı Acısı, Ajan Deneyimi & Şeffaf Kısıtlar

Bu doküman, 100+ puan hedefi doğrultusunda çözülen kullanıcı acılarını, yakalanan ajan uydurmalarını ve sistem kısıtlarını içerir.

---

## 1. 100+ Puan Kullanılabilir Pas (Kullanıcı Acısı Çözümü)

### Tek Cümlelik Pas (Sunum İçin):
> **"PulseDesk; B2B SaaS ve e-ticaret şirketlerinin e-Fatura yasal takvimine bağlı SLA hedeflerini yönetmesini, kurumsal mesai saatleri ve resmi tatilleri hesaba katan SLA motorunu işletmesini, cevapsız kalan topluluk sorularını 24 saat içinde otomatik olarak öncelikli destek biletine dönüştürmesini ve Zendesk'in karmaşık kuralları yerine güvenli dry-run önizlemesi sunmasını sağlayan eksiksiz bir platformdur."**

### Çözülen 3 Temel Kullanıcı Acısı:
1. **24 Saat Yanıtsız Kalan Topluluk Soruları (Capterra İncelemesi):**
   - *Acı:* Müşteriler forumda teknik soru soruyor, günlerce kimse görmüyor.
   - *Çözüm:* `CommunityQuestion.auto_convert_unanswered!` metodu ile 24 saat içinde kabul edilen bir cevabı olmayan sorular otomatik yüksek öncelikli destek biletine dönüştürülür.
2. **Kural Çakışması ve Yanlış Tetiklenme Korkusu (G2 İncelemesi):**
   - *Acı:* Yeni otomasyon kuralı yazarken var olan kurallarla çakışıp müşterilere yanlış bildirim gitmesi.
   - *Çözüm:* Güvenli Dry-Run Önizlemesi (`AutomationRule#preview`) ve Kural Çakışma Analizi (`detect_conflicts`).
3. **e-Fatura 7 Günlük Yasal İtiraz Takvimi:**
   - *Acı:* Standart SLA sayaçlarının saatlik olması, GİB 7 günlük yasal itiraz takvimini tanıyamaması.
   - *Çözüm:* VKN/TCKN, Fatura No ve GİB Durumu (`gib_pending`) alanları eklendi. Otomatik 168 saatlik yasal SLA motoru çalışır.

---

## 2. Yakalanan Ajan Uydurmaları (Hallucination) ve Düzeltmeler

1. **Uydurma API (`3.business_days.from_now`):**
   - *Ajan Önerisi:* Ajan iş kurallarında doğrudan `3.business_days.from_now` metodunu çağırabileceğini iddia etti.
   - *Gerçek:* Bu metot Rails çekirdeğinde varsayılan olarak yoktur; harici bir gem gerektirir.
   - *Düzeltme:* `app/services/business_hours_calendar.rb` sınıfı yazılarak resmi tatil ve mesai saatlerini hesaba katan özgün takvim motoru kuruldu.
2. **Geçersiz Durum Geçişinde Sessiz Başarı:**
   - *Ajan Önerisi:* `transition_to!` metodunun her durumda çalıştığını varsaydı.
   - *Düzeltme:* `validate_status_transition` validasyonu ve `ALLOWED_TRANSITIONS` sözlüğü eklenerek geçersiz durumlarda `ActiveRecord::RecordInvalid` fırlatılması zorunlu kılındı.

---

## 3. Yapamadıklarım & Şeffaf Kısıtlar

1. **Render Free Tier Arka Plan Zamanlayıcısı:**
   - Render ücretsiz sunucusu 15 dakika istek almadığında uyku moduna geçer. Bu sebeple hem Solid Queue ActiveJob sınıfı, hem sayfa açılışında dinamik kontrol, hem de jüri gösterimi için tek tıkla manuel dönüştürme butonu (`POST /community_questions/trigger_auto_convert`) sağlandı.
2. **Çoklu Dil (i18n):**
   - Sınıfta canlı Türkçe sunum yapılacağı için sistem doğrudan Türkçe olarak geliştirildi; dinamik dil değiştirme modülü eklenmedi.

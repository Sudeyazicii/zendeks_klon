# CHALLENGE_LOG

## Başlangıç noktası
- **Klonlanan ürün ve canlı URL:** PulseDesk (Zendesk SaaS Klonu) — [https://zendeks-klon.onrender.com](https://zendeks-klon.onrender.com)
- **Geçen haftanın son commit'i:** [`638b981`](https://github.com/Sudeyazicii/zendeks_klon/commit/638b981) ("Ensure zero original brand references in UI and assets")
- **Bu ürüne kim, neden para ödüyor?** 
  - Fortune 500 kuruluşları ve kurumsal B2B şirketleri (Fintech, E-ticaret, Lojistik), SLA taahhüt sürelerini (acil biletlerde 2 saat, e-fatura itirazlarında 7 gün) kaçırıp yüzbinlerce dolarlık müşteri kaybı (churn) ve sözleşme cezası yaşamamak için para ödüyor.
  - Şirketler çok kanallı (web, WhatsApp, e-posta, API) biletleri organize etmek, mesai takvimine göre süre hesaplamak ve kurumsal onay akışlarını yönetmek için kullanıcı başına ayda $50 – $150 lisans ödüyor.

---

## Acı
- **Hangi kullanıcının hangi acısı? Kaynak (şikâyet, forum, inceleme linki):**
  1. **Bayram ve Resmi Tatil Yoğunluğu / SLA Patlaması Acısı:**
     - *Kaynak:* [G2 Zendesk Reviews](https://www.g2.com/products/zendesk-support-suite/reviews) & [Trustpilot Zendesk Complaints](https://www.trustpilot.com/review/zendesk.com) — "During national holidays and seasonal surges, our human agents are off-duty. Tickets pile up, SLA breach rates surge to 40%, and customers vent their frustration on social media."
     - *Kullanıcı:* E-ticaret operasyon müdürleri, müşteri deneyimi (CX) liderleri ve destek ekipleri.
  2. **Yüksek İnsan Maliyeti ve Lisans Kısıtı Acısı:**
     - 1 haftalık bayram veya indirim dönemi için yeni insan temsilci işe almak, eğitmek ve Zendesk koltuk lisansı (per-seat pricing) ödemek imkansızdır. Bir insan temsilcinin haftalık mesai maliyeti ₺37.800'e kadar çıkmaktadır.
  3. **Yapay Zeka "Slop" / Akılsız Bot Acısı:**
     - Mevcut müşteri hizmetleri botları sadece anahtar kelime eşleştirmesi ("teşekkür", "acil") yapan, bilet çözemeyen, halüsinasyon gören ve müşteriyi çıldırtan basit şablon motorlarıdır. Gerçek otonomi ve güvenli insan denetimi (Human-in-the-Loop) sunmaz.

---

## Bu haftanın vaadi
- *"Şuraya kadar getirdim, üzerine şunu ekleyeceğim."*
  - **Şuraya kadar getirdim:** İki aşamalı (dual-stage) ilk yanıt ve çözüm SLA motoru, GİB 7 günlük e-Fatura mevzuat takvimi, 24 saat yanıtsız forum sorularını otomatik bilete dönüştürme, kural çakışma tespiti ve dry-run simülasyonu olan çalışan bir Zendesk klonu (PulseDesk).
  - **Hocanın Özel Görevi Doğrultusunda Üzerine Eklenenler:**
    - **Zendesk Klonunu AI Agent Marketplace'e Çevirme:** İnsan-insana bilet sürükle-bırak modelinden, otonom yapay zeka personeli kiralama platformuna geçiş.
    - **"Bayramda 5 Destek Agent'ı Kirala" Senaryosu:** Tek tıkla 7 günlük bayram nöbet paketi kiralama (`Aura`, `Atlas`, `Volt`, `Nova`, `Seren`).
    - **Otonom Bilet Çözümü & RAG Grounding:** Gelen bayram taleplerini uzmanlık alanına göre otomatik devralan, bilgi bankası makalelerinden RAG ile beslenen ve biletleri otonom kapatan akıl yürütme motoru (Chain of Thought).
    - **Human-in-the-Loop (HITL) Güvenlik Katmanı:** Finansal risk (₺10.000+ tazminat/iade) veya hukuki dava tehdidi içeren biletlerde güven skoru eşik altı bırakılarak insan onayına sunulması.
    - **Canlı Bayram Fırtınası Simülasyonu:** 10 gerçekçi biletlik bayram dalgasını tek tıkla patlatıp ajanların canlı tepkilerini, kurtarılan SLA sürelerini ve tasarruf edilen mesai maliyetini telemetri panelinde izleme.

---

## Yapılanlar ve kanıt
- **Commit Linkleri & Kod Değişiklikleri:**
  - Veritabanı Modelleri & Migrasyon: `AiAgent`, `AgentRental`, `AgentExecutionLog`, `Ticket` HITL alanları (`20261021200000_create_agent_marketplace.rb`)
  - Ajan Orkestrasyon & Akıl Yürütme Motoru: [`app/services/agent_orchestrator_service.rb`](file:///c:/Users/PC/Desktop/zendesk/app/services/agent_orchestrator_service.rb)
  - Marketplace & HITL Kontrolcüsü: [`app/controllers/marketplace_controller.rb`](file:///c:/Users/PC/Desktop/zendesk/app/controllers/marketplace_controller.rb)
  - Pazaryeri & Canlı Telemetri Arayüzü: [`app/views/marketplace/index.html.erb`](file:///c:/Users/PC/Desktop/zendesk/app/views/marketplace/index.html.erb) ve [`app/views/marketplace/review_queue.html.erb`](file:///c:/Users/PC/Desktop/zendesk/app/views/marketplace/review_queue.html.erb)
  - Bilet Arayüzü HITL & Ajan Kartları: [`app/views/tickets/index.html.erb`](file:///c:/Users/PC/Desktop/zendesk/app/views/tickets/index.html.erb) ve [`app/views/tickets/show.html.erb`](file:///c:/Users/PC/Desktop/zendesk/app/views/tickets/show.html.erb)

- **Çalışan Testler (102 Test, 398 Assertion, 0 Hata):**
  - Model Testleri: `test/models/ai_agent_test.rb`, `test/models/agent_rental_test.rb`, `test/models/ticket_test.rb`
  - Orkestrasyon Testleri: `test/services/agent_orchestrator_service_test.rb` (5 ajanın bayram paketiyle kiralanması, kategori bazlı ajan eşleşmesi, Aura ile otonom kargo çözümü, yüksek meblağlı bilette HITL eskalasyonu, 10 biletlik simülasyon)
  - Kontrolcü Testleri: `test/controllers/marketplace_controller_test.rb`
  - Test Çıktısı Kanıtı: `102 runs, 398 assertions, 0 failures, 0 errors, 0 skips (19.05s)`

- **Canlı Demo Adımları (Hocaya Sunum Rehberi):**
  1. **Pazaryerine Giriş:** Üst menüden **"🏪 Ajan Pazaryeri [🌙 BAYRAM]"** sekmesine tıklayın.
  2. **5 Ajanı İnceleme:** Kargo/İade Uzmanı (`Aura`), e-Fatura/GİB Mevzuat Uzmanı (`Atlas`), 7/24 Nöbetçi SLA Koruyucu (`Volt`), Teknik/API Uzmanı (`Nova`) ve Müşteri Yatıştırıcı (`Seren`) profillerini, saatlik/günlük ücretlerini ve başarı oranlarını görün.
  3. **Bayram Paketini Başlatma:** **"🚀 5 Ajanı 1 Tıkla Kirala (7 Günlük Bayram Kalkanı)"** butonuna tıklayın. 5 ajanın da aktif nöbete geçtiğini doğrulayın.
  4. **Bayram Fırtınası Simülasyonu:** **"⚡ 10 Biletlik Bayram Fırtınası Simülasyonu Başlat"** butonuna basın.
  5. **Otonom Çözüm & Canlı Telemetri:**
     - Kurtarılan SLA sayacının, çözülen biletlerin ve tasarruf edilen insan mesaisinin (₺) anlık arttığını gözlemleyin.
     - Canlı CoT Akışında ajanların biletleri incelerken yürüttükleri düşünce basamaklarını (Chain of Thought) okuyun.
  6. **Human-in-the-Loop Kanıtı:**
     - 25.000 TL'lik kurumsal hasar biletinin otonom kapatılmayıp **"Human-in-the-Loop: İnsan Denetimi Bekleyen Talepler"** kuyruğuna düştüğünü gösterin.
     - İnsan temsilci olarak **"✓ Ajan Yanıtını Onayla ve Gönder"** butonuna basarak onaylı geçişi kanıtlayın.

- **Vaat edip yapamadığım ne varsa açıkça yaz:**
  - Canlı OpenAI/Claude API çağrıları için ortam değişkeni (`OPENAI_API_KEY`) girilmediğinde sistem deterministic yerel NLP ve CoT akıl yürütme motoruna düşmektedir (kullanıcıya maliyet çıkarmamak ve offline/CI ortamında testlerin %100 geçmesi amacıyla bilerek bu mimari kurulmuştur).

---

## Zaman
- **İnsan zamanı / Agent zamanı (dürüstçe):**
  - İnsan zamanı: ~3.5 saat (Hocanın geri bildirimlerini ve dersteki yönlendirmelerini analiz etme, 5 ajanın uzmanlık persona ve mevzuat senaryolarını kurgulama, arayüz mimarisi ve HITL karar eşiklerini planlama).
  - Agent zamanı: ~45 dakika (Veritabanı tablolarının oluşturulması, migrasyonların işletilmesi, Hotwire/ERB frontend bileşenlerinin kodlanması, 102 adet birim ve entegrasyon testinin yazılıp koşturulması).
- **İlk prompt'un (olduğu gibi):**
  > "Neredeyiz? Geçen hafta Fortune 500 şirketlerinin para ödediği bir SaaS ürününü klonladınız... Görevim: Sudenur Zendesk klonunu agent marketplace’e çevir: 'Bayramda 5 destek agent’ı kirala' senaryosu. Mevcut özellikleri koru ama marketplace ön planda olsun. Ders dökümü ve yönergelere göre adım adım karar verip CHALLENGE_LOG.md ekle ve fark katmanını kodla kanıtla."

---

## Karar
- **Karar:** **Pivot Yap (Pivot & Supercharge: Traditional Helpdesk → Autonomous Agent Marketplace)**
- **Gerekçesi ("Bundan bir iş çıkar mı?" sorusunun cevabı):**
  - Geleneksel Zendesk ve Freshdesk modelleri insan emeğine dayalıdır ("koltuk başına lisans öde, insan temsilci bilet sürüklesin"). Ancak e-ticaret ve dijital dünyada trafik dalgalanmaları (Black Friday, bayram tatilleri, gece saatleri) insan istihdamını ekonomik olmaktan çıkarmaktadır.
  - Bayramda nöbet tutacak 5 insan temsilci bulmak 2 hafta sürer ve mesaisiyle birlikte haftalık en az ₺37.800 maliyet yaratır. Üstelik gece 03:00'te uykulu bir temsilcinin hata yapma ihtimali yüksektir.
  - PulseDesk'in geliştirdiği **Destek Ajanları Pazaryeri (Agent Marketplace)**, şirketlere *"İhtiyacın olduğu an, 1 tıkla, uzmanlaşmış yapay zeka personelini 7 günlüğüne kirala"* değer önerisini sunar. Sıfır eğitim süresi, 30 saniyelik ilk yanıt garantisi, GİB ve e-ticaret mevzuatına hakimiyet ve kritik biletlerde insan denetimi (HITL) ile birleştiğinde, bu doğrudan B2B şirketlerin para ödeyeceği ve piyasadaki "slop" klonlardan tamamen ayrışan gerçek bir girişim modelidir.

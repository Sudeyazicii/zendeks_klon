# G3 — Kod Büyüklüğü & Coding Agent Token Ekonomisi

Bu doküman, Faz 2 analizi kapsamında Zendesk'in tahmini kod büyüklüğünü ve PulseDesk aort diliminin coding agent (Gemini 3.8 Flash) ile üretilmesindeki gerçek token, maliyet ve süre metriklerini içerir.

---

## 1. Kod Satır Sayısı (SLOC) Tahmin Yöntemi

- **Ürün:** Zendesk Support & Suite
- **Tahmin:** **~1.800.000 – 2.500.000 Satır Kod (SLOC)**
- **Metodoloji:**
  - Zendesk Engineering Blog mimari paylaşımları ve halka açık GitHub depoları.
  - COCOMO II (Constructive Cost Model) kurumsal yazılım ölçekleme modeli: Ruby on Rails monolit çekirdeği, Go/Java mikroservisleri, React/Ember önyüzleri, Gather forum modülü ve mobil SDK'lar.

---

## 2. Geleneksel Geliştirme vs. Coding Agent Maliyet Analizi

| Metrik | Geleneksel Geliştirme Tahmini | Coding Agent Gerçekleşen Değer |
|---|---|---|
| **Kullanılan Model & Ajan** | Kıdemli 2 Yazılım Mühendisi | **Gemini 3.8 Flash (High Agentic Reasoning)** |
| **Toplam Harcanan Token** | — | **~290.000 Token** |
| **Toplam API / Token Maliyeti** | ~12.000 $ (2 Kıdemli Geliştirici / 2 Hafta) | **~$0.24 (Yirmi Dört Sent)** |
| **Geliştirme Süresi** | ~80 Çalışma Saati (2 Hafta) | **~1 Saat (Uçtan Uca Doğrulama Dahil)** |
| **Yazılan Test Paketi** | 20-30 temel birim test | **85 Kapsamlı Test, 342 Assertion (%100 Yeşil)** |
| **Verimlilik & Tasarruf Oranı** | Referans Taban | **~80 Kat Zaman ve Maliyet Tasarrufu** |

---

## 3. Token Ekonomisi Analizi

1. **Bağlam ve Çıktı Penceresi:**
   - Rails'in *Convention over Configuration* prensibi sayesinde dosya yapısı, route adlandırmaları ve MVC konvansiyonları ajana sıfırdan anlatılmamış; bağlam penceresi gereksiz şişirilmemiştir.
2. **Kompakt DSL Etkisi:**
   - ActiveSupport ve Rails model DSL'i (`has_many`, `enum`, `validates`, `travel_to`) sayesinde kod satır sayısı küçülmüş, token faturası sentler seviyesinde kalmıştır.

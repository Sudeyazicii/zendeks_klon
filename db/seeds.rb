# PulseDesk Demo Seeds
puts "Tohum verileri yükleniyor..."

Notification.destroy_all
AutomationAuditLog.destroy_all
AutomationRule.destroy_all
CannedResponse.destroy_all
Article.destroy_all
TicketComment.destroy_all
CommunityAnswer.destroy_all
Ticket.destroy_all
CommunityQuestion.destroy_all
User.destroy_all

# 0. Demo Kullanıcıları
agent_user = User.create!(
  name: "Mert Demir",
  email: "mert@pulsedesk.io",
  password: "password123",
  role: "agent",
  department: "Birinci Seviye Destek"
)

admin_user = User.create!(
  name: "Ali Yönetici",
  email: "admin@pulsedesk.io",
  password: "password123",
  role: "admin",
  department: "Mühendislik & Operasyon"
)

customer_user = User.create!(
  name: "Ahmet Yılmaz",
  email: "ahmet@example.com",
  password: "password123",
  role: "customer",
  department: "Müşteri"
)

# 1. Hazır Yanıtlar (Canned Responses / Macros)
CannedResponse.create!(
  title: "Standart Karşılama & İnceleme",
  category: "Genel",
  content: "Merhaba,\n\nTalebiniz destek ekibimiz tarafından incelemeye alınmıştır. İlgili kayıtları kontrol edip en kısa sürede geri dönüş sağlayacağız.\n\nİyi çalışmalar,\nPulseDesk Destek Ekibi"
)

CannedResponse.create!(
  title: "Ek Bilgi & Log Talebi",
  category: "Teknik",
  content: "Merhaba,\n\nSorunu daha detaylı inceleyebilmemiz için karşılaştığınız hata ekranının ekran görüntüsünü veya ilgili zaman aralığındaki API request ID değerini bizimle paylaşabilir misiniz?"
)

CannedResponse.create!(
  title: "Çözüm Bildirimi & Kapatma Onayı",
  category: "Çözüm",
  content: "Merhaba,\n\nBildirdiğiniz sorun giderilmiştir. Kontrol edip herhangi bir aksaklık olması durumunda bu talebi yanıtlayarak yeniden açabilirsiniz.\n\nSağlıklı günler dileriz."
)

# 2. Bilgi Bankası Makaleleri (Knowledge Base)
Article.create!(
  title: "REST API ve Webhook Güvenlik Doğrulaması",
  category: "Entegrasyon & API",
  body: "Gelen webhook payload'larının doğruluğunu test etmek için header içerisindeki X-PulseDesk-Signature değerini webhook gizli anahtarınızla HMAC SHA256 kullanarak hash'leyiniz.",
  published: true
)

Article.create!(
  title: "İki Aşamalı Doğrulama (2FA) Sıfırlama Kılavuzu",
  category: "Hesap & Güvenlik",
  body: "Telefon değişikliği veya authenticator erişim kaybı durumunda kayıtlı e-posta adresinize tek kullanımlık kurtarma bağlantısı gönderilerek 2FA güvenle sıfırlanabilir.",
  published: true
)

Article.create!(
  title: "GİB Uyumlu e-Fatura Entegrasyonu ve Vergi Alanları",
  category: "Fatura & Ödeme",
  body: "e-Fatura mükellefleri için vergi dairesi ve vergi kimlik numarası (VKN) zorunludur. Profil ayarlarından şirket bilgilerinizi güncelleyebilirsiniz.",
  published: true
)

# 3. SLA İhlali Olan Talep (Geçmişte açılmış ve süresi dolmuş)
breached_ticket = Ticket.create!(
  subject: "Ödeme altyapısı 502 Bad Gateway veriyor",
  description: "Checkout ekranında kart bilgilerini girdikten sonra 502 alıyoruz. Satışlarımız durdu!",
  customer_name: "Mehmet Öztürk",
  customer_email: "mehmet@fintech.co",
  priority: "urgent",
  status: "open",
  category: "Teknik Hata",
  tags: "odeme, kritik, acil",
  assigned_to: agent_user,
  created_at: 5.hours.ago,
  sla_due_at: 3.hours.ago,
  sla_breached: true
)
breached_ticket.ticket_comments.create!(
  author_name: "Ayşe Kaya (DevOps)",
  author_role: "agent",
  body: "Ödeme sağlayıcısının durum sayfasını kontrol ediyoruz, loglar inceleniyor.",
  created_at: 4.hours.ago
)
breached_ticket.ticket_comments.create!(
  author_name: "Ali Yönetici",
  author_role: "agent",
  is_internal_note: true,
  body: "🔒 Dahili Not: Ödeme gateway timeout limitini 30 saniyeye çıkardık, deploy hazırlanıyor.",
  created_at: 3.hours.ago
)

# 4. Yeni Talep (new)
new_ticket = Ticket.create!(
  subject: "Kullanıcı rolleri ve yetkilendirme yapılandırması",
  description: "Ekibimizdeki 3 yeni analiste sadece okuma yetkisi tanımlamak istiyoruz, panelde bu seçenek görünmüyor.",
  customer_name: "Selin Çelik",
  customer_email: "selin@lojistik.com",
  priority: "medium",
  status: "new",
  category: "Hesap & Güvenlik",
  tags: "yetki, onboarding",
  created_at: 30.minutes.ago
)

# 5. Açık Talep (open)
open_ticket = Ticket.create!(
  subject: "API Webhook bildirimleri gecikmeli geliyor",
  description: "Stripe webhook olayları sisteme yaklaşık 15 dakika gecikmeyle ulaşıyor. Kuyruk gecikmesi mi var?",
  customer_name: "Burak Yılmaz",
  customer_email: "burak@startup.io",
  priority: "high",
  status: "open",
  category: "Entegrasyon & API",
  tags: "webhook, queue",
  assigned_to: agent_user,
  created_at: 2.hours.ago
)
open_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "Talebinizi aldık Burak Bey. Webhook işleyicimizin Solid Queue kuyruk doluluğunu kontrol ediyoruz.",
  created_at: 1.hour.ago
)

# 6. Beklemede Talep (pending)
pending_ticket = Ticket.create!(
  subject: "e-Fatura entegrasyonu için ek alan talebi",
  description: "GİB uyumlu e-Fatura kesebilmek için vergi numarası ve vergi dairesi alanlarını profilde zorunlu kılmak istiyoruz.",
  customer_name: "Deniz Arslan",
  customer_email: "deniz@muhasebe.org",
  priority: "medium",
  status: "pending",
  category: "Fatura & Ödeme",
  tags: "efatura, gib",
  created_at: 1.day.ago
)
pending_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "GİB XML şemanızı tarafımıza iletebilir misiniz? İnceleyip entegrasyona ekleyelim.",
  created_at: 20.hours.ago
)

# 7. Çözülmüş Talep (solved)
solved_ticket = Ticket.create!(
  subject: "İki aşamalı doğrulama (2FA) sıfırlama",
  description: "Telefonumu değiştirdiğim için authenticator kodlarıma erişemiyorum.",
  customer_name: "Kerem Koç",
  customer_email: "kerem@tech.net",
  priority: "medium",
  status: "solved",
  category: "Hesap & Güvenlik",
  assigned_to: agent_user,
  solved_at: 2.hours.ago,
  created_at: 6.hours.ago
)
solved_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "Kimlik doğrulamanız başarıyla tamamlandı ve 2FA sıfırlandı. Tekrar giriş yapabilirsiniz.",
  created_at: 2.hours.ago
)

# 8. Mükerrer / Benzer Talep (G2 Duplication Testi)
duplicate_ticket = Ticket.create!(
  subject: "Kullanıcı rolleri paneli hala açılmıyor",
  description: "Daha önce Selin Hanım yazmıştı ama acil çözmemiz gerekiyor.",
  customer_name: "Selin Çelik",
  customer_email: "selin@lojistik.com",
  priority: "high",
  status: "open",
  category: "Hesap & Güvenlik",
  tags: "yetki",
  created_at: 15.minutes.ago
)

# 9. Topluluk Sorusu 1: 26 saat önce sorulmuş, cevapsız -> Otomatik Dönüştürülmüş!
old_unanswered_q = CommunityQuestion.create!(
  title: "REST API üzerinden toplu kullanıcı dışa aktarma (export) nasıl yapılır?",
  body: "10.000'den fazla müşterimiz var. Tek tek GET yapmak yerine CSV formatında toplu export alabileceğimiz bir endpoint mevcut mu?",
  author_name: "Gizem Kurt",
  author_email: "gizem@ecommerce.biz",
  category: "Entegrasyon & API",
  created_at: 26.hours.ago,
  answers_count: 0
)
old_unanswered_q.convert_to_ticket!(reason: "auto_seed")

# 10. Topluluk Sorusu 2: Yanıtı olan soru
answered_q = CommunityQuestion.create!(
  title: "Özel alan (custom domain) ekleme adımları",
  body: "destek.sirketimiz.com şeklinde kendi alt alan adımızı nasıl yönlendirebiliriz?",
  author_name: "Emre Şen",
  author_email: "emre@ajans.com",
  category: "Genel Destek",
  created_at: 12.hours.ago
)
answered_q.community_answers.create!(
  author_name: "Topluluk Gönüllüsü",
  body: "CNAME kaydınızı dns.pulsedesk.io adresine yönlendirip SSL sertifikasının oluşturulmasını bekleyebilirsiniz."
)

# 11. Topluluk Sorusu 3: Yeni soru (< 24 saat, yanıt bekliyor)
recent_q = CommunityQuestion.create!(
  title: "Webhook imza doğrulaması (HMAC SHA256) örneği var mı?",
  body: "Gelen webhook payload'larının güvenliğini doğrulamak için header'daki X-PulseDesk-Signature nasıl kontrol edilmeli?",
  author_name: "Ozan Tekin",
  author_email: "ozan@developer.dev",
  category: "Entegrasyon & API",
  created_at: 4.hours.ago
)

# 12. Otomasyon Kuralları (Önceden Tanımlı Kural Kataloğu)
rule1 = AutomationRule.create!(
  name: "Atanmamış Yeni Talepleri Mert Demir'e Ata",
  description: "Yeni açılan ve henüz sahipsiz olan talepleri doğrudan birinci seviye destek temsilcisine yönlendirir.",
  trigger_type: "event",
  conditions: { "status" => "new", "unassigned" => true }.to_json,
  actions: { "assign_to_user_id" => agent_user.id, "add_tag" => "otomatik_atandi" }.to_json,
  active: true,
  priority_order: 1
)

rule2 = AutomationRule.create!(
  name: "SLA İhlali Olan Talepleri Yöneticiye Eskale Et",
  description: "SLA süresi aşılmış olan açık talepleri tespit eder, önceliğini Acil (Urgent) yapar ve yöneticiye atar.",
  trigger_type: "time_based",
  conditions: { "status" => "breached" }.to_json,
  actions: { "set_priority" => "urgent", "assign_to_user_id" => admin_user.id, "add_tag" => "sla_eskale" }.to_json,
  active: true,
  priority_order: 2
)

# 13. Örnek Bildirimler
agent_user.notifications.create!(
  title: "⚠️ SLA İhlali Uyarısı",
  message: "#PD-1001 ('Ödeme altyapısı 502 Bad Gateway veriyor') talebinin SLA hedef süresi aşıldı!",
  notifiable: breached_ticket,
  read: false
)

agent_user.notifications.create!(
  title: "💬 Yeni Topluluk Sorusu Dönüştürüldü",
  message: "Topluluk forumunda 24 saattir cevapsız kalan bir soru otomatik olarak destek talebine aktarıldı.",
  notifiable: old_unanswered_q.ticket,
  read: false
)

puts "Tohum verileri eksiksiz ve başarıyla yüklendi!"

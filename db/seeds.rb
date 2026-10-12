# PulseDesk Demo Seeds
puts "Tohum verileri yükleniyor..."

TicketComment.destroy_all
CommunityAnswer.destroy_all
Ticket.destroy_all
CommunityQuestion.destroy_all

# 1. SLA İhlali Olan Talep (Geçmişte açılmış ve yanıtlanmamış)
breached_ticket = Ticket.create!(
  subject: "Ödeme altyapısı 502 Bad Gateway veriyor",
  description: "Checkout ekranında kart bilgilerini girdikten sonra 502 alıyoruz. Satışlarımız durdu!",
  customer_name: "Mehmet Öztürk",
  customer_email: "mehmet@fintech.co",
  priority: "urgent",
  status: "open",
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

# 2. Yeni Talep (new)
new_ticket = Ticket.create!(
  subject: "Kullanıcı rolleri ve yetkilendirme yapılandırması",
  description: "Ekibimizdeki 3 yeni analiste sadece okuma yetkisi tanımlamak istiyoruz, panelde bu seçenek görünmüyor.",
  customer_name: "Selin Çelik",
  customer_email: "selin@lojistik.com",
  priority: "medium",
  status: "new",
  created_at: 30.minutes.ago
)

# 3. İncelenmekte Olan Açık Talep (open)
open_ticket = Ticket.create!(
  subject: "API Webhook bildirimleri gecikmeli geliyor",
  description: "Stripe webhook olayları sisteme yaklaşık 15 dakika gecikmeyle ulaşıyor. Kuyruk gecikmesi mi var?",
  customer_name: "Burak Yılmaz",
  customer_email: "burak@startup.io",
  priority: "high",
  status: "open",
  created_at: 2.hours.ago
)
open_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "Talebinizi aldık Burak Bey. Webhook işleyicimizin Solid Queue kuyruk doluluğunu kontrol ediyoruz.",
  created_at: 1.hour.ago
)

# 4. Beklemede Talep (pending)
pending_ticket = Ticket.create!(
  subject: "e-Fatura entegrasyonu için ek alan talebi",
  description: "GİB uyumlu e-Fatura kesebilmek için vergi numarası ve vergi dairesi alanlarını profilde zorunlu kılmak istiyoruz.",
  customer_name: "Deniz Arslan",
  customer_email: "deniz@muhasebe.org",
  priority: "medium",
  status: "pending",
  created_at: 1.day.ago
)
pending_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "GİB XML şemanızı tarafımıza iletebilir misiniz? İnceleyip entegrasyona ekleyelim.",
  created_at: 20.hours.ago
)

# 5. Başarıyla Çözülmüş Talep (solved)
solved_ticket = Ticket.create!(
  subject: "İki aşamalı doğrulama (2FA) sıfırlama",
  description: "Telefonumu değiştirdiğim için authenticator kodlarıma erişemiyorum.",
  customer_name: "Kerem Koç",
  customer_email: "kerem@tech.net",
  priority: "medium",
  status: "solved",
  solved_at: 2.hours.ago,
  created_at: 6.hours.ago
)
solved_ticket.ticket_comments.create!(
  author_name: "Mert Demir (Destek Ekibi)",
  author_role: "agent",
  body: "Kimlik doğrulamanız başarıyla tamamlandı ve 2FA sıfırlandı. Tekrar giriş yapabilirsiniz.",
  created_at: 2.hours.ago
)

# 6. Topluluk Sorusu 1: 26 saat önce sorulmuş, cevapsız -> Otomatik dönüştürülmüş!
old_unanswered_q = CommunityQuestion.create!(
  title: "REST API üzerinden toplu kullanıcı dışa aktarma (export) nasıl yapılır?",
  body: "10.000'den fazla müşterimiz var. Tek tek GET yapmak yerine CSV formatında toplu export alabileceğimiz bir endpoint mevcut mu?",
  author_name: "Gizem Kurt",
  author_email: "gizem@ecommerce.biz",
  category: "Entegrasyon",
  created_at: 26.hours.ago,
  answers_count: 0
)

# 24 saat kuralı gereği otomatik olarak dönüştürülüyor
converted_ticket = old_unanswered_q.convert_to_ticket!(reason: "auto_seed")

# 7. Topluluk Sorusu 2: Yanıtı olan soru (Dönüştürülmez)
answered_q = CommunityQuestion.create!(
  title: "Özel alan (custom domain) ekleme adımları",
  body: "destek.sirketimiz.com şeklinde kendi alt alan adımızı nasıl yönlendirebiliriz?",
  author_name: "Emre Şen",
  author_email: "emre@ajans.com",
  category: "Genel",
  created_at: 12.hours.ago
)
answered_q.community_answers.create!(
  author_name: "Topluluk Gönüllüsü",
  body: "CNAME kaydınızı dns.pulsedesk.io adresine yönlendirip SSL sertifikasının oluşturulmasını bekleyebilirsiniz."
)

# 8. Topluluk Sorusu 3: Yeni soru (< 24 saat, yanıt bekliyor)
recent_q = CommunityQuestion.create!(
  title: "Webhook imza doğrulaması (HMAC SHA256) örneği var mı?",
  body: "Gelen webhook payload'larının güvenliğini doğrulamak için header'daki X-PulseDesk-Signature nasıl kontrol edilmeli?",
  author_name: "Ozan Tekin",
  author_email: "ozan@developer.dev",
  category: "Entegrasyon",
  created_at: 4.hours.ago
)

puts "Tohum verileri başarıyla yüklendi!"
puts "Destek Talebi Sayısı: #{Ticket.count}"
puts "Topluluk Sorusu Sayısı: #{CommunityQuestion.count}"

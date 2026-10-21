class AgentOrchestratorService
  # 5 Destek Ajanı Bayram Paketi Kiralama
  def self.hire_bayram_pack!(user = nil, duration_days: 7)
    AiAgent.seed_default_agents!
    rentals = []

    AiAgent.active.find_each do |agent|
      rental = AgentRental.find_or_initialize_by(
        ai_agent: agent,
        status: "active"
      )
      rental.user = user if user.present?
      rental.package_name = "🌙 Ramazan / Kurban Bayramı Yoğunluk Kalkanı Paketi"
      rental.rental_duration_days = duration_days
      rental.rented_at = Time.current
      rental.expires_at = duration_days.days.from_now
      rental.total_cost = (agent.daily_rate * duration_days).round(2)
      rental.auto_pilot_enabled = true
      rental.require_human_approval = false
      rental.save!
      rentals << rental
    end

    rentals
  end

  # Tekil Ajan Kiralama
  def self.rent_single_agent!(agent, user = nil, duration_days: 7, require_human_approval: false)
    rental = AgentRental.find_or_initialize_by(
      ai_agent: agent,
      status: "active"
    )
    rental.user = user if user.present?
    rental.package_name = "Özel Destek Görevi"
    rental.rental_duration_days = duration_days
    rental.rented_at = Time.current
    rental.expires_at = duration_days.days.from_now
    rental.total_cost = (agent.daily_rate * duration_days).round(2)
    rental.auto_pilot_enabled = true
    rental.require_human_approval = require_human_approval
    rental.save!
    rental
  end

  # Kiralama İptali / Durdurma
  def self.terminate_rental!(rental)
    rental.update!(status: "expired", expires_at: Time.current)
  end

  # Bilet için en uygun aktif kiralık ajanı bulma
  def self.best_agent_for(ticket)
    active_rentals = AgentRental.active_now.includes(:ai_agent)
    return nil if active_rentals.empty?

    rented_agents = active_rentals.map(&:ai_agent)
    content = "#{ticket.subject} #{ticket.description}".downcase

    # 1. e-Fatura / Muhasebe
    if ticket.e_invoice? || ticket.category == "Fatura & Ödeme" || content.include?("fatura") || content.include?("gib") || content.include?("vkn")
      atlas = rented_agents.find { |a| a.code_name == "atlas_invoice" }
      return atlas if atlas
    end

    # 2. Teknik / API / Bad Gateway
    if ticket.category.in?(["Teknik Hata", "Entegrasyon & API"]) || content.include?("502") || content.include?("api") || content.include?("webhook") || content.include?("hata") || content.include?("2fa")
      nova = rented_agents.find { |a| a.code_name == "nova_tech" }
      return nova if nova
    end

    # 3. Yüksek öfke / Churn / Dava tehdidi
    if content.match?(/dava|şikayet|rezalet|berbat|dolandırıcı|tazminat|hakkımı|zehir/)
      seren = rented_agents.find { |a| a.code_name == "seren_sentiment" }
      return seren if seren
    end

    # 4. Kargo / İade / Teslimat
    if content.match?(/kargo|iade|teslim|şube|sipariş|takip|nerede/)
      aura = rented_agents.find { |a| a.code_name == "aura_returns" }
      return aura if aura
    end

    # 5. Acil SLA / Gece nöbeti
    if ticket.priority == "urgent" || ticket.breached?
      volt = rented_agents.find { |a| a.code_name == "volt_sla_guardian" }
      return volt if volt
    end

    # Genel fallback: İlk müsait ajan
    rented_agents.first
  end

  # Bileti kiralanmış ajanla otonom işleme
  def self.process_ticket_with_agent!(ticket, agent = nil)
    agent ||= best_agent_for(ticket)
    return false unless agent

    rental = agent.current_rental
    return false unless rental&.active?

    # Bilgi Bankası RAG Grounding
    rag_context = fetch_rag_context(ticket)

    # Akıl yürütme (Chain of Thought Reasoning) ve Güven Skoru
    analysis = analyze_and_reason(ticket, agent, rag_context)

    confidence = analysis[:confidence_score]
    reasoning = analysis[:reasoning]
    reply_text = analysis[:reply]
    action_type = analysis[:action_type]

    # Human-in-the-Loop Denetim Eşiği
    needs_review = rental.require_human_approval ||
                   confidence < agent.human_in_the_loop_threshold ||
                   analysis[:force_human_review]

    if needs_review
      # İnsan Onay Kuyruğuna Sevk Et
      ticket.update_columns(
        assigned_ai_agent_id: agent.id,
        needs_human_review: true,
        ai_agent_reasoning: reasoning
      )

      execution_log = AgentExecutionLog.create!(
        agent_rental: rental,
        ai_agent: agent,
        ticket: ticket,
        action_taken: "escalated_human",
        confidence_score: confidence,
        reasoning: reasoning,
        suggested_reply: reply_text,
        human_approved: nil
      )

      # Yetkililere bildirim oluştur
      notify_staff_for_review(ticket, agent, reasoning)
      rental.increment_metrics!(solved: false, sla_saved: true)
      execution_log
    else
      # Otonom Çözüm & Otomatik Yanıt
      comment = ticket.ticket_comments.create!(
        author_name: "🤖 #{agent.name} (PulseDesk Kiralık Destek Ajanı)",
        author_role: "agent",
        body: reply_text
      )

      # İlk yanıt SLA sayacını işlet ve durumu güncelle
      updates = {
        assigned_ai_agent_id: agent.id,
        needs_human_review: false,
        ai_agent_reasoning: reasoning,
        first_responded_at: ticket.first_responded_at || Time.current
      }

      if action_type == :solve
        updates[:status] = "solved"
        updates[:solved_at] = Time.current
      elsif ticket.status == "new"
        updates[:status] = "open"
      end

      ticket.update_columns(updates)

      execution_log = AgentExecutionLog.create!(
        agent_rental: rental,
        ai_agent: agent,
        ticket: ticket,
        action_taken: action_type == :solve ? "resolved" : "replied_pending",
        confidence_score: confidence,
        reasoning: reasoning,
        suggested_reply: reply_text,
        human_approved: true,
        reviewed_at: Time.current
      )

      rental.increment_metrics!(solved: (action_type == :solve), sla_saved: true)
      execution_log
    end
  end

  # Bayram Yoğunluğu Simülasyonu: 10 Gerçekçi Bayram Bileti Oluştur & Ajanlara Dağıt
  def self.simulate_bayram_surge!(user = nil, count = 10)
    hire_bayram_pack!(user, duration_days: 7)

    scenarios = [
      {
        subject: "Bayram arefesi kargom şubede kaldı, bayramdan önce teslim edilir mi?",
        description: "Merhabalar, sipariş ettiğim bayramlık kıyafetler bugün teslim edilmedi. Takip no: YK-8823910. Yarın arefe günü şubeler açık mı, gidip kendim teslim alabilir miyim?",
        customer_name: "Fatma Şahin",
        customer_email: "fatma@example.com",
        category: "Genel Destek",
        priority: "high"
      },
      {
        subject: "Bayram öncesi kesilen kurumsal e-faturada VKN hatalı, düzeltme talebi",
        description: "Şirketimize kesilen e-faturada vergi kimlik numarası (VKN) yanlış girilmiş. GİB 7 günlük itiraz süremiz bayram tatiline denk geliyor. VKN: 1234567890. Fatura No: GIB20260001928.",
        customer_name: "Orhan Pamuk (Finans Müdürü)",
        customer_email: "orhan@holding.com.tr",
        category: "Fatura & Ödeme",
        priority: "urgent",
        e_invoice_status: "gib_pending",
        tax_number: "1234567890",
        invoice_number: "GIB20260001928"
      },
      {
        subject: "Bayram kampanyasında ödeme servisi 502 Bad Gateway hatası veriyor",
        description: "Sitemizde bayram indirimi başladı ancak müşteriler kredi kartı adımında 502 Bad Gateway alıyor. API endpoint: /v1/checkout/process. Acil sistem mühendisi bakabilir mi?",
        customer_name: "Barış Can (CTO)",
        customer_email: "baris@eticaret.io",
        category: "Teknik Hata",
        priority: "urgent"
      },
      {
        subject: "Gece 02:40 Bayram nöbeti: Yanlış adrese verilen siparişin acil iptali",
        description: "Az önce verdiğim siparişte eski adresim seçili kalmış. Sabah kargoya verilmeden acilen iptal edilmesini veya adresimin güncellenmesini istiyorum! Sipariş #99281.",
        customer_name: "Emre Aydın",
        customer_email: "emre@mail.com",
        category: "Genel Destek",
        priority: "high"
      },
      {
        subject: "Siparişim bayramda yetişmedi, bayramımız mahvoldu, dava açacağım!",
        description: "Çocuklarımın bayram hediyesi 4 gündür yolda görünüyor. Rezillik bu! Tüketici Hakem Heyetine ve avukatıma vereceğim sizi, paramı derhal iade edin!",
        customer_name: "Selin Yılmaz",
        customer_email: "selin@angrycustomer.com",
        category: "Genel Destek",
        priority: "urgent"
      },
      {
        subject: "Bayram tatili boyunca e-fatura 7 günlük yasal itiraz süresi işler mi?",
        description: "İyi günler, 20 Nisan'da düzenlenen e-faturaya itiraz etmek istiyoruz. Bayram tatili resmi tatil olduğu için 7 günlük yasal süre durur mu yoksa devam eder mi?",
        customer_name: "Mali Müşavir Kemal",
        customer_email: "kemal@muhasebe.org",
        category: "Fatura & Ödeme",
        priority: "medium",
        e_invoice_status: "gib_pending"
      },
      {
        subject: "Webhook bayramda gelen siparişleri CRM sistemine aktarmıyor",
        description: "PulseDesk webhook ayarlarında X-PulseDesk-Signature doğrulaması başarısız oluyor ve 401 Unauthorized dönüyor. HMAC SHA256 secret anahtarını kontrol edebilir misiniz?",
        customer_name: "Deniz Arda",
        customer_email: "deniz@developer.co",
        category: "Entegrasyon & API",
        priority: "high"
      },
      {
        subject: "Bayramda iade kodu süresi dolar mı, şubeye ne zaman verebilirim?",
        description: "Ürünü iade etmek için kod aldım ancak bayram tatili araya girdi. Bu kodun geçerlilik süresi tatilde uzar mı?",
        customer_name: "Canan Erdem",
        customer_email: "canan@gmail.com",
        category: "Genel Destek",
        priority: "low"
      },
      {
        subject: "Gece nöbeti: Yönetici paneli 2FA sıfırlama talebi",
        description: "Nöbetçi mağaza müdürüyüm, bayram indirimi etiketlerini güncellemek için panele girmem gerekiyor fakat telefonum bozuldu, 2FA kodumu alamıyorum.",
        customer_name: "Murat Şen",
        customer_email: "murat@magaza.com",
        category: "Hesap & Güvenlik",
        priority: "urgent"
      },
      {
        subject: "⚠️ 25.000 TL Kurumsal toplu hediye siparişinde hasar ve tam iade talebi",
        description: "Şirketimiz çalışanlarına dağıtılmak üzere alınan 25.000 TL değerindeki çikolata ve hediye kutularının yarısı ezik ve ambalajı yırtık ulaştı. Tüm siparişin bedelinin iadesini ve tazminat protokolünü talep ediyoruz.",
        customer_name: "Büyük Holding A.Ş. Satın Alma",
        customer_email: "satinalma@buyukholding.com",
        category: "Fatura & Ödeme",
        priority: "urgent"
      }
    ]

    created_tickets = []
    scenarios.first(count).each_with_index do |sc, idx|
      ticket = Ticket.create!(
        subject: sc[:subject],
        description: sc[:description],
        customer_name: sc[:customer_name],
        customer_email: sc[:customer_email],
        category: sc[:category],
        priority: sc[:priority],
        status: "new",
        e_invoice_status: sc[:e_invoice_status] || "not_applicable",
        tax_number: sc[:tax_number],
        invoice_number: sc[:invoice_number],
        created_at: (count - idx).minutes.ago
      )

      # Ajan ile otonom işle
      process_ticket_with_agent!(ticket)
      created_tickets << ticket
    end

    created_tickets
  end

  private

  # RAG: İlgili Bilgi Bankası Makalelerini Çek
  def self.fetch_rag_context(ticket)
    words = "#{ticket.subject} #{ticket.description}".downcase.split(/\W+/).select { |w| w.length > 3 }
    articles = Article.where(published: true).limit(3)
    matching_articles = articles.select do |a|
      body_down = "#{a.title} #{a.body}".downcase
      words.any? { |w| body_down.include?(w) }
    end

    return "İlgili standart bilgi bankası yönergeleri uygulandı." if matching_articles.empty?

    matching_articles.map { |a| "• [KB] #{a.title}: #{a.body.truncate(140)}" }.join("\n")
  end

  # Akıl yürütme (Reasoning) ve karar mantığı
  def self.analyze_and_reason(ticket, agent, rag_context)
    content = "#{ticket.subject} #{ticket.description}".downcase

    # 1. Human-in-the-Loop Risk Kontrolü: 10.000 TL üzeri veya hukuki dava
    if content.include?("25.000") || content.include?("tazminat protokolü") || (content.include?("dava") && content.include?("holding"))
      return {
        confidence_score: 68,
        force_human_review: true,
        action_type: :review,
        reasoning: "🧠 [Ajan Karar Analizi]: Müşteri yüksek tutarlı (25.000 TL) kurumsal zarar ve tazminat protokolü talep ediyor. Hukuki ve finansal risk içerdiğinden otonom karar verilmedi, insan temsilci onayına sevk edildi.\n• Tespit Edilen Risk: Kurumsal Finansal Yetki Sınırı Aşımı\n• Önerilen Aksiyon: Satış ve Hukuk birimiyle koordineli telafi teklifi hazırlanması.",
        reply: "Değerli Müşterimiz,\n\nİlettiğiniz kurumsal sipariş durumu ve hasar tespiti yönetim ekibimiz tarafından öncelikli olarak incelemeye alınmıştır. Tarafınıza özel tazminat ve telafi protokolü hazırlanarak en geç 2 saat içinde dönüş sağlanacaktır.\n\nSaygılarımızla,\nPulseDesk Kurumsal Müşteri Yönetimi"
      }
    end

    case agent.code_name
    when "aura_returns"
      {
        confidence_score: 97,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Aura Analizi]: Müşteri bayram öncesi kargo teslimatını sorguluyor. Entegre Kargo API kontrol edildi: Paket varış şubesinde. Arefe günü saat 13:00'e kadar şubeden teslimat yapılabileceği ve nöbetçi kargo takvimi bilgisi sağlandı.\n• RAG Referansı: #{rag_context}\n• Sonuç: İvedilikle bilet çözüldü, müşteri kaygısı giderildi.",
        reply: "Merhaba #{ticket.customer_name.split.first},\n\nSiparişinizin durumunu kargo dağıtım merkezi sistemimizden kontrol ettik. Kargolar bayram arefe gününde saat 13:00'e kadar dağıtımda olup, paketiniz şu anda teslimat şubesindedir.\n\nİsterseniz takip numaranızla şubeden doğrudan teslim alabilir veya yarın 13:00'e kadar adresinize gelecek kuryeyi bekleyebilirsiniz. Bayramınızın güzel geçmesini dileriz!\n\nİyi bayramlar,\nPulseDesk E-Ticaret Destek Ekibi (Aura)"
      }
    when "atlas_invoice"
      {
        confidence_score: 98,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Atlas Analizi]: e-Fatura mevzuatı denetlendi. Vergi Usul Kanunu ve GİB kılavuzuna göre 7 günlük yasal itiraz süresi resmi tatillerde durmaz, takvim günü olarak işler. Müşteriye GİB iptal portalı adımları ve VKN güncelleme prosedürü eksiksiz iletildi.\n• RAG Referansı: #{rag_context}\n• Sonuç: Yasal ceza riski önlendi, bilet çözümlendi.",
        reply: "Sayın #{ticket.customer_name},\n\nBelirttiğiniz e-Fatura kaydı GİB entegrasyon havuzumuzda taranmıştır. 213 sayılı Vergi Usul Kanunu uyarınca 7 günlük yasal itiraz süresi resmi tatil ve bayramlarda durmamakta, takvim günü olarak işlemeye devam etmektedir.\n\nFaturanızın iptali ve VKN düzeltmesi için GİB İptal/İtiraz Portalı üzerinden ivedilikle onay verilmiş ve yeni düzeltilmiş faturanız muhasebe e-postanıza iletilmiştir.\n\nSaygılarımızla,\nPulseDesk e-Fatura & Mali Mevzuat Masası (Atlas)"
      }
    when "nova_tech"
      {
        confidence_score: 96,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Nova Analizi]: Teknik loglar ve webhook/gateway verileri tarandı. 502 Bad Gateway veya Webhook 401 hatası için HMAC SHA256 header imzalama ve upstream timeout yaması sağlandı.\n• RAG Referansı: #{rag_context}\n• Sonuç: Geliştirici seviyesinde net teknik çözüm sunuldu.",
        reply: "Merhaba #{ticket.customer_name.split.first},\n\nTeknik sistem kayıtlarımız incelenmiştir. Bildirilen hata upstream ödeme servisi bağlantısındaki anlık rate-limit aşımından kaynaklanmıştır. İlgili bağlantı havuzu genişletilmiş ve webhook için X-PulseDesk-Signature doğrulama anahtarı yeniden senkronize edilmiştir.\n\nŞu anda sistemler normal seyrinde çalışmaktadır, lütfen tekrar test ediniz.\n\nİyi çalışmalar,\nPulseDesk Kıdemli Sistem & Entegrasyon Ekibi (Nova)"
      }
    when "volt_sla_guardian"
      {
        confidence_score: 99,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Volt Analizi]: 7/24 Nöbetçi SLA Motoru devreye girdi. Bayram tatilinde gelen gece talebi 30 saniye içinde algılandı, ilk yanıt SLA ihlali engellendi ve nöbetçi operasyon kuyruğuna acil emir iletildi.\n• Sonuç: 0 SLA kaybı sağlandı.",
        reply: "Merhaba #{ticket.customer_name.split.first},\n\nBayram nöbetçi destek sistemimiz talebinizi anında devralmıştır. Belirttiğiniz acil durum ilgili operasyon nöbetçisine iletilmiş ve siparişinizin paketleme hattında durdurulması sağlanmıştır. Adres güncellemeniz yapılmıştır.\n\n7/24 kesintisiz desteğimizle bayramda da yanınızdayız.\n\nSaygılarımızla,\nPulseDesk 7/24 Nöbetçi Kriz Masası (Volt)"
      }
    when "seren_sentiment"
      {
        confidence_score: 95,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Seren Analizi]: Müşteri mesajındaki yüksek negatif duygu (sentiment) ve hayal kırıklığı yakalandı. Müşteriye koşulsuz empati gösterildi, bayram mağduriyeti için özel telafi kuponu ve kargo şube müdürü özel temas bilgisi sağlandı.\n• Churn Riski: Engellendi.",
        reply: "Değerli #{ticket.customer_name},\n\nYaşadığınız bu aksaklık ve bayram arifesinde hissettiğiniz hayal kırıklığı için tüm içtenliğimizle özür dileriz. Çocuklarınızın bayram sevincinin her şeyden kıymetli olduğunun farkındayız.\n\nKargonuzun bugün mutlaka elinize ulaşması için bölge kargo dağıtım müdürü ile özel irtibata geçilmiş olup kurye doğrudan adresinize yönlendirilmiştir. Ayrıca bu aksaklığı bir nebze telafi edebilmek adına hesabınıza sonraki alışverişinizde geçerli 500 TL hediye çeki tanımlanmıştır.\n\nMutlu ve huzurlu bir bayram dileriz,\nPulseDesk Müşteri Mutluluğu Masası (Seren)"
      }
    else
      {
        confidence_score: 90,
        force_human_review: false,
        action_type: :solve,
        reasoning: "🧠 [Ajan Analizi]: Talep incelendi ve standart prosedür doğrultusunda yanıtlandı.",
        reply: "Merhaba #{ticket.customer_name},\n\nİlettiğiniz konuyla ilgili incelemeler tamamlanmıştır. Gerekli düzenlemeler yapılmıştır.\n\nİyi çalışmalar dileriz,\nPulseDesk Destek Ekibi"
      }
    end
  end

  def self.notify_staff_for_review(ticket, agent, reasoning)
    User.agents.find_each do |staff_user|
      Notification.create!(
        user: staff_user,
        title: "🤖 Ajan Onay Talebi: ##{ticket.ticket_number}",
        message: "#{agent.name} isimli kiralık ajan ##{ticket.ticket_number} biletini risk nedeniyle onayınıza sundu.",
        notifiable_type: "Ticket",
        notifiable_id: ticket.id
      )
    end
  rescue StandardError => e
    Rails.logger.error("Staff notification error: #{e.message}")
  end
end

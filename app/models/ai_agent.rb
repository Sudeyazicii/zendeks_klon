class AiAgent < ApplicationRecord
  has_many :agent_rentals, dependent: :destroy
  has_many :agent_execution_logs, dependent: :destroy
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: "assigned_ai_agent_id", dependent: :nullify

  validates :name, presence: true
  validates :code_name, presence: true, uniqueness: true
  validates :role_title, presence: true
  validates :specialty, presence: true
  validates :category_focus, presence: true
  validates :bio, presence: true

  scope :active, -> { where(active: true) }

  # Ajan şu an aktif olarak kiralanmış mı?
  def currently_rented?
    agent_rentals.active_now.exists?
  end

  def current_rental
    agent_rentals.active_now.order(created_at: :desc).first
  end

  # Uzmanlık kategorisine göre etiket dizisi
  def skills_list
    skills_tags.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # Bayram Nöbet Paketi için 5 Temel Ajanın Tanımı
  BAYRAM_PACK_AGENTS = [
    {
      name: "Aura",
      code_name: "aura_returns",
      role_title: "E-Ticaret & İade Operasyon Ajanı",
      avatar: "📦",
      badge_color: "#2563eb",
      specialty: "Sipariş takibi, kargo gecikmesi, iade kodu üretme ve kargo şubesi yönlendirmesi",
      category_focus: "Genel Destek",
      skills_tags: "Kargo Takip, İade Onayı, Bayram Teslimat, Adres Güncelleme, Hızlı Çözüm",
      llm_model_name: "gpt-4o-mini",
      hourly_rate: 45.0,
      daily_rate: 250.0,
      rating: 4.98,
      reviews_count: 184,
      accuracy_rate: 99,
      human_in_the_loop_threshold: 80,
      bio: "Bayram arefesi ve tatil döneminde kargoların gecikmesiyle çıldıran müşterileri sakinleştirir, kargo API entegrasyonuyla anlık takip numarası ve en yakın açık nöbetçi kargo şubesini bilet yanıtında sunar.",
      system_prompt: "Sen PulseDesk bünyesinde çalışan Aura isimli E-Ticaret ve İade Destek Ajanısın. Bayram yoğunluğunda gelen kargo, iade ve sipariş gecikmesi taleplerini empatiyle, net adımlarla ve hızlıca çözersin."
    },
    {
      name: "Atlas",
      code_name: "atlas_invoice",
      role_title: "e-Fatura & GİB Yasal Mevzuat Ajanı",
      avatar: "🧾",
      badge_color: "#d97706",
      specialty: "GİB 7 günlük itiraz süresi, VKN/TCKN teyidi, e-Arşiv/e-Fatura iptal ve düzeltme süreçleri",
      category_focus: "Fatura & Ödeme",
      skills_tags: "GİB e-Fatura, 7 Günlük SLA, VKN Doğrulama, İtiraz Dilekçesi, Muhasebe API",
      llm_model_name: "gpt-4o-mini",
      hourly_rate: 55.0,
      daily_rate: 300.0,
      rating: 4.96,
      reviews_count: 142,
      accuracy_rate: 99,
      human_in_the_loop_threshold: 85,
      bio: "Maliye Bakanlığı ve Gelir İdaresi Başkanlığı (GİB) 7 günlük yasal itiraz takvimine göre fatura uyuşmazlıklarını çözer. 10 haneli VKN veya 11 haneli TCKN formatlarını anında denetler, şirketlerin ceza yemesini engeller.",
      system_prompt: "Sen PulseDesk bünyesinde çalışan Atlas isimli e-Fatura ve Muhasebe Destek Ajanısın. Türk vergi mevzuatı ve GİB portalı kurallarına tam hakimsin. Hatalı fatura biletlerinde VKN kontrolü ve 7 günlük yasal itiraz prosedürünü işletirsin."
    },
    {
      name: "Volt",
      code_name: "volt_sla_guardian",
      role_title: "7/24 Nöbetçi Kriz & SLA Koruyucu Ajan",
      avatar: "⚡",
      badge_color: "#dc2626",
      specialty: "Bayram ve gece nöbetinde biletleri 30 saniyede triyaj edip ilk yanıt SLA ihlalini sıfırlama",
      category_focus: "Genel Destek",
      skills_tags: "30 Saniye SLA, Acil Triyaj, Gece Nöbeti, Kesintisiz Yanıt, Önceliklendirme",
      llm_model_name: "gpt-4o-mini",
      hourly_rate: 60.0,
      daily_rate: 320.0,
      rating: 5.0,
      reviews_count: 230,
      accuracy_rate: 99,
      human_in_the_loop_threshold: 75,
      bio: "Bayram tatilinde tüm insan temsilciler dinlenirken devreye girer. Gece 03:00'te açılan kritik biletleri 30 saniye içinde algılar, ilk yanıt SLA'sını kurtarır ve doğru aksiyon planını devreye alır.",
      system_prompt: "Sen PulseDesk 7/24 Nöbetçi Kriz Ajanı Volt'sun. Ana görevin bayram ve resmi tatillerde gelen biletlerin SLA süresinin dolmasını engellemek, ivedilikle ilk yanıtı verip doğru departman aksiyonunu başlatmaktır."
    },
    {
      name: "Nova",
      code_name: "nova_tech",
      role_title: "Teknik Entegrasyon & API Sorun Giderici",
      avatar: "🛠️",
      badge_color: "#7c3aed",
      specialty: "502/500 sunucu hataları, webhook imza doğrulama, API token ve 2FA kurtarma",
      category_focus: "Teknik Hata",
      skills_tags: "REST API, Webhook HMAC, 502 Bad Gateway, 2FA Kurtarma, Log Analizi",
      llm_model_name: "gpt-4o-mini",
      hourly_rate: 65.0,
      daily_rate: 350.0,
      rating: 4.94,
      reviews_count: 118,
      accuracy_rate: 97,
      human_in_the_loop_threshold: 85,
      bio: "Teknik logları, webhook HTTP hata kodlarını ve API payload'larını analiz eder. Geliştirici seviyesinde net curl komutları, HTTP header çözümleri ve kod yamaları önerir.",
      system_prompt: "Sen PulseDesk bünyesinde Teknik Destek Ajanı Nova'sın. API, Webhook, sunucu hataları (502, 500) ve güvenlik konularında kıdemli bir yazılım mühendisi titizliğiyle yanıt verirsin."
    },
    {
      name: "Seren",
      code_name: "seren_sentiment",
      role_title: "Müşteri Yatıştırıcı & VIP Sadakat Ajanı",
      avatar: "💎",
      badge_color: "#059669",
      specialty: "Aşırı öfkeli, hayal kırıklığına uğramış müşterileri yatıştırma, telafi ve jest yönetimi",
      category_focus: "Genel Destek",
      skills_tags: "Yüksek Empati, De-escalation, VIP Destek, Telafi Kuponu, Churn Önleme",
      llm_model_name: "gpt-4o-mini",
      hourly_rate: 50.0,
      daily_rate: 280.0,
      rating: 4.97,
      reviews_count: 165,
      accuracy_rate: 98,
      human_in_the_loop_threshold: 80,
      bio: "Duygu analizi (sentiment) motoruyla 'rezalet, dava edeceğim, iptal edin' diyen öfkeli müşterileri anında yakalar. İnsan psikolojisine uygun yüksek empatik dille iletişim kurarak müşteriyi sakinleştirir ve kaybetmeyi (churn) önler.",
      system_prompt: "Sen PulseDesk bünyesinde Müşteri Memnuniyeti ve Sadakat Ajanı Seren'sin. Agresif veya kırgın müşterilere son derece nazik, yapıcı ve çözüm üretici bir tonda yaklaşırsın."
    }
  ].freeze

  def self.seed_default_agents!
    BAYRAM_PACK_AGENTS.each do |data|
      agent = find_or_initialize_by(code_name: data[:code_name])
      agent.assign_attributes(data)
      agent.save!
    end
  end
end

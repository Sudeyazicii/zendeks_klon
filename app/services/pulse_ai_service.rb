require "net/http"
require "json"

class PulseAiService
  # Talep özetleme fonksiyonu
  def self.summarize(ticket)
    if ENV["OPENAI_API_KEY"].present?
      call_openai_summary(ticket)
    elsif ENV["GEMINI_API_KEY"].present?
      call_gemini_summary(ticket)
    else
      local_nlp_summary(ticket)
    end
  end
 
  # Akıllı yanıt taslağı hazırlama
  def self.generate_draft_reply(ticket)
    customer_first_name = ticket.customer_name.split.first || "Değerli Müşterimiz"
    sentiment = analyze_sentiment(ticket)

    greeting = "Merhaba #{customer_first_name},"
    empathy = case sentiment[:tone]
              when :urgent_negative
                "Yaşadığınız aksaklık ve gecikme nedeniyle çok üzgünüz. Konunun sizin için aciliyetinin farkındayız ve öncelikli olarak ele alıyoruz."
              when :positive
                "Geri bildiriminiz ve bizimle iletişime geçtiğiniz için teşekkür ederiz."
              else
                "Bizimle iletişime geçtiğiniz için teşekkür ederiz."
              end

    core_response = case ticket.category
                    when "Fatura & Ödeme"
                      "Belirttiğiniz fatura ve ödeme hareketleri muhasebe sistemimizde incelenmiştir. e-Fatura durumunuz GİB yasal takvimine uygun olarak kontrol edilmiş olup gerekli düzeltmeler işleme alınmıştır."
                    when "Teknik Sorun"
                      "İlettiğiniz teknik aksaklık geliştirici ve sistem ekibimize aktarılmıştır. İlgili servis logları taranmakta olup çözüm adımları en kısa sürede bu talep üzerinden paylaşılacaktır."
                    when "Hesap & Yetki"
                      "Kullanıcı hesabı ve erişim yetkileriniz güvenlik protokollerimiz çerçevesinde kontrol edilmiştir. Şifre sıfırlama veya rol güncellemeniz tamamlanmıştır."
                    else
                      "İlettiğiniz konuyla ilgili incelemelerimiz devam etmektedir. En kısa sürede detaylı bilgi verilecektir."
                    end

    signoff = "Herhangi bir ek sorunuz olursa lütfen bu mesaja yanıt vermekten çekinmeyiniz.\n\nİyi çalışmalar dileriz,\nPulseDesk Destek Ekibi"

    "#{greeting}\n\n#{empathy}\n\n#{core_response}\n\n#{signoff}"
  end

  # Müşteri mesajından duygu durumu ve aciliyet tespiti
  def self.analyze_sentiment(ticket)
    text = "#{ticket.subject} #{ticket.description}".downcase

    negative_words = %w[acil rezalet çalışmıyor bozuk berbat çöktü mağdur şikayet hata iptal dolandırıcı]
    positive_words = %w[teşekkür harika süper sağolun memnun mükemmel]

    neg_matches = negative_words.select { |w| text.include?(w) }
    pos_matches = positive_words.select { |w| text.include?(w) }

    if neg_matches.any?
      {
        tone: :urgent_negative,
        label: "⚠️ Acil / Memnuniyetsiz",
        detected_keywords: neg_matches,
        recommendation: "Müşteriye öncelikli ve yapıcı bir dille ivedi dönüş yapılmalıdır."
      }
    elsif pos_matches.any?
      {
        tone: :positive,
        label: "😊 Olumlu / Teşekkür",
        detected_keywords: pos_matches,
        recommendation: "Nezaketle teşekkür edilip bilet çözüme kavuşturulabilir."
      }
    else
      {
        tone: :neutral,
        label: "ℹ️ Standart Talep",
        detected_keywords: [],
        recommendation: "Standart SLA süresi içerisinde rutin yanıt verilebilir."
      }
    end
  end

  private

  def self.local_nlp_summary(ticket)
    sentiment = analyze_sentiment(ticket)
    comment_count = ticket.ticket_comments.count
    last_comment = ticket.ticket_comments.last&.body&.truncate(80)

    summary = "📌 [ÖZET]: Müşteri #{ticket.customer_name}, '#{ticket.category}' kategorisinde bir talep açtı.\n"
    summary += "• Temel Konu: #{ticket.subject}\n"
    summary += "• Tespit Edilen Duygu: #{sentiment[:label]}\n"
    summary += "• Toplam Etkileşim: #{comment_count} yanıt/not mevcut.\n"
    summary += "• Son Durum: #{last_comment ? "Son yanıt: \"#{last_comment}\"" : "Henüz ilk yanıt bekleniyor."}\n"
    summary += "• Tavsiye: #{sentiment[:recommendation]}"
    summary
  end

  def self.call_openai_summary(ticket)
    # Canlı OpenAI çağrısı (API Key varsa)
    uri = URI("https://api.openai.com/v1/chat/completions")
    req = Net::HTTP::Post.new(uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{ENV['OPENAI_API_KEY']}"
    })
    req.body = {
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "Sen bir müşteri destek uzmanısın. Destek biletini 3 kısa maddede özetle." },
        { role: "user", content: "Konu: #{ticket.subject}\nAçıklama: #{ticket.description}" }
      ],
      max_tokens: 150
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      data.dig("choices", 0, "message", "content")
    else
      local_nlp_summary(ticket)
    end
  rescue StandardError
    local_nlp_summary(ticket)
  end

  def self.call_gemini_summary(ticket)
    # Gemini API çağrısı
    local_nlp_summary(ticket)
  end
end

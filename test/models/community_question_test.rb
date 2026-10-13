require "test_helper"

class CommunityQuestionTest < ActiveSupport::TestCase
  setup do
    @question = CommunityQuestion.create!(
      title: "API rate limit hatası alıyorum, limitler nedir?",
      body: "v1 endpointlerini çağırırken 429 hatası alıyorum. Limitler ve sıfırlanma süresi nerede yazıyor?",
      author_name: "Can Demir",
      author_email: "can@example.com",
      category: "Entegrasyon"
    )
  end

  test "topluluk sorusu başarıyla oluşturulur ve başlangıçta bilete dönüştürülmemiştir" do
    assert @question.persisted?
    assert_equal 0, @question.answers_count
    assert_equal false, @question.converted_to_ticket
    assert_nil @question.converted_at
    assert_nil @question.ticket_id
  end

  test "24 saat dolmadan yanıtsız soru destek talebine dönüştürülmez (travel_to)" do
    travel_to @question.created_at + 23.hours + 50.minutes do
      assert_not @question.eligible_for_conversion?, "24 saat dolmadan uygun sayılmamalı"
      converted = CommunityQuestion.auto_convert_unanswered!
      assert_empty converted, "24 saat dolmadan hiçbir soru dönüştürülmemeli"

      @question.reload
      assert_equal false, @question.converted_to_ticket
      assert_nil @question.ticket_id
    end
  end

  test "24 saat dolunca yanıtsız soru otomatik olarak destek talebine dönüştürülür (travel_to)" do
    travel_to @question.created_at + 24.hours + 2.minutes do
      assert @question.eligible_for_conversion?, "24 saat dolunca dönüştürülmeye uygun olmalı"

      converted_tickets = CommunityQuestion.auto_convert_unanswered!
      assert_equal 1, converted_tickets.size, "1 adet bilet üretilmeli"

      ticket = converted_tickets.first
      @question.reload

      assert_equal true, @question.converted_to_ticket, "Sorunun dönüştürüldü bayrağı true olmalı"
      assert_not_nil @question.converted_at, "Dönüştürme zamanı kaydedilmeli"
      assert_equal ticket.id, @question.ticket_id, "Kaynak soru yeni taleple ilişkilendirilmeli"

      # Bilet alanları doğrulaması
      assert_equal @question.id, ticket.community_question_id, "Talep kaynak soruyla ilişkilendirilmeli"
      assert_includes ticket.subject, @question.title
      assert_includes ticket.description, @question.body
      assert_equal @question.author_name, ticket.customer_name
      assert_equal @question.author_email, ticket.customer_email
      assert_equal "high", ticket.priority
      assert_equal "new", ticket.status
    end
  end

  test "aynı soru ikinci kez dönüştürülmez (idempotent / çift kayıt engeli)" do
    travel_to @question.created_at + 25.hours do
      first_run = CommunityQuestion.auto_convert_unanswered!
      assert_equal 1, first_run.size

      # İkinci kez çalıştırıldığında tekrar dönüştürülmemeli
      second_run = CommunityQuestion.auto_convert_unanswered!
      assert_empty second_run, "Aynı soru ikinci kez dönüştürülmemeli"

      assert_equal 1, Ticket.where(community_question_id: @question.id).count, "Veritabanında yalnızca tek bir bilet olmalı"
    end
  end

  test "cevap verilmiş olan soru 24 saat geçse bile otomatik dönüştürülmez" do
    # Toplulukta yanıt eklendi
    @question.community_answers.create!(
      author_name: "Topluluk Lideri",
      body: "Limitler saatlik 1000 istektir, belgelerden inceleyebilirsiniz."
    )
    assert_equal 1, @question.reload.answers_count

    travel_to @question.created_at + 48.hours do
      assert_not @question.eligible_for_conversion?, "Cevaplanan soru dönüştürülmemeli"
      converted = CommunityQuestion.auto_convert_unanswered!
      assert_empty converted
      assert_equal false, @question.reload.converted_to_ticket
    end
  end

  test "kabul edilen çözüm olarak işaretleme soruyu çözüldü yapar ve diğer çözümleri kaldırır" do
    ans1 = @question.community_answers.create!(author_name: "Ali", body: "İlk çözüm önerisi")
    ans2 = @question.community_answers.create!(author_name: "Ayşe", body: "Doğru ve net çözüm önerisi")

    assert_equal false, @question.solved?
    assert_equal false, ans1.is_solution?
    assert_equal false, ans2.is_solution?

    ans2.mark_as_solution!

    assert_equal true, ans2.reload.is_solution?
    assert_equal false, ans1.reload.is_solution?
    assert_equal true, @question.reload.solved?
  end

  test "faydalı buldum upvote yanıt sayacını artırır" do
    ans = @question.community_answers.create!(author_name: "Ali", body: "Harika yanıt")
    assert_equal 0, ans.upvotes_count

    ans.upvote!
    assert_equal 1, ans.reload.upvotes_count

    ans.upvote!
    assert_equal 2, ans.reload.upvotes_count
  end
end


require "test_helper"

class CommunityQuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @question = CommunityQuestion.create!(
      title: "Webhook yeniden deneme politikası nedir?",
      body: "Endpoint 500 dönerse kaç kez ve hangi aralıklarla retry yapılıyor?",
      author_name: "Barış Koç",
      author_email: "baris@example.com",
      category: "Entegrasyon"
    )
  end

  test "topluluk soruları listesi açılır" do
    get community_questions_url
    assert_response :success
    assert_select "h1", "Topluluk Forumu Soruları"
  end

  test "topluluk sorusu detayı açılır" do
    get community_question_url(@question)
    assert_response :success
    assert_select "h1", @question.title
  end

  test "yeni soru oluşturma formu açılır" do
    get new_community_question_url
    assert_response :success
  end

  test "yeni topluluk sorusu oluşturulur" do
    assert_difference("CommunityQuestion.count", 1) do
      post community_questions_url, params: {
        community_question: {
          title: "Mobil SDK Swift desteği var mı?",
          body: "iOS uygulamamıza PulseDesk SDK eklemek istiyoruz.",
          author_name: "Derya Aydın",
          author_email: "derya@mobile.app",
          category: "Genel"
        }
      }
    end

    new_q = CommunityQuestion.last
    assert_redirected_to community_question_url(new_q)
  end

  test "soruya topluluk yanıtı eklenebilir" do
    assert_difference("@question.community_answers.count", 1) do
      post community_question_community_answers_url(@question), params: {
        community_answer: {
          author_name: "Gönüllü Uzman",
          body: "Webhooks 5 kez exponential backoff ile tekrar denenmektedir."
        }
      }
    end

    assert_redirected_to community_question_url(@question)
    assert_equal 1, @question.reload.answers_count
  end

  test "soru butonla manuel olarak destek talebine dönüştürülebilir" do
    assert_difference("Ticket.count", 1) do
      post convert_to_ticket_community_question_url(@question)
    end

    ticket = Ticket.last
    assert_redirected_to ticket_url(ticket)
    assert_equal true, @question.reload.converted_to_ticket
    assert_equal ticket.id, @question.ticket_id
  end

  test "24 saat otomatik dönüşüm tetikleyici endpoint çalışır" do
    # 26 saat önce oluşturulmuş yanıtsız bir soru
    old_q = CommunityQuestion.create!(
      title: "Cevapsız kalan eski soru",
      body: "Kimse yanıt vermedi.",
      author_name: "Eski Kullanıcı",
      author_email: "eski@user.com",
      category: "Genel",
      created_at: 26.hours.ago,
      answers_count: 0
    )

    assert_difference("Ticket.count", 1) do
      post trigger_auto_convert_community_questions_url
    end

    assert_redirected_to community_questions_url
    assert_equal true, old_q.reload.converted_to_ticket
  end
end

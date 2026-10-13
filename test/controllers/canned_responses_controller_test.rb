require "test_helper"

class CannedResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @canned = CannedResponse.create!(
      title: "GİB İtiraz Şablonu",
      content: "Sayın mükellef, 7 günlük yasal süre içerisinde...",
      category: "Fatura & Ödeme"
    )
  end

  test "destek çalışanı hazır yanıtlar listesini görebilir" do
    post switch_role_url, params: { role: "agent" }

    get canned_responses_url
    assert_response :success
    assert_select "h1", /Hazır Yanıtlar/
    assert_includes response.body, "GİB İtiraz Şablonu"
  end

  test "yeni hazır yanıt oluşturma formu açılır ve kaydedilir" do
    post switch_role_url, params: { role: "agent" }

    get new_canned_response_url
    assert_response :success

    assert_difference("CannedResponse.count", 1) do
      post canned_responses_url, params: {
        canned_response: {
          title: "Parola Sıfırlama Şablonu",
          content: "Güvenliğiniz için lütfen parolanızı sıfırlayınız.",
          category: "Hesap & Güvenlik"
        }
      }
    end

    assert_redirected_to canned_responses_url
  end

  test "hazır yanıt düzenlenebilir ve silinebilir" do
    post switch_role_url, params: { role: "agent" }

    get edit_canned_response_url(@canned)
    assert_response :success

    patch canned_response_url(@canned), params: {
      canned_response: { title: "Güncellenmiş Başlık" }
    }
    assert_redirected_to canned_responses_url
    assert_equal "Güncellenmiş Başlık", @canned.reload.title

    assert_difference("CannedResponse.count", -1) do
      delete canned_response_url(@canned)
    end
    assert_redirected_to canned_responses_url
  end

  test "müşteri rolü hazır yanıtları yönetemez" do
    post switch_role_url, params: { role: "customer" }

    get canned_responses_url
    assert_redirected_to root_url
  end
end

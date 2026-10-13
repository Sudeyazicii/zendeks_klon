require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "profil sayfası başarıyla açılır" do
    get profile_url
    assert_response :success
    assert_select "h1", /Profil & Bildirim Ayarları/
  end

  test "bildirim tercihleri ve departman güncellenebilir" do
    patch update_preferences_url, params: {
      user: {
        name: "Ahmet Test",
        department: "Fatura & Muhasebe",
        email_notifications_enabled: "1"
      }
    }

    assert_redirected_to profile_url
    follow_redirect!
    assert_includes response.body, "başarıyla güncellendi"
  end
end

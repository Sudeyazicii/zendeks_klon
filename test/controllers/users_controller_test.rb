require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.find_or_create_by!(email: "admin@pulsedesk.io") do |u|
      u.name     = "Ali Yönetici"
      u.password = "password123"
      u.role     = "admin"
      u.department = "Yönetim"
    end

    @agent = User.find_or_create_by!(email: "mert@pulsedesk.io") do |u|
      u.name     = "Mert Demir"
      u.password = "password123"
      u.role     = "agent"
      u.department = "Destek Ekibi"
    end

    @customer = User.find_or_create_by!(email: "ahmet@example.com") do |u|
      u.name     = "Ahmet Yılmaz (Müşteri)"
      u.password = "password123"
      u.role     = "customer"
      u.department = "Müşteri"
    end
  end

  # ---- Login / Logout ----

  test "login sayfası başarıyla açılır" do
    get login_url
    assert_response :success
    assert_includes response.body, "Giriş Yap"
  end

  test "doğru kimlik bilgileriyle giriş yapılır ve session oluşur" do
    post login_url, params: { email: "mert@pulsedesk.io", password: "password123" }
    assert_redirected_to root_url
    assert_equal @agent.id, session[:user_id]
    assert session[:real_login]
  end

  test "yanlış parola ile giriş reddedilir" do
    post login_url, params: { email: "mert@pulsedesk.io", password: "yanlis_sifre" }
    assert_response :unprocessable_entity
    assert_includes response.body, "E-posta veya parola hatalı"
  end

  test "çıkış yapılınca session temizlenir ve login sayfasına yönlendirilir" do
    post login_url, params: { email: "mert@pulsedesk.io", password: "password123" }
    delete logout_url
    assert_redirected_to login_url
    assert_nil session[:user_id]
    assert_nil session[:real_login]
  end

  # ---- Admin: Kullanıcı Listesi ----

  test "admin kullanıcı listesini görüntüleyebilir" do
    post switch_role_url, params: { role: "admin" }
    get admin_users_url
    assert_response :success
    assert_includes response.body, "Kullanıcı Yönetimi"
  end

  test "agent kullanıcı listesine erişemez (sadece admin)" do
    post switch_role_url, params: { role: "agent" }
    get admin_users_url
    assert_redirected_to root_url
  end

  test "admin başka kullanıcının rolünü değiştirebilir" do
    post switch_role_url, params: { role: "admin" }
    patch admin_update_user_role_url(@customer), params: { role: "agent" }
    assert_redirected_to admin_users_url
    assert_equal "agent", @customer.reload.role
  end

  # ---- Profil ----

  test "profil sayfası açılır" do
    get profile_url
    assert_response :success
  end

  test "profil güncelleme kaydedilir" do
    patch update_preferences_url, params: {
      user: { name: "Yeni Ad", department: "Destek Ekibi", email_notifications_enabled: "1" }
    }
    assert_redirected_to profile_url
  end
end

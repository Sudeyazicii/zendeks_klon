require "test_helper"

class SentEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @email = SentEmail.create!(
      to_email: "musteri@example.com",
      subject: "Talebiniz Alındı",
      body: "Sayın müşterimiz talebiniz işleme alınmıştır.",
      mail_type: "ticket_created",
      status: "delivered"
    )
  end

  test "giden e-postalar listesi başarıyla açılır" do
    get sent_emails_path
    assert_response :success
    assert_select "h1", /Giden E-posta Kutusu/
    assert_includes response.body, "musteri@example.com"
  end

  test "giden e-posta detay sayfası açılır" do
    get sent_email_path(@email)
    assert_response :success
    assert_includes response.body, "Talebiniz Alındı"
    assert_includes response.body, "Sayın müşterimiz talebiniz işleme alınmıştır."
  end
end

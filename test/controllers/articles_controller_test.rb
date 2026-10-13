require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @article = Article.create!(
      title: "GİB e-Fatura İtiraz ve İptal Kılavuzu",
      body: "7 günlük yasal süre içinde GİB portalı üzerinden itiraz dilekçesi verilebilir.",
      category: "Fatura & Ödeme",
      published: true
    )
  end

  test "makaleler listesi herkese açıktır" do
    get articles_url
    assert_response :success
    assert_select "h1", "Bilgi Bankası (Knowledge Base)"
  end

  test "makale detayı görüntülenir ve sayaç artar" do
    initial_views = @article.views_count
    get article_url(@article)
    assert_response :success
    assert_select "h1", @article.title
    assert_equal initial_views + 1, @article.reload.views_count
  end

  test "destek çalışanı yeni makale oluşturabilir" do
    post switch_role_url, params: { role: "agent" }

    assert_difference("Article.count", 1) do
      post articles_url, params: {
        article: {
          title: "Webhook İmza Doğrulama Rehberi",
          body: "HMAC SHA256 ile imza doğrulaması yapılır.",
          category: "Entegrasyon & API",
          published: true
        }
      }
    end

    assert_redirected_to article_url(Article.last)
  end

  test "müşteri makale oluşturamaz" do
    post switch_role_url, params: { role: "customer" }

    assert_no_difference("Article.count") do
      post articles_url, params: {
        article: {
          title: "Yetkisiz Makale",
          body: "Bu makale kaydedilmemeli",
          category: "Genel"
        }
      }
    end

    assert_redirected_to root_url
  end
end

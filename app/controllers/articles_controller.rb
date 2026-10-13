class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  before_action :require_agent!, only: [:new, :create, :edit, :update, :destroy]

  def index
    @category = params[:category]
    @articles = Article.recent_first

    if @category.present?
      @articles = @articles.where(category: @category)
    end

    if params[:query].present?
      @articles = Article.search_relevant(params[:query])
    end

    @categories = Article.distinct.pluck(:category)
  end

  def show
    @article.increment!(:views_count)
  end

  def new
    @article = Article.new(published: true, category: "Genel")
  end

  def create
    @article = Article.new(article_params)

    if @article.save
      redirect_to @article, notice: "Bilgi bankası makalesi başarıyla yayınlandı."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Makale başarıyla güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    redirect_to articles_path, notice: "Makale silindi."
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body, :category, :published)
  end
end

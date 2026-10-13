class CannedResponsesController < ApplicationController
  before_action :require_agent!
  before_action :set_canned_response, only: [:edit, :update, :destroy]

  def index
    @canned_responses = CannedResponse.recent_first
  end

  def new
    @canned_response = CannedResponse.new(category: "Genel")
  end

  def create
    @canned_response = CannedResponse.new(canned_response_params)
    @canned_response.created_by = current_user

    if @canned_response.save
      redirect_to canned_responses_path, notice: "'#{@canned_response.title}' hazır yanıtı başarıyla oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @canned_response.update(canned_response_params)
      redirect_to canned_responses_path, notice: "'#{@canned_response.title}' hazır yanıtı güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @canned_response.title
    @canned_response.destroy!
    redirect_to canned_responses_path, notice: "'#{title}' hazır yanıtı silindi."
  end

  private

  def set_canned_response
    @canned_response = CannedResponse.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:title, :content, :category)
  end
end

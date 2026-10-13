class CommunityAnswersController < ApplicationController
  before_action :set_question

  def create
    @answer = @question.community_answers.build(answer_params)

    if @answer.save
      redirect_to @question, notice: "Yanıtınız başarıyla eklendi."
    else
      redirect_to @question, alert: "Yanıt eklenemedi: #{@answer.errors.full_messages.join(', ')}"
    end
  end

  def mark_solution
    @answer = @question.community_answers.find(params[:id])
    @answer.mark_as_solution!
    redirect_to @question, notice: "Bu yanıt 'Kabul Edilen Çözüm' olarak işaretlendi."
  end

  def upvote
    @answer = @question.community_answers.find(params[:id])
    @answer.upvote!
    redirect_to @question, notice: "Yanıt faydalı bulundu (+1 oy)."
  end

  private

  def set_question
    @question = CommunityQuestion.find(params[:community_question_id])
  end

  def answer_params
    params.require(:community_answer).permit(:author_name, :body)
  end
end

class CommunityAnswersController < ApplicationController
  def create
    @question = CommunityQuestion.find(params[:community_question_id])
    @answer = @question.community_answers.build(answer_params)

    if @answer.save
      redirect_to @question, notice: "Yanıtınız başarıyla eklendi."
    else
      redirect_to @question, alert: "Yanıt eklenemedi: #{@answer.errors.full_messages.join(', ')}"
    end
  end

  private

  def answer_params
    params.require(:community_answer).permit(:author_name, :body)
  end
end

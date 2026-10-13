class CommunityQuestionsController < ApplicationController
  before_action :set_question, only: [:show, :convert_to_ticket]

  def index
    @filter = params[:filter]
    @questions = CommunityQuestion.recent_first

    case @filter
    when "unanswered"
      @questions = @questions.unanswered
    when "answered"
      @questions = @questions.where("answers_count > 0")
    when "converted"
      @questions = @questions.where(converted_to_ticket: true)
    end

    if params[:query].present?
      q = "%#{params[:query]}%"
      @questions = @questions.where("title LIKE ? OR body LIKE ? OR author_name LIKE ?", q, q, q)
    end

    @total_count      = CommunityQuestion.count
    @unanswered_count = CommunityQuestion.unanswered.count
    @converted_count  = CommunityQuestion.where(converted_to_ticket: true).count
    @eligible_count   = CommunityQuestion.eligible_for_auto_conversion.count

    # Son çalıştırma bilgileri (Denetim günlüğünden)
    @last_log = AutomationAuditLog.where(rule_name: "24 Saat Cevapsız Forum Sorularını Destek Talebine Dönüştür").recent_first.first
    @last_converted_count = @last_log&.records_modified || 0
    @last_run_at = @last_log&.created_at
    @last_status = @last_log&.status
  end

  def show
    @answers = @question.community_answers
    @new_answer = CommunityAnswer.new
  end

  def new
    @question = CommunityQuestion.new
  end

  def create
    @question = CommunityQuestion.new(question_params)

    if @question.save
      redirect_to @question, notice: "Topluluk sorunuz başarıyla yayınlandı."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def convert_to_ticket
    if @question.converted_to_ticket?
      redirect_to @question.ticket, alert: "Bu soru zaten ##{@question.ticket.ticket_number} numaralı destek talebine dönüştürülmüştür."
    else
      ticket = @question.convert_to_ticket!(reason: "manual")
      redirect_to ticket, notice: "Soru başarıyla ##{ticket.ticket_number} numaralı destek talebine dönüştürüldü."
    end
  end

  def trigger_auto_convert
    converted = CommunityQuestion.auto_convert_unanswered!(executed_by: "#{current_user.name} (Manuel Çalıştırma)")

    if converted.any?
      redirect_to community_questions_path, notice: "#{converted.size} adet 24 saattir cevapsız soru başarıyla destek talebine dönüştürüldü."
    else
      redirect_to community_questions_path, notice: "Şu anda 24 saat kuralına uyan dönüştürülecek cevapsız soru bulunamadı (Tüm sorular yanıtlanmış veya 24 saatten genç)."
    end
  end

  private

  def set_question
    @question = CommunityQuestion.find(params[:id])
  end

  def question_params
    params.require(:community_question).permit(:title, :body, :author_name, :author_email, :category)
  end
end

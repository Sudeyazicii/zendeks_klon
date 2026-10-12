class CommunityQuestionAutoConvertJob < ApplicationJob
  queue_as :default

  def perform
    converted = CommunityQuestion.auto_convert_unanswered!
    Rails.logger.info "[PulseDesk AutoConvert] #{converted.size} adet cevapsız topluluk sorusu destek talebine dönüştürüldü."
    converted
  end
end

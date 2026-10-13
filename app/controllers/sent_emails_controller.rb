class SentEmailsController < ApplicationController
  def index
    @sent_emails = SentEmail.recent.limit(50)
  end

  def show
    @sent_email = SentEmail.find(params[:id])
  end
end

class UsersController < ApplicationController
  def profile
    @user = current_user
  end

  def update_preferences
    @user = current_user
    
    enabled = params[:user][:email_notifications_enabled] == "1"
    dept = params[:user][:department].presence || @user.department
    name = params[:user][:name].presence || @user.name

    if @user.update(email_notifications_enabled: enabled, department: dept, name: name)
      redirect_to profile_path, notice: "Profil ve bildirim tercihleriniz başarıyla güncellendi."
    else
      render :profile, status: :unprocessable_entity
    end
  end
end

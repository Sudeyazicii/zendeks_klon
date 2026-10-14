class UsersController < ApplicationController
  before_action :require_admin!, only: [:index, :update_role]

  # ---- Profil ----
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

  # ---- Admin: Kullanıcı Listesi ----
  def index
    @users = User.order(:role, :name)
  end

  def update_role
    @user = User.find(params[:id])
    new_role = params[:role].presence_in(User::ROLES)

    unless new_role
      redirect_to admin_users_path, alert: "Geçersiz rol seçildi."
      return
    end

    if @user.update(role: new_role)
      redirect_to admin_users_path, notice: "#{@user.name} kullanıcısının rolü '#{new_role.upcase}' olarak güncellendi."
    else
      redirect_to admin_users_path, alert: "Rol güncellenemedi: #{@user.errors.full_messages.join(', ')}"
    end
  end

  # ---- Gerçek Login / Logout ----
  def login
    redirect_to root_path if current_user.present? && session[:real_login] && !session[:logged_out]
  end

  def authenticate
    user = User.find_by(email: params[:email]&.downcase&.strip)

    if user && user.authenticate(params[:password])
      session.delete(:logged_out)
      session[:user_id]    = user.id
      session[:real_login] = true
      redirect_to root_path, notice: "Hoş geldiniz, #{user.name}! (#{user.role.upcase})"
    else
      flash.now[:alert] = "E-posta veya parola hatalı."
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session.delete(:user_id)
    session.delete(:real_login)
    session[:logged_out] = true
    redirect_to login_path, notice: "Başarıyla çıkış yaptınız."
  end
end

class ApplicationController < ActionController::Base
  # Modern browser compatibility
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :check_authentication!

  helper_method :current_user, :current_role

  def current_user
    return nil if session[:logged_out]
    @current_user ||= find_or_initialize_demo_user
  end

  def current_role
    current_user&.role || "guest"
  end

  def switch_role
    session.delete(:logged_out)
    role = params[:role].presence_in(%w[agent customer admin]) || "agent"
    user = User.find_by(role: role) || create_demo_user_for_role(role)
    session[:user_id] = user.id
    session[:real_login] = true

    if request.referer.blank? || request.referer.include?("/login")
      redirect_to root_path, notice: "Hoş geldiniz, #{user.name}! (#{role.upcase})"
    else
      redirect_back fallback_location: root_path, notice: "Aktif rol '#{role.upcase}' (#{user.name}) olarak değiştirildi."
    end
  end

  protected

  def require_agent!
    unless current_user&.staff?
      redirect_to root_path, alert: "Bu işlem için destek çalışanı veya yönetici yetkisi gereklidir."
    end
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Bu işlem yalnızca sistem yöneticisi tarafından yapılabilir."
    end
  end

  private

  def check_authentication!
    if session[:logged_out] && !public_controller_action?
      redirect_to login_path, alert: "Oturumunuz sonlandırılmıştır. Lütfen tekrar giriş yapın."
    end
  end

  def public_controller_action?
    (controller_name == "users" && action_name.in?(%w[login authenticate])) || action_name == "switch_role"
  end

  def find_or_initialize_demo_user
    return nil if session[:logged_out]

    if session[:user_id].present?
      user = User.find_by(id: session[:user_id])
      return user if user.present?
    end

    # Varsayılan olarak destek temsilcisi ata
    default_agent = User.find_by(role: "agent") || create_demo_user_for_role("agent")
    session[:user_id] = default_agent.id
    default_agent
  end

  def create_demo_user_for_role(role)
    case role
    when "admin"
      User.find_or_create_by!(email: "admin@pulsedesk.io") do |u|
        u.name = "Ali Yönetici"
        u.password = "password123"
        u.role = "admin"
        u.department = "Yönetim"
      end
    when "customer"
      User.find_or_create_by!(email: "ahmet@example.com") do |u|
        u.name = "Ahmet Yılmaz (Müşteri)"
        u.password = "password123"
        u.role = "customer"
        u.department = "Müşteri"
      end
    else
      User.find_or_create_by!(email: "mert@pulsedesk.io") do |u|
        u.name = "Mert Demir"
        u.password = "password123"
        u.role = "agent"
        u.department = "Destek Ekibi"
      end
    end
  end
end

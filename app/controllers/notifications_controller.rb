class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.recent_first
    @unread_count = current_user.unread_notifications_count
  end

  def mark_as_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!
    redirect_to notifications_path, notice: "Bildirim okundu olarak işaretlendi."
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read: true, read_at: Time.current)
    redirect_to notifications_path, notice: "Tüm bildirimler okundu olarak işaretlendi."
  end
end

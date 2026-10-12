class User < ApplicationRecord
  has_secure_password

  ROLES = %w[customer agent admin].freeze

  has_many :assigned_tickets, class_name: "Ticket", foreign_key: "assigned_to_id", dependent: :nullify
  has_many :created_tickets, class_name: "Ticket", foreign_key: "user_id", dependent: :nullify
  has_many :ticket_comments, dependent: :nullify
  has_many :notifications, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }

  scope :agents, -> { where(role: %w[agent admin]) }

  def staff?
    agent? || admin?
  end

  def agent?
    role == "agent"
  end

  def admin?
    role == "admin"
  end

  def customer?
    role == "customer"
  end

  def unread_notifications_count
    notifications.where(read: false).count
  end
end

class CannedResponse < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true

  validates :title, presence: true
  validates :content, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
end

class AutomationAuditLog < ApplicationRecord
  belongs_to :automation_rule, optional: true

  validates :rule_name, presence: true
  validates :trigger_type, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  def parsed_details
    return {} if details.blank?
    JSON.parse(details)
  rescue JSON::ParserError
    {}
  end
end

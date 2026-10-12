class Article < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true

  scope :published, -> { where(published: true) }
  scope :recent_first, -> { order(created_at: :desc) }

  def self.search_relevant(query)
    return published.none if query.blank?

    tokens = query.to_s.downcase.split(/\s+/).reject { |t| t.length < 3 }
    return published.none if tokens.empty?

    # Basit ve güvenli anahtar kelime eşleştirmesi
    sql_clauses = tokens.map { "LOWER(title) LIKE ? OR LOWER(body) LIKE ?" }.join(" OR ")
    params = tokens.flat_map { |t| ["%#{t}%", "%#{t}%"] }

    published.where(sql_clauses, *params).limit(5)
  end
end

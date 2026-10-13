class CommunityAnswer < ApplicationRecord
  belongs_to :community_question, counter_cache: :answers_count

  validates :body, presence: true
  validates :author_name, presence: true

  scope :recent_first, -> { order(created_at: :asc) }
  scope :solutions, -> { where(is_solution: true) }

  def mark_as_solution!
    transaction do
      # Bu sorudaki diğer çözümleri kaldır
      community_question.community_answers.where.not(id: id).update_all(is_solution: false)
      update!(is_solution: true)
      community_question.update!(solved: true)
    end
  end

  def upvote!
    increment!(:upvotes_count)
  end
end

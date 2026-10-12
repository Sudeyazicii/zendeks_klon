class CommunityAnswer < ApplicationRecord
  belongs_to :community_question, counter_cache: :answers_count

  validates :body, presence: true
  validates :author_name, presence: true
end

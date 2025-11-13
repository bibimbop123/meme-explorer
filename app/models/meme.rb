class Meme < ApplicationRecord
  has_many :likes, dependent: :destroy
  has_many :liked_by_users, through: :likes, source: :user

  validates :title, presence: true
  validates :image_url, presence: true

  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :trending, -> { order(view_count: :desc, created_at: :desc).limit(20) }
  scope :random, -> { order("RANDOM()").limit(1) }

  def increment_views
    update(view_count: (view_count || 0) + 1)
  end
end

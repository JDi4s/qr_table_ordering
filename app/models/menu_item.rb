class MenuItem < ApplicationRecord
  belongs_to :category
  has_one :establishment, through: :category
  has_one_attached :image
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  has_many :recommendations, class_name: 'MenuItemRecommendation', dependent: :destroy
  has_many :recommended_menu_items, through: :recommendations
  has_many :recommended_by, class_name: 'MenuItemRecommendation',
           foreign_key: :recommended_menu_item_id, dependent: :destroy
  has_many :recommended_by_menu_items, through: :recommended_by, source: :menu_item

  scope :not_archived, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end
  attribute :available, :boolean, default: true
  validate { errors.add(:price, 'deve ter no máximo duas casas decimais') if price && price != price.round(2) }
  validates :name, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
end

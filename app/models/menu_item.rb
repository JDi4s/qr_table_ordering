class MenuItem < ApplicationRecord
  belongs_to :category
  has_one :establishment, through: :category
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  attribute :available, :boolean, default: true
  validate { errors.add(:price, 'deve ter no máximo duas casas decimais') if price && price != price.round(2) }
  validates :name, presence: true, length: { maximum: 150 }
  validates :price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
end

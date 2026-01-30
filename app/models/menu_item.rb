class MenuItem < ApplicationRecord
  belongs_to :category
  has_many :order_items
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :available, -> { where(available: true) }
end

class Category < ApplicationRecord
  has_many :menu_items, dependent: :destroy

  validates :name, presence: true

  scope :available, -> { where(available: true) }
end

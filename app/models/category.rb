class Category < ApplicationRecord
  belongs_to :establishment
  has_many :menu_items, dependent: :restrict_with_error
  attribute :available, :boolean, default: true
  validates :name, presence: true, length: { maximum: 120 }
end

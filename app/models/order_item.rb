class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item
  enum status: { pending: 'pending', accepted: 'accepted', denied: 'denied' }
  before_validation do
    self.name_snapshot ||= menu_item&.name
    self.original_unit_price ||= unit_price
  end
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
  validates :denial_reason, presence: true, if: :denied?
  validates :denial_reason, :proposed_description, length: { maximum: 300 }
  validate :same_establishment

  def display_name
    name_snapshot.presence || menu_item.name
  end

  private

  def same_establishment
    if order&.table && menu_item && order.table.establishment_id != menu_item.category.establishment_id
      errors.add(:menu_item, 'não pertence a este estabelecimento')
    end
  end
end

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item, optional: true
  enum status: { pending: 'pending', accepted: 'accepted', denied: 'denied' }
  attribute :paid_quantity, :integer, default: 0
  before_validation do
    self.name_snapshot ||= menu_item&.name
    self.original_unit_price ||= unit_price
  end
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 99 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, less_than: 100000 }
  validates :paid_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :denial_reason, presence: true, if: :denied?
  validates :denial_reason, :proposed_description, length: { maximum: 300 }
  validate :paid_quantity_cannot_exceed_quantity
  validate :same_establishment

  def display_name
    name_snapshot.presence || menu_item&.name || 'Produto eliminado'
  end

  def remaining_quantity
    [quantity.to_i - paid_quantity.to_i, 0].max
  end

  def paid?
    !denied? && remaining_quantity.zero?
  end

  def unpaid?
    !denied? && remaining_quantity.positive?
  end

  def outstanding_total
    unit_price.to_d * remaining_quantity
  end

  private

  def paid_quantity_cannot_exceed_quantity
    return unless quantity && paid_quantity && paid_quantity > quantity

    errors.add(:paid_quantity, 'não pode ser superior à quantidade pedida')
  end

  def same_establishment
    if order&.table && menu_item && order.table.establishment_id != menu_item.category.establishment_id
      errors.add(:menu_item, 'não pertence a este estabelecimento')
    end
  end
end

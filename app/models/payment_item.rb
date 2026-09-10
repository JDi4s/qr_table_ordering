class PaymentItem < ApplicationRecord
  belongs_to :payment
  belongs_to :order_item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, :amount, numericality: { greater_than_or_equal_to: 0 }
end

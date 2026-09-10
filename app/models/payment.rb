class Payment < ApplicationRecord
  belongs_to :order
  belongs_to :user
  has_many :payment_items, dependent: :destroy

  enum payment_method: { cash: 'cash', card: 'card', mbway: 'mbway', other: 'other' }
  validates :amount, numericality: { greater_than: 0 }
  validates :paid_at, presence: true
  validates :payment_method, inclusion: { in: payment_methods.keys }
end

class CashClosure < ApplicationRecord
  belongs_to :establishment
  belongs_to :user

  validates :business_date, presence: true, uniqueness: { scope: :establishment_id }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
end

class Establishment < ApplicationRecord
  has_many :tables, dependent: :restrict_with_error
  has_many :categories, dependent: :restrict_with_error
  has_many :menu_items, through: :categories
  has_many :users, dependent: :restrict_with_error
  has_many :orders, through: :tables
  has_many :service_calls, through: :tables
  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :table_limit, :monthly_fee_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :limit_covers_active_tables

  def monthly_fee
    monthly_fee_cents.to_d / 100
  end

  def monthly_fee=(value)
    self.monthly_fee_cents = BigDecimal(value.to_s.tr(',', '.')) * 100
  rescue ArgumentError
    self.monthly_fee_cents = nil
  end

  def staff_stream
    "establishment_#{id}_staff"
  end

  private

  def limit_covers_active_tables
    if persisted? && table_limit && table_limit < tables.where(active: true).count
      errors.add(:table_limit, 'não pode ser inferior ao número de mesas ativas')
    end
  end
end

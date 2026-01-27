class Order < ApplicationRecord
  belongs_to :table
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  accepts_nested_attributes_for :order_items

  enum status: { pending: "pending", accepted: "accepted", denied: "denied" }

  before_create :set_default_status

  # Scopes for convenience
  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :denied, -> { where(status: "denied") }

  private

  def set_default_status
    self.status ||= "pending"
  end
end

class Order < ApplicationRecord
  belongs_to :table
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  before_create :set_default_status

  private

  def set_default_status
    self.status ||= "pending"
  end
end

class MenuItem < ApplicationRecord
  belongs_to :category
  has_many :order_items
  has_many :orders, through: :order_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  after_create_commit  :broadcast_menu!
  after_update_commit  :broadcast_menu!
  after_destroy_commit :broadcast_menu!

  private

  def broadcast_menu!
    Turbo::StreamsChannel.broadcast_update_to(
      "menu",
      target: "customer_menu",
      partial: "orders/menu",
      locals: { categories: Category.includes(:menu_items).order(:name) }
    )
  end
end

class Category < ApplicationRecord
  has_many :menu_items, dependent: :destroy
  validates :name, presence: true

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

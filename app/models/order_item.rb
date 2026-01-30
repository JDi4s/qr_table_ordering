class OrderItem < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :order
  belongs_to :menu_item

  enum status: { pending: "pending", accepted: "accepted", denied: "denied" }

  validates :quantity, numericality: { greater_than: 0 }

  after_create_commit :broadcast_parent
  after_update_commit :broadcast_parent
  after_destroy_commit :broadcast_parent

  private

  def broadcast_parent
    # recalcula total do pedido (unit_price/quantity)
    order.recalculate_total! if order.respond_to?(:recalculate_total!)

    # ✅ Cliente: atualiza o "My Orders" card (sem refresh)
    order.broadcast_replace_to(
      "table_#{order.table_id}_orders",
      target: dom_id(order),
      partial: "orders/my_order_card",
      locals: { order: order }
    )

    # ✅ Staff: atualiza a row do pedido na Live Queue (sem refresh)
    order.broadcast_replace_to(
      "staff_orders",
      target: dom_id(order),
      partial: "staff/orders/order_row",
      locals: { order: order }
    )
  end
end

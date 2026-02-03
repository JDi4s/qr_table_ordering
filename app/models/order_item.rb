class OrderItem < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :order
  belongs_to :menu_item

  enum status: { pending: "pending", accepted: "accepted", denied: "denied" }

  validates :quantity, numericality: { greater_than: 0 }

  after_create_commit :broadcast_parent
  after_update_commit :broadcast_parent

  private

  def broadcast_parent
    order.recalculate_total! if order.respond_to?(:recalculate_total!)

    # IMPORTANT: manter o status do order consistente com os items
    order.sync_status_from_items! if order.respond_to?(:sync_status_from_items!)

    # customer card
    order.broadcast_replace_to(
      "table_#{order.table_id}_orders",
      target: dom_id(order),
      partial: "orders/my_order_card",
      locals: { order: order }
    )

    # staff row
    order.broadcast_replace_to(
      "staff_orders",
      target: dom_id(order),
      partial: "staff/orders/order_row",
      locals: { order: order }
    )
  end
end

class Order < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :table
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  enum status: {
    pending: "pending",
    accepted: "accepted",
    served: "served",
    denied: "denied"
  }

  before_validation :set_default_status, on: :create

  after_create_commit :broadcast_new_order
  after_update_commit :broadcast_order_change

  def recalculate_total!
    new_total = order_items.where.not(status: "denied").sum("quantity * unit_price")
    update_column(:total, new_total) if respond_to?(:total)
  end

  private

  def set_default_status
    self.status ||= "pending"
  end

  def broadcast_new_order
    recalculate_total!

    broadcast_append_to(
      "staff_orders",
      target: "pending_orders",
      partial: "staff/orders/order_row",
      locals: { order: self }
    )

    broadcast_append_to(
      "table_#{table_id}_orders",
      target: "my_orders_list",
      partial: "orders/my_order_card",
      locals: { order: self }
    )
  end

  def broadcast_order_change
    # Staff queue: pending stays, others disappear
    if pending?
      broadcast_replace_to(
        "staff_orders",
        target: dom_id(self),
        partial: "staff/orders/order_row",
        locals: { order: self }
      )
    else
      broadcast_remove_to("staff_orders", target: dom_id(self))
    end

    # Customer active orders: served/denied disappear
    if served? || denied?
      broadcast_remove_to("table_#{table_id}_orders", target: dom_id(self))
    else
      broadcast_replace_to(
        "table_#{table_id}_orders",
        target: dom_id(self),
        partial: "orders/my_order_card",
        locals: { order: self }
      )
    end
  end
end

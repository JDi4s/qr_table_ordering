class Order < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :table
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  enum status: {
    pending: "pending",
    accepted: "accepted",
    needs_customer_action: "needs_customer_action",
    denied: "denied",
    served: "served"
  }

  before_validation :set_default_status, on: :create

  after_create_commit :broadcast_customer
  after_update_commit :broadcast_customer
  after_create_commit :broadcast_staff
  after_update_commit :broadcast_staff

  def set_default_status
    self.status ||= "pending"
  end

  def recalculate_total!
    update!(total: order_items.sum("unit_price * quantity"))
  end

  # Decide status from items
  def sync_status_from_items!
    if order_items.any?(&:denied?)
      update!(status: "needs_customer_action")
      return
    end

    if order_items.all?(&:accepted?)
      update!(status: "accepted")
      return
    end

    update!(status: "pending")
  end

  private

  # Customer: updates "My Orders" live
  def broadcast_customer
    stream = "table_#{table_id}_orders"

    if served? || denied?
      broadcast_remove_to(stream, target: dom_id(self))
    else
      broadcast_replace_to(
        stream,
        target: dom_id(self),
        partial: "orders/my_order_card",
        locals: { order: self }
      )
    end
  end

  # Staff: updates Live Queue + removes when served/denied
  def broadcast_staff
    if served? || denied?
      broadcast_remove_to("staff_orders", target: dom_id(self))
    else
      broadcast_replace_to(
        "staff_orders",
        target: dom_id(self),
        partial: "staff/orders/order_row",
        locals: { order: self }
      )
    end
  end
end

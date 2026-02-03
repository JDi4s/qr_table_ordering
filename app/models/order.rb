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

  # IMPORTANT: broadcasts when the ORDER itself changes (staff accept/deny/served)
  after_create_commit :broadcast_staff_create
  after_update_commit :broadcast_customer_update
  after_update_commit :broadcast_staff_update

  def set_default_status
    self.status ||= "pending"
  end

  # If you already have totals:
  # def recalculate_total!
  #   update!(total: order_items.sum("unit_price * quantity"))
  # end

  def sync_status_from_items!
    # If any item is denied -> needs_customer_action
    if order_items.any?(&:denied?)
      update!(status: "needs_customer_action")
      return
    end

    # If all non-zero items are accepted -> accepted
    if order_items.all? { |oi| oi.accepted? }
      update!(status: "accepted")
      return
    end

    update!(status: "pending")
  end

  private

  # STAFF: show new pending orders instantly in the live queue
  def broadcast_staff_create
    return unless pending?

    broadcast_prepend_to(
      "staff_orders",
      target: "pending_orders",
      partial: "staff/orders/order_row",
      locals: { order: self }
    )
  end

  # CUSTOMER: update order card in My Orders instantly
  def broadcast_customer_update
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

  # STAFF: keep queues in sync without refresh
  def broadcast_staff_update
    if pending? || needs_customer_action?
      broadcast_replace_to(
        "staff_orders",
        target: dom_id(self),
        partial: "staff/orders/order_row",
        locals: { order: self }
      )
    else
      broadcast_remove_to("staff_orders", target: dom_id(self))
    end
  end
end

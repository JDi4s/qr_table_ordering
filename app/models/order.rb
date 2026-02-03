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

  after_create_commit :broadcast_staff_create
  after_update_commit :broadcast_staff_update

  private

  def set_default_status
    self.status ||= "pending"
  end

  def broadcast_staff_create
    return if served? || denied?

    broadcast_prepend_to(
      "staff_orders",
      target: "staff_orders_live",
      partial: "staff/orders/order_row",
      locals: { order: self }
    )
  end

  def broadcast_staff_update
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
